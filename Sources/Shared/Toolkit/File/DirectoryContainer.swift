//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A file system directory as a ``Container``.
public struct DirectoryContainer: Container, Loggable {
    public struct NotADirectoryError: Error {}

    private let directoryURL: FileURL
    public var sourceURL: AbsoluteURL? { directoryURL }
    public let entries: Set<AnyURL>

    /// Creates a ``DirectoryContainer`` at `directory` serving only the given
    /// `entries`.
    public init(directory: FileURL, entries: Set<RelativeURL>) {
        directoryURL = directory
        self.entries = Set(entries.map(\.anyURL.normalized))
    }

    /// Creates a ``DirectoryContainer`` at `directory` serving all its children
    /// recursively.
    public init(
        directory: FileURL,
        options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]
    ) async throws {
        var entries = Set<RelativeURL>()

        var isDirectory: ObjCBool = false
        guard
            FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            throw NotADirectoryError()
        }

        if let enumerator = FileManager.default.enumerator(
            at: directory.url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: options
        ) {
            for case let url as URL in enumerator {
                do {
                    let fileAttributes = try url.resourceValues(forKeys: [.isRegularFileKey])
                    if fileAttributes.isRegularFile == true, let entry = directory.relativize(url.anyURL) {
                        entries.insert(entry)
                    }
                } catch {
                    Self.log(.error, error)
                }
            }
        }

        self.init(directory: directory, entries: entries)
    }

    public subscript(url: any URLConvertible) -> Resource? {
        guard
            entries.contains(url.anyURL),
            let file = directoryURL.resolve(url)?.fileURL
        else {
            return nil
        }
        return FileResource(file: file)
    }
}
