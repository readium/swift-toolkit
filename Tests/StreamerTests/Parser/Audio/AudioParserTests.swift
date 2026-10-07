//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
@testable import ReadiumStreamer
import Testing

struct AudioParserTests {
    let fixtures = Fixtures()

    let parser: AudioParser

    let zabAsset: Asset
    let mp3Asset: Asset

    init() async throws {
        parser = AudioParser(assetRetriever: AssetRetriever(httpClient: DefaultHTTPClient()))

        zabAsset = try await .container(ZIPArchiveOpener().open(
            resource: FileResource(file: fixtures.url(for: "audiotest.zab")),
            format: Format(specifications: .zip, .informalAudiobook, mediaType: .zab, fileExtension: "zab")
        ).get())

        mp3Asset = .resource(ResourceAsset(
            resource: FileResource(file: fixtures.url(for: "audiotest/Test Audiobook/Latin.mp3")),
            format: Format(specifications: .mp3, mediaType: .mp3, fileExtension: "mp3")
        ))
    }

    @Test func refusesNonAudioBased() async throws {
        let asset: Asset = try await .container(ZIPArchiveOpener().open(
            resource: FileResource(file: fixtures.url(for: "futuristic_tales.cbz")),
            format: Format(specifications: .zip, .informalComic, mediaType: .cbz, fileExtension: "cbz")
        ).get())

        let result = await parser.parse(asset: asset, warnings: nil)

        guard case .failure(.formatNotSupported) = result else {
            Issue.record("Expected a formatNotSupported error, got \(result)")
            return
        }
    }

    @Test func acceptsZAB() async throws {
        _ = try await parser.parse(asset: zabAsset, warnings: nil).get()
    }

    @Test func acceptsMP3() async throws {
        _ = try await parser.parse(asset: mp3Asset, warnings: nil).get()
    }

    @Test func conformsToAudiobook() async throws {
        let publication = try await parser.parse(asset: zabAsset, warnings: nil).get().build()
        #expect(publication.metadata.conformsTo == [.audiobook])
    }

    /// The reading order is sorted alphabetically, ignores Thumbs.db, hidden files and non-audio
    /// files.
    @Test func readingOrderIsSortedAlphabetically() async throws {
        let publication = try await parser.parse(asset: zabAsset, warnings: nil).get().build()

        #expect(publication.readingOrder.map(\.href) == [
            "Test%20Audiobook/gtr-jazz.mp3",
            "Test%20Audiobook/Latin.mp3",
            "Test%20Audiobook/vln-lin-cs.mp3",
        ])
    }

    @Test func hasNoCover() async throws {
        let publication = try await parser.parse(asset: zabAsset, warnings: nil).get().build()
        #expect(publication.linkWithRel(.cover) == nil)
    }

    @Test func hasNoPositions() async throws {
        let publication = try await parser.parse(asset: zabAsset, warnings: nil).get().build()
        let result = try await publication.positions().get()
        #expect(result.count == 0)
    }
}
