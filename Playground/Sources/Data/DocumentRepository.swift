//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import OSLog

@MainActor final class DocumentRepository: ObservableObject {
    @Published private(set) var documents: [URL] = []

    private let directory = FileManager.default.documentDirectory
    private let logger = Logger(for: DocumentRepository.self)

    /// Watches the content of the Documents/ folder.
    private var dispatchSource: DispatchSourceFileSystemObject?

    init() {
        watchDirectory()
    }

    func get(atOffsets offsets: IndexSet) -> [URL] {
        offsets.compactMap { documents[$0] }
    }

    func add(file: URL) throws {
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

    func remove(_ file: URL) throws {
        try FileManager.default.removeItem(at: file)
    }

    // MARK: - Load and Watch Documents

    private func watchDirectory() {
        let fileDescriptor = open(directory.path, O_EVTONLY)
        guard fileDescriptor != -1 else {
            logger.fault("Failed to open directory at \(directory.path)")
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

        dispatchSource?.resume()

        loadDocuments()

        logger.notice("Watching directory at \(directory.path)")
    }

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
