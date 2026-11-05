//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

enum LanguageTests {
    struct Equality {
        @Test(arguments: ["en-US", "en-us", "EN-US", "en_US"] as [Language])
        func ignoresCaseAndSeparator(_ language: Language) {
            #expect(language == "en-US")
            #expect(language.hashValue == ("en-US" as Language).hashValue)
        }

        @Test func matchesDictionaryKeys() {
            let voices: [Language: String] = ["en-US": "Samantha"]
            #expect(voices["en_us"] == "Samantha")
        }

        @Test func distinguishesRegions() {
            #expect(("en-US" as Language) != "en-GB")
            #expect(("en-US" as Language) != "en")
        }

        @Test func keepsTheOriginalCode() {
            #expect(("en_us" as Language).code.bcp47 == "en_us")
        }
    }
}
