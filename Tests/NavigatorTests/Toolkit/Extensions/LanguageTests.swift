//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing

struct LanguageTests {
    struct IsRTL {
        @Test(arguments: [
            "ar", "fa", "he",
            "ar-EG", "fa-Arab-IR", "HE", "he_IL",
            "zh-Hant", "zh-TW", "ZH-HANT", "zh_TW", "zh_TW@calendar=roc",
        ])
        func rtl(_ code: String) {
            #expect(Language(code: .bcp47(code)).isRTL)
        }

        @Test(arguments: [
            "", "-ar", "en", "es-AR", "ja",
            // Codes sharing a prefix with an RTL language.
            "arn", "far", "her",
            // Only the exact `zh-Hant` and `zh-TW` tags are RTL.
            "zh", "zh-CN", "zh-Hans", "zh-HK", "zh-Hant-TW",
        ])
        func notRTL(_ code: String) {
            #expect(!Language(code: .bcp47(code)).isRTL)
        }
    }

    struct IsCJK {
        @Test(arguments: [
            "zh", "ja", "ko",
            "ja-JP", "ja-Latn", "zh-Hant-TW", "KO", "zh_CN",
        ])
        func cjk(_ code: String) {
            #expect(Language(code: .bcp47(code)).isCJK)
        }

        @Test(arguments: [
            "", "-ja", "en", "en-JP", "ar", "mn-Mong",
            // Codes sharing a prefix with a CJK language.
            "zha", "jav", "kok",
        ])
        func notCJK(_ code: String) {
            #expect(!Language(code: .bcp47(code)).isCJK)
        }
    }
}
