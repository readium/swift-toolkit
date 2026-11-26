//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumNavigator
import Testing

enum LegacyPreferencesTests {
    @Suite("LegacyEPUBPreferences") struct EPUB {
        @Test("decodes every 3.x preference from its own key")
        func decodesCodingKeys() throws {
            let prefs = try decode(LegacyEPUBPreferences.self, """
            {
              "backgroundColor": 16711680,
              "columnCount": "2",
              "fit": "width",
              "fontFamily": "Literata",
              "fontSize": 1.4,
              "fontWeight": 1.75,
              "hyphens": true,
              "imageFilter": "invert",
              "language": "fr",
              "letterSpacing": 0.1,
              "ligatures": false,
              "lineHeight": 1.6,
              "offsetFirstPage": true,
              "pageMargins": 1.5,
              "paragraphIndent": 1.1,
              "paragraphSpacing": 0.5,
              "publisherStyles": false,
              "readingProgression": "rtl",
              "scroll": true,
              "spread": "always",
              "textAlign": "justify",
              "textColor": 65280,
              "textNormalization": true,
              "theme": "sepia",
              "typeScale": 1.2,
              "verticalText": true,
              "wordSpacing": 0.2
            }
            """)
            #expect(prefs == LegacyEPUBPreferences(
                backgroundColor: 0xFF0000,
                columnCount: .two,
                fit: .width,
                fontFamily: "Literata",
                fontSize: 1.4,
                fontWeight: 1.75,
                hyphens: true,
                imageFilter: .invert,
                language: "fr",
                letterSpacing: 0.1,
                ligatures: false,
                lineHeight: 1.6,
                offsetFirstPage: true,
                pageMargins: 1.5,
                paragraphIndent: 1.1,
                paragraphSpacing: 0.5,
                publisherStyles: false,
                readingProgression: .rtl,
                scroll: true,
                spread: .always,
                textAlign: .justify,
                textColor: 0x00FF00,
                textNormalization: true,
                theme: .sepia,
                typeScale: 1.2,
                verticalText: true,
                wordSpacing: 0.2
            ))
        }

        @Test("an invalid value drops only its preference")
        func invalidValue() throws {
            let prefs = try decode(LegacyEPUBPreferences.self, #"{"fontSize": "big", "textColor": "red", "theme": "night", "columnCount": 2, "lineHeight": 1.5}"#)
            #expect(try prefs == decode(LegacyEPUBPreferences.self, #"{"lineHeight": 1.5}"#))
        }
    }

    @Suite("LegacyPDFPreferences") struct PDF {
        @Test("decodes every 3.x preference from its own key")
        func decodesCodingKeys() throws {
            let prefs = try decode(LegacyPDFPreferences.self, """
            {
              "backgroundColor": 16711680,
              "fit": "width",
              "offsetFirstPage": true,
              "pageSpacing": 12.5,
              "readingProgression": "rtl",
              "scroll": true,
              "scrollAxis": "horizontal",
              "spread": "always",
              "visibleScrollbar": false
            }
            """)
            #expect(prefs == LegacyPDFPreferences(
                backgroundColor: 0xFF0000,
                fit: .width,
                offsetFirstPage: true,
                pageSpacing: 12.5,
                readingProgression: .rtl,
                scroll: true,
                scrollAxis: .horizontal,
                spread: .always,
                visibleScrollbar: false
            ))
        }

        @Test("an invalid value drops only its preference")
        func invalidValue() throws {
            let prefs = try decode(LegacyPDFPreferences.self, #"{"fit": "unknown", "scrollAxis": 1, "backgroundColor": "red", "scroll": true}"#)
            #expect(try prefs == decode(LegacyPDFPreferences.self, #"{"scroll": true}"#))
        }
    }

    @Suite("LegacyAudioPreferences") struct Audio {
        @Test("decodes every 3.x preference from its own key")
        func decodesCodingKeys() throws {
            let prefs = try decode(LegacyAudioPreferences.self, #"{"volume": 0.5, "speed": 1.5}"#)
            #expect(prefs == LegacyAudioPreferences(volume: 0.5, speed: 1.5))
        }

        @Test("an invalid value drops only its preference")
        func invalidValue() throws {
            let prefs = try decode(LegacyAudioPreferences.self, #"{"volume": "loud", "speed": 2}"#)
            #expect(prefs == LegacyAudioPreferences(volume: nil, speed: 2))
        }

        @Test("keeps the values out of the ranges supported by AudioPreferences")
        func outOfRange() throws {
            let prefs = try decode(LegacyAudioPreferences.self, #"{"volume": 1.5, "speed": -1}"#)
            #expect(prefs == LegacyAudioPreferences(volume: 1.5, speed: -1))
        }
    }

    @Suite("Legacy preferences") struct All {
        @Test("a payload which is not an object fails to decode", arguments: [#"[]"#, #""dark""#, "1"])
        func notAnObject(json: String) {
            #expect(throws: DecodingError.self) { try decode(LegacyEPUBPreferences.self, json) }
            #expect(throws: DecodingError.self) { try decode(LegacyPDFPreferences.self, json) }
            #expect(throws: DecodingError.self) { try decode(LegacyAudioPreferences.self, json) }
        }
    }
}

private func decode<L: Decodable>(_ type: L.Type, _ json: String) throws -> L {
    try JSONDecoder().decode(L.self, from: Data(json.utf8))
}
