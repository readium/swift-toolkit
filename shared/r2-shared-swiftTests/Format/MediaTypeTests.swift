//
//  MediaTypeTests.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 10/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class MediaTypeTests: XCTestCase {

    func testInvalidTypesReturnsNil() {
        XCTAssertNil(MediaType("application"))
        XCTAssertNil(MediaType("application/atom+xml/extra"))
    }

    func testGetString() {
        XCTAssertEqual(
            MediaType("application/atom+xml;profile=opds-catalog")!.string,
            "application/atom+xml;profile=opds-catalog"
        )
    }
    
    func testGetStringNormalizes() {
        XCTAssertEqual(
            MediaType("APPLICATION/ATOM+XML;PROFILE=OPDS-CATALOG   ;   a=0")!.string,
            "application/atom+xml;a=0;profile=OPDS-CATALOG"
        )
        // Parameters are sorted by name
        XCTAssertEqual(
            MediaType("application/atom+xml;a=0;b=1")!.string,
            "application/atom+xml;a=0;b=1"
        )
        XCTAssertEqual(
            MediaType("application/atom+xml;b=1;a=0")!.string,
            "application/atom+xml;a=0;b=1"
        )
    }
    
    func testGetType() {
        XCTAssertEqual(
            MediaType("application/atom+xml;profile=opds-catalog")!.type,
            "application"
        )
        XCTAssertEqual(MediaType("*/jpeg")!.type, "*")
    }

    func testGetSubtype() {
        XCTAssertEqual(
            MediaType("application/atom+xml;profile=opds-catalog")!.subtype,
            "atom+xml"
        )
        XCTAssertEqual(MediaType("image/*")!.subtype, "*")
    }

    func testGetParameters() {
        XCTAssertEqual(
            MediaType("application/atom+xml;type=entry;profile=opds-catalog")!.parameters,
            [
                "type": "entry",
                "profile": "opds-catalog"
            ]
        )
    }
    
    func testGetEmptyParameters() {
        XCTAssertTrue(MediaType("application/atom+xml")!.parameters.isEmpty)
    }
    
    func testGetParametersWithWhitespaces() {
        XCTAssertEqual(
            MediaType("application/atom+xml    ;    type=entry   ;    profile=opds-catalog   ")!.parameters,
            [
                "type": "entry",
                "profile": "opds-catalog"
            ]
        )
    }
    
    func testGetStructuredSyntaxSuffix() {
        XCTAssertNil(MediaType("foo/bar")!.structuredSyntaxSuffix)
        XCTAssertNil(MediaType("application/zip")!.structuredSyntaxSuffix)
        XCTAssertEqual(MediaType("application/epub+zip")!.structuredSyntaxSuffix, "+zip")
        XCTAssertEqual(MediaType("foo/bar+json+zip")!.structuredSyntaxSuffix, "+zip")
    }
    
    func testGetEncoding() {
        XCTAssertNil(MediaType("text/html")!.encoding)
        XCTAssertEqual(MediaType("text/html;charset=utf-8")!.encoding, .utf8)
    }
    
    func testTypeSubtypeAndParameterNamesAreLowercased() {
        let mediaType = MediaType("APPLICATION/ATOM+XML;PROFILE=OPDS-CATALOG")!
        XCTAssertEqual(mediaType.type, "application")
        XCTAssertEqual(mediaType.subtype, "atom+xml")
        XCTAssertEqual(mediaType.parameters, ["profile": "OPDS-CATALOG"])
    }
    
    func testCharsetValueIsUppercased() {
        XCTAssertEqual(MediaType("text/html;charset=utf-8")!.parameters["charset"], "UTF-8")
    }
    
    func testEquals() {
        XCTAssertEqual(MediaType("application/atom+xml")!, MediaType("application/atom+xml")!)
        XCTAssertEqual(MediaType("application/atom+xml;profile=opds-catalog")!, MediaType("application/atom+xml;profile=opds-catalog")!)
        XCTAssertNotEqual(MediaType("application/atom+xml")!, MediaType("application/atom")!)
        XCTAssertNotEqual(MediaType("application/atom+xml")!, MediaType("text/atom+xml")!)
        XCTAssertNotEqual(MediaType("application/atom+xml;profile=opds-catalog")!, MediaType("application/atom+xml")!)
    }
    
    func testEqualsIgnoresCaseOfTypeSubtypeAndParameterNames() {
        XCTAssertEqual(
            MediaType("application/atom+xml;profile=opds-catalog")!,
            MediaType("APPLICATION/ATOM+XML;PROFILE=opds-catalog")!
        )
        XCTAssertNotEqual(
            MediaType("application/atom+xml;profile=opds-catalog")!,
            MediaType("APPLICATION/ATOM+XML;PROFILE=OPDS-CATALOG")!
        )
    }
    
    func testEqualsIgnoresParametersOrder() {
        XCTAssertEqual(
            MediaType("application/atom+xml;type=entry;profile=opds-catalog")!,
            MediaType("application/atom+xml;profile=opds-catalog;type=entry")!
        )
    }
    
    func testEqualsIgnoresCharsetCase() {
        XCTAssertEqual(
            MediaType("application/atom+xml;charset=utf-8")!,
            MediaType("application/atom+xml;charset=UTF-8")
        )
    }
    
    func testContainsEqualMediaType() {
        XCTAssertTrue(MediaType("text/html;charset=utf-8")!
            .contains(MediaType("text/html;charset=utf-8")!))
    }
    
    func testContainsMustMatchParameters() {
        XCTAssertFalse(MediaType("text/html;charset=utf-8")!
            .contains(MediaType("text/html;charset=ascii")!))
        XCTAssertFalse(MediaType("text/html;charset=utf-8")!
            .contains(MediaType("text/html")!))
    }
    
    func testContainsIgnoresParametersOrder() {
        XCTAssertTrue(MediaType("text/html;charset=utf-8;type=entry")!
            .contains(MediaType("text/html;type=entry;charset=utf-8")!))
    }
    
    func testContainsIgnoresExtraParameters() {
        XCTAssertTrue(MediaType("text/html")!
            .contains(MediaType("text/html;charset=utf-8")!))
    }
    
    func testContainsSupportsWildcards() {
        XCTAssertTrue(MediaType("*/*")!
            .contains(MediaType("text/html;charset=utf-8")!))
        XCTAssertTrue(MediaType("text/*")!
            .contains(MediaType("text/html;charset=utf-8")!))
        XCTAssertFalse(MediaType("text/*")!
            .contains(MediaType("application/zip")!))
    }
    
    func testContainsFromString() {
        XCTAssertTrue(MediaType("text/html;charset=utf-8")!
            .contains("text/html;charset=utf-8"))
    }
    
    func testMatchesEqualMediaType() {
        XCTAssertTrue(MediaType("text/html;charset=utf-8")!
            .matches(MediaType("text/html;charset=utf-8")!))
    }
    
    func testMatchesMustMatchParameters() {
        XCTAssertFalse(MediaType("text/html;charset=ascii")!
            .matches(MediaType("text/html;charset=utf-8")!))
    }
    
    func testMatchesIgnoresParametersOrder() {
        XCTAssertTrue(MediaType("text/html;charset=utf-8;type=entry")!
            .matches(MediaType("text/html;type=entry;charset=utf-8")!))
    }
    
    func testMatchesIgnoresExtraParameters() {
        XCTAssertTrue(MediaType("text/html;charset=utf-8")!
            .matches(MediaType("text/html;charset=utf-8;extra=param")!))
        XCTAssertTrue(MediaType("text/html;charset=utf-8;extra=param")!
            .matches(MediaType("text/html;charset=utf-8")!))
    }
    
    func testMatchesSupportsWildcards() {
        XCTAssertTrue(MediaType("text/html;charset=utf-8")!.matches(MediaType("*/*")!))
        XCTAssertTrue(MediaType("text/html;charset=utf-8")!.matches(MediaType("text/*")!))
        XCTAssertFalse(MediaType("application/zip")!.matches(MediaType("text/*")!))
        XCTAssertTrue(MediaType("*/*")!.matches(MediaType("text/html;charset=utf-8")!))
        XCTAssertTrue(MediaType("text/*")!.matches(MediaType("text/html;charset=utf-8")!))
        XCTAssertFalse(MediaType("text/*")!.matches(MediaType("application/zip")!))
    }
    
    func testMatchesFromString() {
        XCTAssertTrue(MediaType("text/html;charset=utf-8")!.matches("text/html;charset=utf-8"))
    }
    
    func testMatchesAnyMediaTypes() {
        XCTAssertTrue(MediaType("text/html")!
            .matchesAny(MediaType("application/zip")!, MediaType("text/html;charset=utf-8")!))
        XCTAssertFalse(MediaType("text/html")!
            .matchesAny(MediaType("application/zip")!, MediaType("text/plain;charset=utf-8")!))
        XCTAssertTrue(MediaType("text/html")!
            .matchesAny("application/zip", "text/html;charset=utf-8"))
        XCTAssertFalse(MediaType("text/html")!
            .matchesAny("application/zip", "text/plain;charset=utf-8"))
    }
    
    func testPatternMatch() {
        let mediaType: MediaType? = .json
        XCTAssertTrue(.json ~= mediaType)
        XCTAssertTrue(.json ~= MediaType("application/json")!)
        XCTAssertTrue(.json ~= MediaType("application/json;charset=utf-8")!)
        XCTAssertFalse(.json ~= MediaType("application/opds+json")!)
        XCTAssertFalse(MediaType.json ~= nil)
        XCTAssertTrue(mediaType ~= .json)
        XCTAssertTrue(MediaType("application/json")! ~= .json)
        XCTAssertTrue(MediaType("application/json;charset=utf-8")! ~= .json)
        XCTAssertFalse(MediaType("application/opds+json")! ~= .json)
    }

    func testPatternMatchEqualMediaType() {
        XCTAssertTrue(MediaType("text/html;charset=utf-8")!
            ~= MediaType("text/html;charset=utf-8")!)
    }
    
    func testPatternMatchNil() {
        XCTAssertFalse(MediaType("text/html;charset=utf-8")! ~= nil)
    }
    
    func testPatternMatchMustMatchParameters() {
        XCTAssertFalse(MediaType("text/html;charset=utf-8")!
            ~= MediaType("text/html;charset=ascii")!)
        XCTAssertTrue(MediaType("text/html;charset=utf-8")! ~= MediaType("text/html;charset=utf-8")!)
    }
    
    func testPatternMatchIgnoresParametersOrder() {
        XCTAssertTrue(MediaType("text/html;charset=utf-8;type=entry")!
            ~= MediaType("text/html;type=entry;charset=utf-8")!)
    }
    
    func testPatternMatchIgnoresExtraParameters() {
        XCTAssertTrue(MediaType("text/html")! ~= MediaType("text/html;charset=utf-8")!)
        XCTAssertTrue(MediaType("text/html;charset=utf-8")! ~= MediaType("text/html")!)
    }
    
    func testPatternMatchSupportsWildcards() {
        XCTAssertTrue(MediaType("*/*")! ~= MediaType("text/html;charset=utf-8")!)
        XCTAssertTrue(MediaType("text/*")! ~= MediaType("text/html;charset=utf-8")!)
        XCTAssertFalse(MediaType("text/*")! ~= MediaType("application/zip")!)
        XCTAssertTrue(MediaType("text/html;charset=utf-8")! ~= MediaType("*/*")!)
        XCTAssertTrue(MediaType("text/html;charset=utf-8")! ~= MediaType("text/*")!)
        XCTAssertFalse(MediaType("application/zip")! ~= MediaType("text/*")!)
    }

    func testIsZIP() {
        XCTAssertFalse(MediaType("text/plain")!.isZIP)
        XCTAssertTrue(MediaType("application/zip")!.isZIP)
        XCTAssertTrue(MediaType("application/zip;charset=utf-8")!.isZIP)
        XCTAssertTrue(MediaType("application/epub+zip")!.isZIP)
        // These media types must be explicitely matched since they don't have any ZIP hint
        XCTAssertTrue(MediaType("application/audiobook+lcp")!.isZIP)
        XCTAssertTrue(MediaType("application/pdf+lcp")!.isZIP)
    }

    func testIsJSON() {
        XCTAssertFalse(MediaType("text/plain")!.isJSON)
        XCTAssertTrue(MediaType("application/json")!.isJSON)
        XCTAssertTrue(MediaType("application/json;charset=utf-8")!.isJSON)
        XCTAssertTrue(MediaType("application/opds+json")!.isJSON)
    }

    func testIsOPDS() {
        XCTAssertFalse(MediaType("text/html")!.isOPDS)
        XCTAssertTrue(MediaType("application/atom+xml;profile=opds-catalog")!.isOPDS)
        XCTAssertTrue(MediaType("application/atom+xml;type=entry;profile=opds-catalog")!.isOPDS)
        XCTAssertTrue(MediaType("application/opds+json")!.isOPDS)
        XCTAssertTrue(MediaType("application/opds-publication+json")!.isOPDS)
        XCTAssertTrue(MediaType("application/opds+json;charset=utf-8")!.isOPDS)
        XCTAssertTrue(MediaType("application/opds-authentication+json")!.isOPDS)
    }
    
    func testIsHTML() {
        XCTAssertFalse(MediaType("application/opds+json")!.isHTML)
        XCTAssertTrue(MediaType("text/html")!.isHTML)
        XCTAssertTrue(MediaType("application/xhtml+xml")!.isHTML)
        XCTAssertTrue(MediaType("text/html;charset=utf-8")!.isHTML)
    }
    
    func testIsBitmap() {
        XCTAssertFalse(MediaType("text/html")!.isBitmap)
        XCTAssertTrue(MediaType("image/bmp")!.isBitmap)
        XCTAssertTrue(MediaType("image/gif")!.isBitmap)
        XCTAssertTrue(MediaType("image/jpeg")!.isBitmap)
        XCTAssertTrue(MediaType("image/png")!.isBitmap)
        XCTAssertTrue(MediaType("image/tiff")!.isBitmap)
        XCTAssertTrue(MediaType("image/tiff")!.isBitmap)
        XCTAssertTrue(MediaType("image/tiff;charset=utf-8")!.isBitmap)
    }
    
    func testIsAudio() {
        XCTAssertFalse(MediaType("text/html")!.isAudio)
        XCTAssertTrue(MediaType("audio/unknown")!.isAudio)
        XCTAssertTrue(MediaType("audio/mpeg;param=value")!.isAudio)
    }
    
    func testIsRWPM() {
        XCTAssertFalse(MediaType("text/html")!.isRWPM)
        XCTAssertTrue(MediaType("application/audiobook+json")!.isRWPM)
        XCTAssertTrue(MediaType("application/divina+json")!.isRWPM)
        XCTAssertTrue(MediaType("application/webpub+json")!.isRWPM)
        XCTAssertTrue(MediaType("application/webpub+json;charset=utf-8")!.isRWPM)
    }
    
    func testIsLCPProtected() {
        XCTAssertFalse(MediaType("text/html")!.isLCPProtected)
        XCTAssertTrue(MediaType("application/pdf+lcp")!.isLCPProtected)
        XCTAssertTrue(MediaType("application/audiobook+lcp")!.isLCPProtected)
        XCTAssertTrue(MediaType("application/audiobook+lcp;param=value")!.isLCPProtected)
    }

}
