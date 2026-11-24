//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumFuzi
import ReadiumShared
@testable import ReadiumStreamer
import Testing

/// Parsing of the metadata items identifying a publication following the EBPAJ
/// EPUB 3 production guide.
struct EPUBMetadataParserEBPAJTests {
    /// Version 1 of the guide uses a `dc:description`.
    @Test func parsesTheGuideDescription() throws {
        let metadata = try parse(
            metadata: """
            <dc:description id="ebpaj-guide">ebpaj-guide-1.0</dc:description>
            """
        )

        #expect(metadata.description == "ebpaj-guide-1.0")
    }

    /// Version 1.1 of the guide uses a `meta` with the `ebpaj` prefix, which
    /// the EBPAJ template declares on the `package` element.
    @Test func parsesTheGuideVersionWithADeclaredPrefix() throws {
        let metadata = try parse(
            prefix: """
            rendition: http://www.idpf.org/vocab/rendition/#
                     ebpaj: http://www.ebpaj.jp/
                     fixed-layout-jp: http://www.digital-comic.jp/
            """,
            metadata: """
            <meta property="ebpaj:guide-version">1.1.3</meta>
            """
        )

        #expect(metadata.otherMetadata["http://www.ebpaj.jp/guide-version"] == .string("1.1.3"))
    }

    /// The `ebpaj` prefix resolves to the same vocabulary when it is not
    /// declared on the `package` element.
    @Test func parsesTheGuideVersionWithAnUndeclaredPrefix() throws {
        let metadata = try parse(
            metadata: """
            <meta property="ebpaj:guide-version">1.1.3</meta>
            """
        )

        #expect(metadata.otherMetadata["http://www.ebpaj.jp/guide-version"] == .string("1.1.3"))
    }

    /// Other undeclared prefixes still fall back on the default vocabulary.
    @Test func parsesAnotherUndeclaredPrefixInTheDefaultVocabulary() throws {
        let metadata = try parse(
            metadata: """
            <meta property="foo:guide-version">1.1.3</meta>
            """
        )

        #expect(metadata.otherMetadata == [
            "http://idpf.org/epub/vocab/package/#guide-version": .string("1.1.3"),
        ])
    }

    private func parse(prefix: String? = nil, metadata: String) throws -> Metadata {
        let prefixAttribute = prefix.map { " prefix=\"\($0)\"" } ?? ""
        let document = try XMLDocument(string: """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" xml:lang="ja" unique-identifier="unique-id"\(prefixAttribute)>
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title id="title">タイトル</dc:title>
            <dc:language>ja</dc:language>
            <dc:identifier id="unique-id">urn:uuid:00000000-0000-0000-0000-000000000000</dc:identifier>
            \(metadata)
          </metadata>
          <manifest>
            <item id="p-001" href="xhtml/p-001.xhtml" media-type="application/xhtml+xml"/>
          </manifest>
          <spine page-progression-direction="rtl">
            <itemref idref="p-001"/>
          </spine>
        </package>
        """)

        return try EPUBMetadataParser(
            document: document,
            displayOptions: nil,
            metas: OPFMetaList(document: document)
        ).parse()
    }
}
