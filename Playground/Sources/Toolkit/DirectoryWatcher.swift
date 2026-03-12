//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import OSLog

/// Observes files in a directory.
@MainActor final class DirectoryWatcher: ObservableObject {
    /// The current list of file URLs in the observed directory.
    @Published private(set) var files: [URL] = []

    private let directoryURL: URL
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var logger: Logger!

    /// Initializes the watcher with a specific directory URL.
    init(url: URL) {
        precondition(url.isFileURL)

        directoryURL = url
        logger = Logger(for: DirectoryWatcher.self)

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
            self?.watch()
        }

        dispatchSource?.resume()

        watch()

        logger.notice("Watching directory at \(url.path)")
    }

    /// Updates the list of `files` at `directoryURL`.
    private func watch() {
        let files: [URL]
        do {
            files = try FileManager.default
                .contentsOfDirectory(
                    at: directoryURL,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            logger.error(error)
            files = []
        }

        Task { @MainActor in
            self.files = files
        }
    }
}
