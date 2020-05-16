//
//  FileFetcher.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 11/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Provides access to resources on the local file system.
///
final class FileFetcher: Fetcher, Loggable {
    
    /// Reachable local paths, indexed by the exposed HREF.
    /// Sub-paths are reachable as well, to be able to access a whole directory.
    private let paths: [String: URL]
    
    /// Provides access to a collection of local paths.
    init(paths: [String: URL]) {
        self.paths = paths.mapValues { $0.standardizedFileURL }
    }
    
    /// Provides access to the given local `path` at `href`.
    convenience init(href: String, path: URL) {
        self.init(paths: [href: path])
    }
    
    func get(_ link: Link, parameters: LinkParameters) -> Resource {
        for (href, url) in paths {
            if link.href.hasPrefix(href) {
                let resourceURL = url.appendingPathComponent(link.href.removingPrefix(href)).standardizedFileURL
                // Makes sure that the requested resource is `url` or one of its descendant.
                if resourceURL.path.hasPrefix(url.path) {
                    return FileResource(link: link, file: resourceURL)
                }
            }
        }

        return FailureResource(link: link, error: .notFound)
    }
    
    func close() { }
    
    private final class FileResource: Resource, Loggable {
        
        let link: Link

        private let file: URL
        
        private lazy var handle: Result<FileHandle, ResourceError> = {
            do {
                let values = try file.resourceValues(forKeys:[.isReadableKey, .isDirectoryKey])
                guard let isReadable = values.isReadable, values.isDirectory != true else {
                    return .failure(.notFound)
                }
                return .success(try FileHandle(forReadingFrom: file))
            } catch {
                return .failure(.other(error))
            }
        }()
        
        init(link: Link, file: URL) {
            assert(file.isFileURL)
            self.link = link
            self.file = file
        }

        lazy var length: Result<UInt64, ResourceError> = {
            do {
                let values = try file.resourceValues(forKeys:[.fileSizeKey])
                guard let length = values.fileSize else {
                    return .failure(.notFound)
                }
                return .success(UInt64(length))
            } catch {
                return .failure(.other(error))
            }
        }()
        
        func read(range: Range<UInt64>?) -> Result<Data, ResourceError> {
            return handle.map { handle in
                if let range = range {
                    handle.seek(toFileOffset: UInt64(max(0, range.lowerBound)))
                    return handle.readData(ofLength: Int(range.upperBound - range.lowerBound))
                } else {
                    handle.seek(toFileOffset: 0)
                    return handle.readDataToEndOfFile()
                }
            }
        }
        
        func close() {
            if let handle = try? self.handle.get() {
                handle.closeFile()
            }
        }
        
    }
    
}
