//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

@MainActor final class DocumentRepository: ObservableObject {
    @Published private(set) var documents: [URL] = []

    private let directory = FileManager.default.documentDirectory

    /// Watches the content of the Documents/ folder.
    private var watcher: DirectoryWatcher!

    init() {
        watcher = DirectoryWatcher(
            url: directory,
            onChange: { [weak self] in
                self?.documents = $0
            }
        )
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
}
