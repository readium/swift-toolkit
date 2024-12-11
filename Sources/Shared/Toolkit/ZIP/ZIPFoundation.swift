//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumZIPFoundation

/// An ``ArchiveOpener`` able to open ZIP archives using ZIPFoundation.
public final class ZIPFoundationArchiveOpener: ArchiveOpener {
    
    public init() {}
    
    public func open(resource: any Resource, format: Format) async -> Result<ContainerAsset, ArchiveOpenError> {
        guard
            format.conformsTo(.zip),
            let file = resource.sourceURL?.fileURL
        else {
            return .failure(.formatNotSupported(format))
        }

        return await ZIPFoundationContainer.make(file: file)
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
        guard let file = resource.sourceURL?.fileURL else {
            return .failure(.formatNotRecognized)
        }

        return await ZIPFoundationContainer.make(file: file)
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

    static func make(file: FileURL) async -> Result<ZIPFoundationContainer, MakeError> {
        guard await (try? file.exists()) ?? false else {
            return .failure(.reading(.access(.fileSystem(.fileNotFound(nil)))))
        }

        do {
            let archive = try ReadiumZIPFoundation.Archive(url: file.url, accessMode: .read)
            var entries = [RelativeURL: ZIPFoundationEntryMetadata]()

            for entry in archive {
                guard
                    entry.type == .file,
                    let url = RelativeURL(path: entry.path(using: .utf8)),
                    !url.path.isEmpty
                else {
                    continue
                }
                entries[url] = ZIPFoundationEntryMetadata(
                    length: entry.uncompressedSize,
                    compressedLength: entry.isCompressed ? entry.compressedSize : nil
                )
            }

            return .success(Self(file: file, entries: entries))

        } catch {
            return .failure(.reading(.decoding(error)))
        }
    }

    private let file: FileURL
    private let entriesMetadata: [RelativeURL: ZIPFoundationEntryMetadata]

    public var sourceURL: AbsoluteURL? { file }
    public let entries: Set<AnyURL>

    private init(file: FileURL, entries: [RelativeURL: ZIPFoundationEntryMetadata]) {
        self.file = file
        entriesMetadata = entries
        self.entries = Set(entries.keys.map(\.anyURL))
    }

    subscript(url: any URLConvertible) -> (any Resource)? {
        guard
            let url = url.relativeURL,
            let metadata = entriesMetadata[url]
        else {
            return nil
        }
        return ZIPFoundationResource(file: file, entryPath: url.path, metadata: metadata)
    }
}

private struct ZIPFoundationEntryMetadata {
    let length: UInt64
    let compressedLength: UInt64?
}

private actor ZIPFoundationResource: Resource, Loggable {
    private let file: FileURL
    private let entryPath: String
    private let metadata: ZIPFoundationEntryMetadata

    init(file: FileURL, entryPath: String, metadata: ZIPFoundationEntryMetadata) {
        self.file = file
        self.entryPath = entryPath
        self.metadata = metadata
    }

    public let sourceURL: AbsoluteURL? = nil

    func estimatedLength() async -> ReadResult<UInt64?> {
        .success(metadata.length)
    }

    func properties() async -> ReadResult<ResourceProperties> {
        .success(ResourceProperties {
            $0.filename = RelativeURL(path: entryPath)?.lastPathSegment
            $0.archive = ArchiveProperties(
                entryLength: metadata.compressedLength ?? metadata.length,
                isEntryCompressed: metadata.compressedLength != nil
            )
        })
    }

    func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async -> ReadResult<Void> {
        if range != nil {
        }

        return await archive().flatMap { archive in
            guard let entry = archive[entryPath] else {
                return .failure(.decoding("No entry found in the ZIP at \(entryPath)"))
            }
            
            do {
                if let range = range {
                    try archive.extractRange(range, of: entry) { data in
                        consume(data)
                    }
                } else {
                    _ = try archive.extract(entry, skipCRC32: true) { data in
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
                _archive = .success(try ReadiumZIPFoundation.Archive(url: file.url, accessMode: .read, pathEncoding: nil))
            } catch {
                _archive = .failure(.decoding(error))
            }
        }
        return _archive!
    }
}
