//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import ReadiumShared

final class Paths {
    private init() {}

    static let home: FileURL =
        URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).fileURL!

    static let temporary: FileURL =
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).fileURL!

    static let documents: FileURL =
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.fileURL!

    static let library: FileURL =
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!.fileURL!

    static let covers: FileURL = {
        let url = library.appendingPath("Covers", isDirectory: true)
        try! FileManager.default.createDirectory(at: url.url, withIntermediateDirectories: true)
        return url
    }()

    static func makeDocumentURL(for source: FileURL? = nil, title: String?, format: Format) -> FileURL {
        // Is the file already in Documents/?
        if let source = source, documents.isParent(of: source) {
            return source
        } else {
            let title = title.takeIf { !$0.isEmpty } ?? UUID().uuidString
            let filename = format.fileExtension.appendedToFilename(title.sanitizedPathComponent)
            return documents.appendingUniquePathComponent(filename)
        }
    }

    static func makeTemporaryURL() -> FileURL {
        temporary.appendingUniquePathComponent()
    }

    /// Returns whether the given `url` locates a file that is under the app's home directory.
    static func isAppFile(at url: FileURL) -> Bool {
        home.isParent(of: url)
    }
}

extension FileURL {
    func appendingUniquePathComponent(_ pathComponent: String? = nil) -> FileURL {
        /// Returns the first path component matching the given `validation` closure.
        /// Numbers are appended to the path component until a valid candidate is found.
        func uniquify(_ pathComponent: String?, validation: (String) -> Bool) -> String {
            let pathComponent = pathComponent ?? UUID().uuidString
            var ext = (pathComponent as NSString).pathExtension
            if !ext.isEmpty {
                ext = ".\(ext)"
            }
            let pathComponentWithoutExtension = (pathComponent as NSString).deletingPathExtension

            var candidate = pathComponent
            var i = 0
            while !validation(candidate) {
                i += 1
                candidate = "\(pathComponentWithoutExtension) \(i)\(ext)"
            }
            return candidate
        }

        let pathComponent = uniquify(pathComponent) { candidate in
            let destination = appendingPath(candidate, isDirectory: false)
            return !((try? destination.url.checkResourceIsReachable()) ?? false)
        }

        return appendingPath(pathComponent, isDirectory: false)
    }
}
