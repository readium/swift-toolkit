//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Creates a `Resource` serving the contents of a local file.
public actor FileResource: Resource, Loggable {
    private let fileURL: FileURL

    public init(file: FileURL) {
        fileURL = file
    }

    public nonisolated var sourceURL: AbsoluteURL? { fileURL }

    private var _length: ReadResult<UInt64?>?

    public func estimatedLength() async -> ReadResult<UInt64?> {
        if _length == nil {
            do {
                let values = try fileURL.url.resourceValues(forKeys: [.fileSizeKey])
                if let length = values.fileSize {
                    _length = .success(UInt64(length))
                } else {
                    _length = .failure(.access(.fileSystem(.fileNotFound(nil))))
                }
            } catch {
                _length = .failure(.access(.fileSystem(.io(error))))
            }
        }
        return _length!
    }

    public func properties() async -> ReadResult<ResourceProperties> {
        .success(ResourceProperties {
            $0.filename = fileURL.lastPathSegment
        })
    }

    public func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async -> ReadResult<Void> {
        await handle().flatMap { handle in
            do {
                if var range = range {
                    range = range.clampedToInt()
                    try handle.seek(toOffset: UInt64(max(0, range.lowerBound)))
                    if let data = try handle.read(upToCount: Int(range.upperBound - range.lowerBound)) {
                        consume(data)
                    }
                } else {
                    try handle.seek(toOffset: 0)
                    if let data = try handle.readToEnd() {
                        consume(data)
                    }
                }
            } catch {
                return .failure(.access(.fileSystem(.io(error))))
            }

            return .success(())
        }
    }

    private var _handle: ReadResult<FileHandle>?

    private func handle() async -> ReadResult<FileHandle> {
        if _handle == nil {
            do {
                let values = try fileURL.url.resourceValues(forKeys: [.isReadableKey, .isDirectoryKey])
                if let isReadable = values.isReadable, isReadable, values.isDirectory != true {
                    _handle = try .success(FileHandle(forReadingFrom: fileURL.url))
                } else {
                    _handle = .failure(.access(.fileSystem(.fileNotFound(nil))))
                }
            } catch {
                _handle = .failure(.access(.fileSystem(.io(error))))
            }
        }
        return _handle!
    }
}
