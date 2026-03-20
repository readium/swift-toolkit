//
//  Copyright 2026 Readium Foundation. All rights reserved.
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

    public nonisolated var sourceURL: AbsoluteURL? {
        fileURL
    }

    private var _length: Result<UInt64?, ReadError>?

    public func estimatedLength() async throws(ReadError) -> UInt64? {
        if _length == nil {
            do {
                let values = try fileURL.url.resourceValues(forKeys: [.fileSizeKey])
                if let length = values.fileSize {
                    _length = .success(UInt64(length))
                } else {
                    _length = .failure(.access(.fileSystem(.fileNotFound(nil))))
                }
            } catch {
                _length = .failure(.access(.fileSystem(.wrap(error) ?? .io(error))))
            }
        }
        switch _length! {
        case let .success(length): return length
        case let .failure(error): throw error
        }
    }

    public func properties() async throws(ReadError) -> ResourceProperties {
        ResourceProperties {
            $0.filename = fileURL.lastPathSegment
        }
    }

    public func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async throws(ReadError) {
        let handle = try await handle()
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
            throw ReadError.access(.fileSystem(.io(error)))
        }
    }

    private var _handle: Result<FileHandle, ReadError>?

    private func handle() async throws(ReadError) -> FileHandle {
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
        switch _handle! {
        case let .success(handle): return handle
        case let .failure(error): throw error
        }
    }
}
