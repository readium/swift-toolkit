//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import OSLog

/// Observable store for the publication files in the app's Documents directory.
@MainActor final class DocumentRepository: ObservableObject {
    /// The current list of publication files, sorted alphabetically by
    /// filename.
    @Published private(set) var documents: [URL] = []

    /// The app's Documents directory.
    private let directory = FileManager.default.documentDirectory

    /// Low-level filesystem event source that triggers `loadDocuments()` on any
    /// change.
    private var dispatchSource: DispatchSourceFileSystemObject?

    private let logger = Logger(for: DocumentRepository.self)

    init() {
        watchDirectory()
    }

    deinit {
        dispatchSource?.cancel()
    }

    /// Returns the files at the given index offsets in the current `documents`
    /// list.
    func get(atOffsets offsets: IndexSet) -> [URL] {
        offsets.compactMap { documents.getOrNil($0) }
    }

    /// Copies `file` into the Documents directory, replacing any existing file
    /// with the same name.
    ///
    func add(file: URL) throws {
        // Security-scoped access is acquired and released after the copy so
        // the app can read files selected through the system file picker or
        // shared via the Files app.
        let isSecurityScoped = file.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                file.stopAccessingSecurityScopedResource()
            }
        }

        let target = directory.appendingPathComponent(file.lastPathComponent)
        try? FileManager.default.removeItem(at: target)
        try FileManager.default.copyItem(at: file, to: target)
    }

    /// Permanently deletes `file` from the Documents directory.
    func remove(_ file: URL) throws {
        try FileManager.default.removeItem(at: file)
    }

    // MARK: - Load and Watch Documents

    /// Begins watching the Documents directory for filesystem events.
    private func watchDirectory() {
        let path = directory.path
        let fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor != -1 else {
            logger.fault("Failed to open directory at \(path)")
            return
        }

        dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .all,
            queue: .global()
        )

        dispatchSource?.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.loadDocuments()
            }
        }

        dispatchSource?.setCancelHandler {
            close(fileDescriptor)
        }

        dispatchSource?.resume()

        loadDocuments()

        logger.notice("Watching directory at \(path)")
    }

    /// Reads the Documents directory and updates `documents` with the sorted
    /// file list.
    private func loadDocuments() {
        do {
            documents = try FileManager.default
                .contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
                )
                // Filter out directories.
                .filter { url in
                    !((try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false)
                }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

        } catch {
            logger.error(error)
        }
    }
}
