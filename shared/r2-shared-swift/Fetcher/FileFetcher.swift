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
public final class FileFetcher: Fetcher, Loggable {
    
    /// Reachable local paths, indexed by the exposed HREF.
    /// Sub-paths are reachable as well, to be able to access a whole directory.
    private let paths: [String: URL]
    
    /// Provides access to a collection of local paths.
    public init(paths: [String: URL]) {
        self.paths = paths.mapValues { $0.standardizedFileURL }
    }
    
    /// Provides access to the given local `path` at `href`.
    public convenience init(href: String, path: URL) {
        self.init(paths: [href: path])
    }
    
    public func get(_ link: Link) -> Resource {
        let linkHREF = link.href.addingPrefix("/")
        for (href, url) in paths {
            if linkHREF.hasPrefix(href) {
                let resourceURL = url.appendingPathComponent(linkHREF.removingPrefix(href)).standardizedFileURL
                // Makes sure that the requested resource is `url` or one of its descendant.
                if url.isParentOf(resourceURL) {
                    return FileResource(link: link, file: resourceURL)
                }
            }
        }

        return FailureResource(link: link, error: .notFound)
    }
    
    public lazy var links: [Link] =
        paths.keys.sorted().flatMap { href -> [Link] in
            guard
                let path = paths[href],
                let enumerator = FileManager.default.enumerator(at: path, includingPropertiesForKeys: [.isDirectoryKey]) else
            {
                return []
            }
            
            let hrefURL = URL(fileURLWithPath: href)
            
            return ([path] + enumerator).compactMap {
                guard
                    let url = $0 as? URL,
                    let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                    values.isDirectory == false else
                {
                    return nil
                }
                
                let subPath = url.standardizedFileURL.path.removingPrefix(path.standardizedFileURL.path)
                return Link(
                    href: hrefURL.appendingPathComponent(subPath).standardizedFileURL.path,
                    type: Format.of(fileExtension: url.pathExtension)?.mediaType.string
                )
            }
        }

    public func close() { }
    
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
