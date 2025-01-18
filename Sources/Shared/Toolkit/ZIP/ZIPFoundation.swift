//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
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

/// A ZIP ``Container`` using the ZIPFoundation library.
final class ZIPFoundationContainer: Container, Loggable {
    enum MakeError: Error {
        case notAZIP
        case reading(ReadError)
    }

    static func make(resource: Resource) async -> Result<ZIPFoundationContainer, MakeError> {
        // With an HTTP resource, we use a large buffer to avoid making hundreds
        // of small HTTP range requests.
        let bufferSize = ((resource.sourceURL?.httpURL != nil) ? 512 : 16) * 1024
        let resource = resource.buffered(size: bufferSize)
        do {
            let archive = try await ReadiumZIPFoundation.Archive(resource: resource)
            var entries = [RelativeURL: Entry]()

            for try await entry in archive {
                guard
                    entry.type == .file,
                    let url = RelativeURL(path: entry.path),
                    !url.path.isEmpty
                else {
                    continue
                }
                entries[url] = entry
            }

            return .success(Self(resource: resource, entries: entries, bufferSize: bufferSize))

        } catch {
            return .failure(.reading(.decoding(error)))
        }
    }

    private let resource: any Resource
    private let entriesByPath: [RelativeURL: Entry]
    private let bufferSize: Int

    public var sourceURL: AbsoluteURL? { resource.sourceURL }
    public let entries: Set<AnyURL>

    private init(
        resource: any Resource,
        entries: [RelativeURL: Entry],
        bufferSize: Int
    ) {
        self.resource = resource
        entriesByPath = entries
        self.entries = Set(entries.keys.map(\.anyURL))
        self.bufferSize = bufferSize
    }

    subscript(url: any URLConvertible) -> (any Resource)? {
        guard
            let url = url.relativeURL,
            let entry = entriesByPath[url]
        else {
            return nil
        }
        return ZIPFoundationResource(
            archiveResource: resource,
            entry: entry,
            bufferSize: bufferSize
        )
    }
}

private actor ZIPFoundationResource: Resource, Loggable {
    private let archiveResource: any Resource
    private let entry: Entry
    private let bufferSize: Int

    init(
        archiveResource: any Resource,
        entry: Entry,
        bufferSize: Int
    ) {
        self.archiveResource = archiveResource
        self.entry = entry
        self.bufferSize = bufferSize
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
                    try await archive.extractRange(range, of: entry, bufferSize: bufferSize) { data in
                        consume(data)
                    }
                } else {
                    _ = try await archive.extract(entry, bufferSize: bufferSize, skipCRC32: true) { data in
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
                _archive = try await .success(ReadiumZIPFoundation.Archive(resource: archiveResource))
            } catch {
                _archive = .failure(.decoding(error))
            }
        }
        return _archive!
    }
}

private extension ReadiumZIPFoundation.Archive {
    convenience init(resource: any Resource) async throws {
        if let file = resource.sourceURL?.fileURL {
            try await self.init(url: file.url, accessMode: .read)
        } else {
            try await self.init(url: resource.sourceURL?.url, dataSource: ResourceDataSource(resource: resource))
        }
    }
}

enum ResourceDataSourceError: Error {
    case unknownContentLength
}

private final class ResourceDataSource: ReadiumZIPFoundation.DataSource {
    private let resource: Resource
    private var _position: UInt64 = 0

    init(resource: Resource) {
        self.resource = resource
    }

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

    func close() {
        // FIXME?
//        resource.close()
    }
}
