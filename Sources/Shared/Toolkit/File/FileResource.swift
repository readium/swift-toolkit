//
//  Copyright 2024 Readium Foundation. All rights reserved.
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

    public func close() async {
        do {
            try _handle?.getOrNil()?.close()
        } catch {
            log(.error, error)
        }
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
                    _length = .failure(.access(FileSystemError.fileNotFound(nil)))
                }
            } catch {
                _length = .failure(.access(FileSystemError.io(error)))
            }
        }
        return _length!
    }

    public func properties() async -> ReadResult<ResourceProperties> {
        .success(ResourceProperties())
    }

    public func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async -> ReadResult<Void> {
        await handle().map { handle in
            if let range = range {
                handle.seek(toFileOffset: UInt64(max(0, range.lowerBound)))
                consume(handle.readData(ofLength: Int(range.upperBound - range.lowerBound)))
            } else {
                handle.seek(toFileOffset: 0)
                consume(handle.readDataToEndOfFile())
            }

            return ()
        }
    }

    private var _handle: ReadResult<FileHandle>?

    private func handle() async -> ReadResult<FileHandle> {
        if _handle == nil {
            do {
                let values = try fileURL.url.resourceValues(forKeys: [.isReadableKey, .isDirectoryKey])
                if let isReadable = values.isReadable, values.isDirectory != true {
                    _handle = try .success(FileHandle(forReadingFrom: fileURL.url))
                } else {
                    _handle = .failure(.access(FileSystemError.fileNotFound(nil)))
                }
            } catch {
                _handle = .failure(.access(FileSystemError.io(error)))
            }
        }
        return _handle!
    }
}
