//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing

enum LanguageTests {
    struct IsRTL {
        @Test(arguments: [
            "ar", "fa", "he",
            "ar-EG", "ar-Arab", "fa-Arab-IR",
            "zh-Hant", "zh-TW", "ZH-HANT", "zh_TW@calendar=roc",
        ] as [Language])
        func rtl(_ language: Language) {
            #expect(language.isRTL)
        }

        @Test(arguments: [
            "", "en", "es-AR", "ja",
            // Codes sharing a prefix with an RTL language.
            "arn", "far", "her",
            // Only the exact `zh-Hant` and `zh-TW` tags are RTL.
            "zh", "zh-CN", "zh-Hans", "zh-HK", "zh-Hant-TW",
        ] as [Language])
        func notRTL(_ language: Language) {
            #expect(!language.isRTL)
        }
    }

    struct IsCJK {
        @Test(arguments: [
            "zh", "ja", "ko",
            "ja-JP", "ja-Latn", "zh-Hant-TW",
        ] as [Language])
        func cjk(_ language: Language) {
            #expect(language.isCJK)
        }

        @Test(arguments: [
            "", "en", "en-JP", "ar", "mn-Mong",
            // Codes sharing a prefix with a CJK language.
            "zha", "jav", "kok",
        ] as [Language])
        func notCJK(_ language: Language) {
            #expect(!language.isCJK)
        }
    }
}
