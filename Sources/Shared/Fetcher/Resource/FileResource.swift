//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Creates a `Resource` serving the contents of a local file.
public final class FileResource: Resource, Loggable {
    public let link: Link

    private let _file: URL
    public var file: URL? { _file }

    public init(link: Link, file: URL) {
        assert(file.isFileURL)
        self.link = link
        _file = file
    }

    private lazy var handle: Result<FileHandle, ResourceError> = {
        do {
            let values = try _file.resourceValues(forKeys: [.isReadableKey, .isDirectoryKey])
            guard let isReadable = values.isReadable, values.isDirectory != true else {
                return .failure(.notFound(nil))
            }
            return try .success(FileHandle(forReadingFrom: _file))
        } catch {
            return .failure(.other(error))
        }
    }()

    public lazy var length: Result<UInt64, ResourceError> = {
        do {
            let values = try _file.resourceValues(forKeys: [.fileSizeKey])
            guard let length = values.fileSize else {
                return .failure(.notFound(nil))
            }
            return .success(UInt64(length))
        } catch {
            return .failure(.other(error))
        }
    }()

    public func read(range: Range<UInt64>?) -> Result<Data, ResourceError> {
        handle.map { handle in
            if let range = range {
                handle.seek(toFileOffset: UInt64(max(0, range.lowerBound)))
                return handle.readData(ofLength: Int(range.upperBound - range.lowerBound))
            } else {
                handle.seek(toFileOffset: 0)
                return handle.readDataToEndOfFile()
            }
        }
    }

    public func close() {
        if let handle = try? handle.get() {
            handle.closeFile()
        }
    }
}
