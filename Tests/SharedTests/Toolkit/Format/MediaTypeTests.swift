//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class MediaTypeTests: XCTestCase {
    func testInvalidTypesReturnsNil() {
        XCTAssertNil(MediaType("application"))
        XCTAssertNil(MediaType("application/atom+xml/extra"))
    }

    func testGetString() {
        XCTAssertEqual(
            MediaType("application/atom+xml;profile=opds-catalog")?.string,
            "application/atom+xml;profile=opds-catalog"
        )
    }

    func testGetStringNormalizes() {
        XCTAssertEqual(
            MediaType("APPLICATION/ATOM+XML;PROFILE=OPDS-CATALOG   ;   a=0")?.string,
            "application/atom+xml;a=0;profile=OPDS-CATALOG"
        )
        // Parameters are sorted by name
        XCTAssertEqual(
            MediaType("application/atom+xml;a=0;b=1")?.string,
            "application/atom+xml;a=0;b=1"
        )
        XCTAssertEqual(
            MediaType("application/atom+xml;b=1;a=0")?.string,
            "application/atom+xml;a=0;b=1"
        )
    }

    func testGetType() {
        XCTAssertEqual(
            MediaType("application/atom+xml;profile=opds-catalog")?.type,
            "application"
        )
        XCTAssertEqual(MediaType("*/jpeg")?.type, "*")
    }

    func testGetSubtype() {
        XCTAssertEqual(
            MediaType("application/atom+xml;profile=opds-catalog")?.subtype,
            "atom+xml"
        )
        XCTAssertEqual(MediaType("image/*")?.subtype, "*")
    }

    func testGetParameters() {
        XCTAssertEqual(
            MediaType("application/atom+xml;type=entry;profile=opds-catalog")?.parameters,
            [
                "type": "entry",
                "profile": "opds-catalog",
            ]
        )
    }

    func testGetEmptyParameters() throws {
        XCTAssertTrue(try XCTUnwrap(MediaType("application/atom+xml")?.parameters.isEmpty))
    }

    func testGetParametersWithWhitespaces() {
        XCTAssertEqual(
            MediaType("application/atom+xml    ;    type=entry   ;    profile=opds-catalog   ")?.parameters,
            [
                "type": "entry",
                "profile": "opds-catalog",
            ]
        )
    }

    func testGetStructuredSyntaxSuffix() {
        XCTAssertNil(MediaType("foo/bar")?.structuredSyntaxSuffix)
        XCTAssertNil(MediaType("application/zip")?.structuredSyntaxSuffix)
        XCTAssertEqual(MediaType("application/epub+zip")?.structuredSyntaxSuffix, "+zip")
        XCTAssertEqual(MediaType("foo/bar+json+zip")?.structuredSyntaxSuffix, "+zip")
    }

    func testGetEncoding() {
        XCTAssertNil(MediaType("text/html")?.encoding)
        XCTAssertEqual(MediaType("text/html;charset=utf-8")?.encoding, .utf8)
    }

    func testTypeSubtypeAndParameterNamesAreLowercased() throws {
        let mediaType = try XCTUnwrap(MediaType("APPLICATION/ATOM+XML;PROFILE=OPDS-CATALOG"))
        XCTAssertEqual(mediaType.type, "application")
        XCTAssertEqual(mediaType.subtype, "atom+xml")
        XCTAssertEqual(mediaType.parameters, ["profile": "OPDS-CATALOG"])
    }

    func testCharsetValueIsUppercased() {
        XCTAssertEqual(MediaType("text/html;charset=utf-8")?.parameters["charset"], "UTF-8")
    }

    func testEquals() throws {
        XCTAssertEqual(MediaType("application/atom+xml"), MediaType("application/atom+xml"))
        XCTAssertEqual(MediaType("application/atom+xml;profile=opds-catalog"), MediaType("application/atom+xml;profile=opds-catalog"))
        XCTAssertNotEqual(try XCTUnwrap(MediaType("application/atom+xml")), try XCTUnwrap(MediaType("application/atom")))
        XCTAssertNotEqual(try XCTUnwrap(MediaType("application/atom+xml")), try XCTUnwrap(MediaType("text/atom+xml")))
        XCTAssertNotEqual(try XCTUnwrap(MediaType("application/atom+xml;profile=opds-catalog")), try XCTUnwrap(MediaType("application/atom+xml")))
    }

    func testEqualsIgnoresCaseOfTypeSubtypeAndParameterNames() throws {
        XCTAssertEqual(
            MediaType("application/atom+xml;profile=opds-catalog"),
            MediaType("APPLICATION/ATOM+XML;PROFILE=opds-catalog")
        )
        XCTAssertNotEqual(
            try XCTUnwrap(MediaType("application/atom+xml;profile=opds-catalog")),
            try XCTUnwrap(MediaType("APPLICATION/ATOM+XML;PROFILE=OPDS-CATALOG"))
        )
    }

    func testEqualsIgnoresParametersOrder() {
        XCTAssertEqual(
            MediaType("application/atom+xml;type=entry;profile=opds-catalog"),
            MediaType("application/atom+xml;profile=opds-catalog;type=entry")
        )
    }

    func testEqualsIgnoresCharsetCase() {
        XCTAssertEqual(
            MediaType("application/atom+xml;charset=utf-8"),
            MediaType("application/atom+xml;charset=UTF-8")
        )
    }

    func testContainsEqualMediaType() throws {
        XCTAssertTrue(try XCTUnwrap(try MediaType("text/html;charset=utf-8")?
                .contains(XCTUnwrap(MediaType("text/html;charset=utf-8")))))
    }

    func testContainsMustMatchParameters() throws {
        XCTAssertFalse(try XCTUnwrap(try MediaType("text/html;charset=utf-8")?
                .contains(XCTUnwrap(MediaType("text/html;charset=ascii")))))
        XCTAssertFalse(try XCTUnwrap(try MediaType("text/html;charset=utf-8")?
                .contains(XCTUnwrap(MediaType("text/html")))))
    }

    func testContainsIgnoresParametersOrder() throws {
        XCTAssertTrue(try XCTUnwrap(try MediaType("text/html;charset=utf-8;type=entry")?
                .contains(XCTUnwrap(MediaType("text/html;type=entry;charset=utf-8")))))
    }

    func testContainsIgnoresExtraParameters() throws {
        XCTAssertTrue(try XCTUnwrap(try MediaType("text/html")?
                .contains(XCTUnwrap(MediaType("text/html;charset=utf-8")))))
    }

    func testContainsSupportsWildcards() throws {
        XCTAssertTrue(try XCTUnwrap(try MediaType("*/*")?
                .contains(XCTUnwrap(MediaType("text/html;charset=utf-8")))))
        XCTAssertTrue(try XCTUnwrap(try MediaType("text/*")?
                .contains(XCTUnwrap(MediaType("text/html;charset=utf-8")))))
        XCTAssertFalse(try XCTUnwrap(try MediaType("text/*")?
                .contains(XCTUnwrap(MediaType("application/zip")))))
    }

    func testContainsFromString() throws {
        XCTAssertTrue(try XCTUnwrap(MediaType("text/html;charset=utf-8")?
                .contains("text/html;charset=utf-8")))
    }

    func testMatchesEqualMediaType() throws {
        XCTAssertTrue(try XCTUnwrap(try MediaType("text/html;charset=utf-8")?
                .matches(XCTUnwrap(MediaType("text/html;charset=utf-8")))))
    }

    func testMatchesMustMatchParameters() throws {
        XCTAssertFalse(try XCTUnwrap(try MediaType("text/html;charset=ascii")?
                .matches(XCTUnwrap(MediaType("text/html;charset=utf-8")))))
    }

    func testMatchesIgnoresParametersOrder() throws {
        XCTAssertTrue(try XCTUnwrap(try MediaType("text/html;charset=utf-8;type=entry")?
                .matches(XCTUnwrap(MediaType("text/html;type=entry;charset=utf-8")))))
    }

    func testMatchesIgnoresExtraParameters() throws {
        XCTAssertTrue(try XCTUnwrap(try MediaType("text/html;charset=utf-8")?
                .matches(XCTUnwrap(MediaType("text/html;charset=utf-8;extra=param")))))
        XCTAssertTrue(try XCTUnwrap(try MediaType("text/html;charset=utf-8;extra=param")?
                .matches(XCTUnwrap(MediaType("text/html;charset=utf-8")))))
    }

    func testMatchesSupportsWildcards() throws {
        XCTAssertTrue(try XCTUnwrap(try MediaType("text/html;charset=utf-8")?.matches(XCTUnwrap(MediaType("*/*")))))
        XCTAssertTrue(try XCTUnwrap(try MediaType("text/html;charset=utf-8")?.matches(XCTUnwrap(MediaType("text/*")))))
        XCTAssertFalse(try XCTUnwrap(try MediaType("application/zip")?.matches(XCTUnwrap(MediaType("text/*")))))
        XCTAssertTrue(try XCTUnwrap(try MediaType("*/*")?.matches(XCTUnwrap(MediaType("text/html;charset=utf-8")))))
        XCTAssertTrue(try XCTUnwrap(try MediaType("text/*")?.matches(XCTUnwrap(MediaType("text/html;charset=utf-8")))))
        XCTAssertFalse(try XCTUnwrap(try MediaType("text/*")?.matches(XCTUnwrap(MediaType("application/zip")))))
    }

    func testMatchesFromString() throws {
        XCTAssertTrue(try XCTUnwrap(MediaType("text/html;charset=utf-8")?.matches("text/html;charset=utf-8")))
    }

    func testMatchesAnyMediaTypes() throws {
        XCTAssertTrue(try XCTUnwrap(try MediaType("text/html")?
                .matchesAny(XCTUnwrap(MediaType("application/zip")), XCTUnwrap(MediaType("text/html;charset=utf-8")))))
        XCTAssertFalse(try XCTUnwrap(try MediaType("text/html")?
                .matchesAny(XCTUnwrap(MediaType("application/zip")), XCTUnwrap(MediaType("text/plain;charset=utf-8")))))
        XCTAssertTrue(try XCTUnwrap(MediaType("text/html")?
                .matchesAny("application/zip", "text/html;charset=utf-8")))
        XCTAssertFalse(try XCTUnwrap(MediaType("text/html")?
                .matchesAny("application/zip", "text/plain;charset=utf-8")))
    }

    func testPatternMatch() throws {
        let mediaType: MediaType? = .json
        XCTAssertTrue(.json ~= mediaType)
        XCTAssertTrue(.json ~= MediaType("application/json")!)
        XCTAssertTrue(.json ~= MediaType("application/json;charset=utf-8")!)
        XCTAssertFalse(.json ~= MediaType("application/opds+json")!)
        XCTAssertFalse(MediaType.json ~= nil)
        XCTAssertTrue(mediaType ~= .json)
        XCTAssertTrue(try XCTUnwrap(MediaType("application/json")) ~= .json)
        XCTAssertTrue(try XCTUnwrap(MediaType("application/json;charset=utf-8")) ~= .json)
        XCTAssertFalse(try XCTUnwrap(MediaType("application/opds+json") ~= .json))
    }

    func testPatternMatchEqualMediaType() throws {
        XCTAssertTrue(try XCTUnwrap(MediaType("text/html;charset=utf-8"))
            ~= MediaType("text/html;charset=utf-8")!)
    }

    func testPatternMatchNil() throws {
        XCTAssertFalse(try XCTUnwrap(MediaType("text/html;charset=utf-8")) ~= nil)
    }

    func testPatternMatchMustMatchParameters() throws {
        XCTAssertFalse(try XCTUnwrap(MediaType("text/html;charset=utf-8"))
            ~= MediaType("text/html;charset=ascii")!)
        XCTAssertTrue(try XCTUnwrap(MediaType("text/html;charset=utf-8")) ~= MediaType("text/html;charset=utf-8")!)
    }

    func testPatternMatchIgnoresParametersOrder() throws {
        XCTAssertTrue(try XCTUnwrap(MediaType("text/html;charset=utf-8;type=entry"))
            ~= MediaType("text/html;type=entry;charset=utf-8")!)
    }

    func testPatternMatchIgnoresExtraParameters() throws {
        XCTAssertTrue(try XCTUnwrap(MediaType("text/html")) ~= MediaType("text/html;charset=utf-8")!)
        XCTAssertTrue(try XCTUnwrap(MediaType("text/html;charset=utf-8")) ~= MediaType("text/html")!)
    }

    func testPatternMatchSupportsWildcards() throws {
        XCTAssertTrue(try XCTUnwrap(MediaType("*/*")) ~= MediaType("text/html;charset=utf-8")!)
        XCTAssertTrue(try XCTUnwrap(MediaType("text/*")) ~= MediaType("text/html;charset=utf-8")!)
        XCTAssertFalse(try XCTUnwrap(MediaType("text/*")) ~= MediaType("application/zip")!)
        XCTAssertTrue(try XCTUnwrap(MediaType("text/html;charset=utf-8")) ~= MediaType("*/*")!)
        XCTAssertTrue(try XCTUnwrap(MediaType("text/html;charset=utf-8")) ~= MediaType("text/*")!)
        XCTAssertFalse(try XCTUnwrap(MediaType("application/zip")) ~= MediaType("text/*")!)
    }

    func testIsZIP() throws {
        XCTAssertFalse(try XCTUnwrap(MediaType("text/plain")?.isZIP))
        XCTAssertTrue(try XCTUnwrap(MediaType("application/zip")?.isZIP))
        XCTAssertTrue(try XCTUnwrap(MediaType("application/zip;charset=utf-8")?.isZIP))
        XCTAssertTrue(try XCTUnwrap(MediaType("application/epub+zip")?.isZIP))
        // These media types must be explicitely matched since they don't have any ZIP hint
        XCTAssertTrue(try XCTUnwrap(MediaType("application/audiobook+lcp")?.isZIP))
        XCTAssertTrue(try XCTUnwrap(MediaType("application/pdf+lcp")?.isZIP))
    }

    func testIsJSON() throws {
        XCTAssertFalse(try XCTUnwrap(MediaType("text/plain")?.isJSON))
        XCTAssertTrue(try XCTUnwrap(MediaType("application/json")?.isJSON))
        XCTAssertTrue(try XCTUnwrap(MediaType("application/json;charset=utf-8")?.isJSON))
        XCTAssertTrue(try XCTUnwrap(MediaType("application/opds+json")?.isJSON))
    }

    func testIsOPDS() throws {
        XCTAssertFalse(try XCTUnwrap(MediaType("text/html")?.isOPDS))
        XCTAssertTrue(try XCTUnwrap(MediaType("application/atom+xml;profile=opds-catalog")?.isOPDS))
        XCTAssertTrue(try XCTUnwrap(MediaType("application/atom+xml;type=entry;profile=opds-catalog")?.isOPDS))
        XCTAssertTrue(try XCTUnwrap(MediaType("application/opds+json")?.isOPDS))
        XCTAssertTrue(try XCTUnwrap(MediaType("application/opds-publication+json")?.isOPDS))
        XCTAssertTrue(try XCTUnwrap(MediaType("application/opds+json;charset=utf-8")?.isOPDS))
        XCTAssertTrue(try XCTUnwrap(MediaType("application/opds-authentication+json")?.isOPDS))
    }

    func testIsHTML() throws {
        XCTAssertFalse(try XCTUnwrap(MediaType("application/opds+json")?.isHTML))
        XCTAssertTrue(try XCTUnwrap(MediaType("text/html")?.isHTML))
        XCTAssertTrue(try XCTUnwrap(MediaType("application/xhtml+xml")?.isHTML))
        XCTAssertTrue(try XCTUnwrap(MediaType("text/html;charset=utf-8")?.isHTML))
    }

    func testIsBitmap() throws {
        XCTAssertFalse(try XCTUnwrap(MediaType("text/html")?.isBitmap))
        XCTAssertTrue(try XCTUnwrap(MediaType("image/bmp")?.isBitmap))
        XCTAssertTrue(try XCTUnwrap(MediaType("image/gif")?.isBitmap))
        XCTAssertTrue(try XCTUnwrap(MediaType("image/jpeg")?.isBitmap))
        XCTAssertTrue(try XCTUnwrap(MediaType("image/jxl")?.isBitmap))
        XCTAssertTrue(try XCTUnwrap(MediaType("image/png")?.isBitmap))
        XCTAssertTrue(try XCTUnwrap(MediaType("image/tiff")?.isBitmap))
        XCTAssertTrue(try XCTUnwrap(MediaType("image/webp")?.isBitmap))
        XCTAssertTrue(try XCTUnwrap(MediaType("image/tiff;charset=utf-8")?.isBitmap))
    }

    func testIsAudio() throws {
        XCTAssertFalse(try XCTUnwrap(MediaType("text/html")?.isAudio))
        XCTAssertTrue(try XCTUnwrap(MediaType("audio/unknown")?.isAudio))
        XCTAssertTrue(try XCTUnwrap(MediaType("audio/mpeg;param=value")?.isAudio))
    }

    func testIsVideo() throws {
        XCTAssertFalse(try XCTUnwrap(MediaType("text/html")?.isVideo))
        XCTAssertTrue(try XCTUnwrap(MediaType("video/unknown")?.isVideo))
        XCTAssertTrue(try XCTUnwrap(MediaType("video/mpeg;param=value")?.isVideo))
    }

    func testIsRWPM() throws {
        XCTAssertFalse(try XCTUnwrap(MediaType("text/html")?.isRWPM))
        XCTAssertTrue(try XCTUnwrap(MediaType("application/audiobook+json")?.isRWPM))
        XCTAssertTrue(try XCTUnwrap(MediaType("application/divina+json")?.isRWPM))
        XCTAssertTrue(try XCTUnwrap(MediaType("application/webpub+json")?.isRWPM))
        XCTAssertTrue(try XCTUnwrap(MediaType("application/webpub+json;charset=utf-8")?.isRWPM))
    }
}
