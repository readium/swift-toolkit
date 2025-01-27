//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal
import ReadiumZIPFoundation

/// An ``ArchiveOpener`` able to open ZIP archives using ZIPFoundation.
public final class ZIPFoundationArchiveOpener: ArchiveOpener {
    public init() {}

    public func open(resource: any Resource, format: Format) async -> Result<ContainerAsset, ArchiveOpenError> {
        guard format.conformsTo(.zip) else {
            return .failure(.formatNotSupported(format))
        }

        return await ZIPFoundationContainer.make(resource: resource)
            .mapError {
                switch $0 {
                case .notAZIP:
                    return .formatNotSupported(format)
                case let .reading(error):
                    return .reading(error)
                }
            }
            .map { ContainerAsset(container: $0, format: format) }
    }

    public func sniffOpen(resource: any Resource) async -> Result<ContainerAsset, ArchiveSniffOpenError> {
        await ZIPFoundationContainer.make(resource: resource)
            .mapError {
                switch $0 {
                case .notAZIP:
                    return .formatNotRecognized
                case let .reading(error):
                    return .reading(error)
                }
            }
            .map {
                ContainerAsset(
                    container: $0,
                    format: Format(
                        specifications: .zip,
                        mediaType: .zip,
                        fileExtension: "zip"
                    )
                )
            }
    }
}

/// The ZIP End of Central Directory Record should be at most 65557 bytes,
/// according to the ZIP specification. The ZIP 64 EOCD should be
/// an extra 76 bytes according to ZIPFoundation implementation.
private let zipEOCDMaximumLength: UInt64 = 65557 + 76

/// The maximum length of a non-local ZIP package to be cached entirely in
/// memory instead of streamed.
private let maximumZIPLengthToFullyCache = 5.MB

/// Creates new ZIPFoundation ``Archive`` objects from a shared ``Resource``.
private final class ZIPFoundationArchiveFactory {
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
            let bufferSize = 512.kB
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

/// A ZIP ``Container`` using the ZIPFoundation library.
final class ZIPFoundationContainer: Container, Loggable {
    enum MakeError: Error {
        case notAZIP
        case reading(ReadError)
    }

    static func make(resource: Resource) async -> Result<ZIPFoundationContainer, MakeError> {
        do {
            let archiveFactory = await ZIPFoundationArchiveFactory(resource: resource)
            let archive = try await archiveFactory.make()

            var entries = [RelativeURL: Entry]()

            for try await entry in archive {
                guard
                    entry.type == .file,
                    let url = RelativeURL(path: entry.path)?.normalized,
                    !url.path.isEmpty
                else {
                    continue
                }
                entries[url] = entry
            }

            return .success(Self(archiveFactory: archiveFactory, entries: entries))

        } catch {
            return .failure(.reading(.decoding(error)))
        }
    }

    private let archiveFactory: ZIPFoundationArchiveFactory
    private let entriesByPath: [RelativeURL: Entry]

    public var sourceURL: AbsoluteURL? { archiveFactory.sourceURL }
    public let entries: Set<AnyURL>

    private init(
        archiveFactory: ZIPFoundationArchiveFactory,
        entries: [RelativeURL: Entry]
    ) {
        let entries = entries.reduce(into: [:]) { result, item in
            result[item.key.normalized] = item.value
        }

        self.archiveFactory = archiveFactory
        entriesByPath = entries
        self.entries = Set(entries.keys.map(\.anyURL))
    }

    subscript(url: any URLConvertible) -> (any Resource)? {
        guard
            let url = url.relativeURL?.normalized,
            let entry = entriesByPath[url]
        else {
            return nil
        }
        return ZIPFoundationResource(
            archiveFactory: archiveFactory,
            entry: entry
        )
    }
}

/// A ``Resource`` providing access to a single entry in a ZIPFoundation archive.
private actor ZIPFoundationResource: Resource, Loggable {
    private let archiveFactory: ZIPFoundationArchiveFactory
    private let entry: Entry

    init(
        archiveFactory: ZIPFoundationArchiveFactory,
        entry: Entry
    ) {
        self.archiveFactory = archiveFactory
        self.entry = entry
    }

    public let sourceURL: AbsoluteURL? = nil

    func estimatedLength() async -> ReadResult<UInt64?> {
        .success(entry.uncompressedSize)
    }

    func properties() async -> ReadResult<ResourceProperties> {
        .success(ResourceProperties {
            $0.filename = RelativeURL(path: entry.path)?.lastPathSegment
            $0.archive = ArchiveProperties(
                entryLength: entry.isCompressed ? entry.compressedSize : entry.uncompressedSize,
                isEntryCompressed: entry.isCompressed
            )
        })
    }

    func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async -> ReadResult<Void> {
        if range != nil {}

        return await archive().asyncFlatMap { archive in
            do {
                if let range = range {
                    try await archive.extractRange(range, of: entry) { data in
                        consume(data)
                    }
                } else {
                    _ = try await archive.extract(entry, skipCRC32: true) { data in
                        consume(data)
                    }
                }
                return .success(())
            } catch {
                return .failure(.decoding(error))
            }
        }
    }

    private var _archive: ReadResult<ReadiumZIPFoundation.Archive>?
    private func archive() async -> ReadResult<ReadiumZIPFoundation.Archive> {
        if _archive == nil {
            do {
                _archive = try await .success(archiveFactory.make())
            } catch {
                _archive = .failure(.decoding(error))
            }
        }
        return _archive!
    }
}

enum ResourceDataSourceError: Error {
    case unknownContentLength
}

/// Bridges the ZIPFoundation's ``DataSource`` with our ``Resource``.
private final class ResourceDataSource: ReadiumZIPFoundation.DataSource {
    private let resource: Resource
    private var _position: UInt64 = 0

    init(resource: Resource) {
        self.resource = resource
    }

    func close() throws {}

    func length() async throws -> UInt64 {
        guard let length = try await resource.estimatedLength().get() else {
            throw ResourceDataSourceError.unknownContentLength
        }
        return length
    }

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
