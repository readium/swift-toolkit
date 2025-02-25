//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumZIPFoundation

/// The ZIP End of Central Directory Record should be at most 65557 bytes,
/// according to the ZIP specification. The ZIP 64 EOCD should be
/// an extra 76 bytes according to ZIPFoundation implementation.
private let zipEOCDMaximumLength: UInt64 = 65557 + 76

/// The maximum length of a non-local ZIP package to be cached entirely in
/// memory instead of streamed.
private let maximumZIPLengthToFullyCache = 5.MB

/// Creates new ZIPFoundation ``Archive`` objects from a shared ``Resource``.
final class ZIPFoundationArchiveFactory {
    enum Source {
        case file(FileURL)
        case resource(Resource)
    }

    private let source: Source
    private let bufferSize: Int

    var sourceURL: AbsoluteURL? {
        switch source {
        case let .file(file):
            return file
        case let .resource(resource):
            return resource.sourceURL
        }
    }

    init(resource: Resource) async {
        if let file = resource.sourceURL?.fileURL {
            source = .file(file)
            bufferSize = 16.kB

        } else {
            // We use a large buffer to avoid making hundreds of small HTTP
            // range requests.
            let bufferSize = 6.MB
            var resource: Resource = resource.buffered(size: bufferSize)

            if let optionalLength = await resource.estimatedLength().getOrNil(), let length = optionalLength {
                // The End of Central Directory Record, located at the end of
                // the ZIP file, will be read each time we create a new
                // `Archive` object. To optimize requests, we cache the end of
                // the resource.
                //
                // Additionally, if the ZIP file is small enough, we will cache
                // it completely in memory.
                resource = TailCachingResource(
                    resource: resource,
                    cacheFromOffset: (!canAllocate(maximumZIPLengthToFullyCache * 2) || length > maximumZIPLengthToFullyCache)
                        ? Swift.max(0, length - zipEOCDMaximumLength)
                        : 0
                )
            }

            source = .resource(resource)
            self.bufferSize = bufferSize
        }
    }

    func make() async throws -> ReadiumZIPFoundation.Archive {
        switch source {
        case let .file(url):
            return try await .init(
                url: url.url,
                accessMode: .read,
                defaultReadChunkSize: bufferSize
            )

        case let .resource(resource):
            return try await .init(
                url: resource.sourceURL?.url,
                dataSource: ResourceDataSource(resource: resource),
                defaultReadChunkSize: bufferSize
            )
        }
    }
}

/// Indicates whether there is enough available free memory to allocate `length`
/// bytes.
private func canAllocate(_ length: Int) -> Bool {
    os_proc_available_memory() > length
}

enum ResourceDataSourceError: Error {
    case unknownContentLength
}

/// Bridges the ZIPFoundation's ``DataSource`` with our ``Resource``.
private actor ResourceDataSource: ReadiumZIPFoundation.DataSource {
    private let resource: Resource

    init(resource: Resource) {
        self.resource = resource
    }

    let isWritable: Bool = false

    func length() async throws -> UInt64 {
        guard let length = try await resource.estimatedLength().get() else {
            throw ResourceDataSourceError.unknownContentLength
        }
        return length
    }

    func openRead() async throws -> any DataSourceTransaction {
        Transaction(resource: resource)
    }

    private actor Transaction: ReadiumZIPFoundation.DataSourceTransaction {
        private var _position: UInt64 = 0
        private let resource: Resource

        init(resource: Resource) {
            self.resource = resource
        }

        func close() async throws {}

        func position() async throws -> UInt64 {
            _position
        }

        func seek(to position: UInt64) async throws {
            _position = position
        }

        func read(length: Int) async throws -> Data {
            guard length > 0 else {
                return Data()
            }
            let range = _position ..< (_position + UInt64(length))
            let data = try await resource.read(range: range).get()
            _position += UInt64(data.count)
            return data
        }
    }
}
