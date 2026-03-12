//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import OSLog

/// Observes files in a directory.
final class DirectoryWatcher {
    private let directoryURL: URL
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var logger: Logger!
    private let onChange: @MainActor ([URL]) -> Void

    /// Initializes the watcher with a specific directory URL.
    init(url: URL, onChange: @MainActor @escaping ([URL]) -> Void) {
        precondition(url.isFileURL)

        directoryURL = url
        logger = Logger(for: DirectoryWatcher.self)
        self.onChange = onChange

        let fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor != -1 else {
            logger.fault("Failed to open directory at \(url.path)")
            return
        }

        dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .all,
            queue: .global()
        )

        dispatchSource?.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.watch()
            }
        }

        dispatchSource?.resume()

        watch()

        logger.notice("Watching directory at \(url.path)")
    }

    /// Broadcasts the list of `files` at `directoryURL` to `onChange`.
    private func watch() {
        do {
            let files = try FileManager.default
                .contentsOfDirectory(
                    at: directoryURL,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
                )
                // Filter out directories.
                .filter { url in
                    !((try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false)
                }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            onChange(files)

        } catch {
            logger.error(error)
        }
    }
}
