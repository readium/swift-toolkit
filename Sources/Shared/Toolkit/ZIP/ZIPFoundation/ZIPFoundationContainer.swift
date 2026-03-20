//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumZIPFoundation

/// A ZIP ``Container`` using the ZIPFoundation library.
final class ZIPFoundationContainer: Container, Loggable {
    enum MakeError: Error {
        case notAZIP
        case reading(ReadError)
    }

    static func make(resource: Resource) async throws(MakeError) -> ZIPFoundationContainer {
        do {
            let archiveFactory = await ZIPFoundationArchiveFactory(resource: resource)
            let archive = try await archiveFactory.make()

            var entries = [RelativeURL: Entry]()

            for entry in try await archive.entries() {
                guard
                    entry.type == .file,
                    let url = RelativeURL(path: entry.path)?.normalized,
                    !url.path.isEmpty
                else {
                    continue
                }
                entries[url] = entry
            }

            return Self(archiveFactory: archiveFactory, entries: entries)

        } catch {
            throw .reading(.wrap(error) ?? .decoding(error))
        }
    }

    private let archiveFactory: ZIPFoundationArchiveFactory
    private let entriesByPath: [RelativeURL: Entry]

    var sourceURL: AbsoluteURL? {
        archiveFactory.sourceURL
    }

    let entries: Set<AnyURL>

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
            let url = url.anyURL.relativeURL?.normalized,
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

    let sourceURL: AbsoluteURL? = nil

    func estimatedLength() async throws(ReadError) -> UInt64? {
        entry.uncompressedSize
    }

    func properties() async throws(ReadError) -> ResourceProperties {
        ResourceProperties {
            $0.filename = RelativeURL(path: entry.path)?.lastPathSegment
            $0.archive = ArchiveProperties(
                entryLength: entry.isCompressed ? entry.compressedSize : entry.uncompressedSize,
                isEntryCompressed: entry.isCompressed
            )
        }
    }

    func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async throws(ReadError) {
        let archive = try await archive()
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
        } catch {
            throw .wrap(error) ?? .decoding(error)
        }
    }

    private var _archive: Result<ReadiumZIPFoundation.Archive, ReadError>?
    private func archive() async throws(ReadError) -> ReadiumZIPFoundation.Archive {
        if _archive == nil {
            do {
                _archive = try await .success(archiveFactory.make())
            } catch {
                _archive = .failure(.wrap(error) ?? .decoding(error))
            }
        }
        switch _archive! {
        case let .success(archive): return archive
        case let .failure(error): throw error
        }
    }
}
