//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest
import R2Shared
@testable import R2Navigator

class PreferencesTests: XCTestCase {

    func testCreateFromBuilder() {
        XCTAssertEqual(
            Preferences {
                $0.set(publisherStyles, to: true)
                $0.set(fontSize, to: 1.2)
            },
            Preferences(json: [
                "publisherStyles": true,
                "fontSize": 1.2,
            ])
        )
    }

    func testParseEmptyJSON() {
        XCTAssertEqual(try Preferences(jsonString: "{}"), Preferences())
    }

    func testParseInvalidJSON() {
        XCTAssertThrowsError(try Preferences(jsonString: ""))
        XCTAssertThrowsError(try Preferences(jsonString: "invalid"))
    }

    func testParseFromValidJSON() {
        XCTAssertEqual(
            try Preferences(jsonString: """
                {"fontSize":1.2,"publisherStyles":false,"readingProgression":"ltr"}
                """),
            Preferences {
                $0.set(publisherStyles, to: false)
                $0.set(fontSize, to: 1.2)
                $0.set(readingProgression, to: .ltr)
            }
        )
    }

    func testSerializeToJSON() {
        AssertJSONEqual(
            Preferences {
                $0.set(publisherStyles, to: false)
                $0.set(fontSize, to: 1.2)
                $0.set(readingProgression, to: .ltr)
            }.json,
            [
                "publisherStyles": false,
                "fontSize": 1.2,
                "readingProgression": "ltr"
            ]
        )
    }

    func testGetPreference() {
        let prefs = Preferences(json: [
            "publisherStyles": false,
            "fontSize": 1.2,
            "readingProgression": "ltr"
        ])

        XCTAssertNil(prefs[fit])
        XCTAssertEqual(prefs[publisherStyles], false)
        XCTAssertEqual(prefs[fontSize], 1.2)
        XCTAssertEqual(prefs[readingProgression], .ltr)
    }

    func testSetPreference() {
        var prefs = Preferences(json: [
            "publisherStyles": false,
            "fontSize": 1.2,
        ])
        prefs.set(publisherStyles, to: true)
        prefs.set(fontSize, to: nil)
        prefs.set(fit, to: .contain)

        XCTAssertEqual(
            prefs,
            Preferences(json: [
                "publisherStyles": true,
                "fit": "contain",
            ])
        )
    }

    func testRemovePreference() {
        var prefs = Preferences(json: [
            "fontSize": 1.2,
            "readingProgression": "ltr"
        ])
        prefs.remove(readingProgression)
        XCTAssertEqual(prefs, Preferences(json: ["fontSize": 1.2]))
    }

    func testClearPreferences() {
        var prefs = Preferences(json: [
            "fontSize": 1.2,
            "readingProgression": "ltr"
        ])
        prefs.clear()
        XCTAssertEqual(prefs, Preferences())
    }

    func testMergePreferences() {
        var prefs = Preferences(json: [
            "publisherStyles": true,
            "fontSize": 1.2,
        ])

        prefs.merge(Preferences(json: [
            "publisherStyles": false,
            "readingProgression": "ltr"
        ]))

        XCTAssertEqual(prefs, Preferences(json: [
            "publisherStyles": false,
            "fontSize": 1.2,
            "readingProgression": "ltr"
        ]))
    }

    func testIsSettingActive() {
        XCTAssertFalse(Preferences(json: [
            "wordSpacing": 0.4
        ]).isActive(wordSpacing))

        XCTAssertFalse(Preferences(json: [
            "wordSpacing": 0.4,
            "publisherStyles": true
        ]).isActive(wordSpacing))

        XCTAssertTrue(Preferences(json: [
            "wordSpacing": 0.4,
            "publisherStyles": false
        ]).isActive(wordSpacing))
    }

    func testActivateSetting() {
        var prefs = Preferences(json: [
            "wordSpacing": 0.4
        ])

        prefs.activate(wordSpacing)

        XCTAssertEqual(prefs, Preferences(json: [
            "wordSpacing": 0.4,
            "publisherStyles": false
        ]))

        prefs = Preferences(json: [
            "wordSpacing": 0.4,
            "publisherStyles": true
        ])

        prefs.activate(wordSpacing)

        XCTAssertEqual(prefs, Preferences(json: [
            "wordSpacing": 0.4,
            "publisherStyles": false
        ]))
    }

    func testAutoActivationOnSet() {
        var prefs = Preferences(json: [
            "wordSpacing": 0.4
        ])

        prefs.set(wordSpacing, to: 0.5)

        XCTAssertEqual(prefs, Preferences(json: [
            "wordSpacing": 0.5,
            "publisherStyles": false
        ]))
    }

    func testDisableAutoActivationOnSet() {
        var prefs = Preferences(json: [
            "wordSpacing": 0.4
        ])

        prefs.set(wordSpacing, to: 0.5, activate: false)

        XCTAssertEqual(prefs, Preferences(json: [
            "wordSpacing": 0.5,
        ]))
    }

    func testUpdatePreferenceFromCurrentValue() {
        var prefs = Preferences(json: [
            "fontSize": 0.4
        ])
        prefs.update(fontSize) { $0 + 0.4 }

        XCTAssertEqual(prefs, Preferences(json: [
            "fontSize": 0.8,
        ]))
    }

    func testInvertABooleanSetting() {
        var prefs = Preferences(json: [
            "publisherStyles": false
        ])

        XCTAssertEqual(prefs[publisherStyles], false)
        prefs.toggle(publisherStyles)
        XCTAssertEqual(prefs[publisherStyles], true)
        prefs.toggle(publisherStyles)
        XCTAssertEqual(prefs[publisherStyles], false)
    }

    func testToggleEnumSetting() {
        var prefs = Preferences()

        // toggles on
        prefs.toggle(fit, preference: .contain)
        XCTAssertEqual(prefs[fit], .contain)
        prefs.toggle(fit, preference: .width)
        XCTAssertEqual(prefs[fit], .width)

        // toggles off
        prefs.toggle(fit, preference: .width)
        XCTAssertEqual(prefs[fit], nil)
    }

    func testIncrementDecrementBySuggestedSteps() {
        var prefs = Preferences()
        prefs.set(fontSize, to: 0.5)
        XCTAssertEqual(prefs[fontSize], 0.5)
        prefs.increment(fontSize)
        XCTAssertEqual(prefs[fontSize], 0.8)
        prefs.increment(fontSize)
        XCTAssertEqual(prefs[fontSize], 1.0)
        prefs.increment(fontSize)
        XCTAssertEqual(prefs[fontSize], 2.0)
        prefs.increment(fontSize)
        XCTAssertEqual(prefs[fontSize], 3.0)
        prefs.increment(fontSize)
        XCTAssertEqual(prefs[fontSize], 5.0)
        prefs.increment(fontSize)
        XCTAssertEqual(prefs[fontSize], 5.0)
        prefs.decrement(fontSize)
        XCTAssertEqual(prefs[fontSize], 3.0)
        prefs.decrement(fontSize)
        XCTAssertEqual(prefs[fontSize], 2.0)
        prefs.decrement(fontSize)
        XCTAssertEqual(prefs[fontSize], 1.0)
        prefs.decrement(fontSize)
        XCTAssertEqual(prefs[fontSize], 0.8)
        prefs.decrement(fontSize)
        XCTAssertEqual(prefs[fontSize], 0.5)
        prefs.decrement(fontSize)
        XCTAssertEqual(prefs[fontSize], 0.5)

        // from unknown starting value
        prefs.set(fontSize, to: 0.9)
        prefs.increment(fontSize)
        XCTAssertEqual(prefs[fontSize], 1.0)
        prefs.set(fontSize, to: 0.9)
        prefs.decrement(fontSize)
        XCTAssertEqual(prefs[fontSize], 0.8)
    }

    func testIncrementDecrementBySuggestedIncrement() {
        var prefs = Preferences()
        prefs.set(pageMargins, to: 1.0)
        XCTAssertEqual(prefs[pageMargins], 1.0)
        prefs.increment(pageMargins)
        XCTAssertEqual(prefs[pageMargins], 1.5)
        prefs.increment(pageMargins)
        XCTAssertEqual(prefs[pageMargins], 2.0)
        prefs.increment(pageMargins)
        XCTAssertEqual(prefs[pageMargins], 2.0)
        prefs.decrement(pageMargins)
        XCTAssertEqual(prefs[pageMargins], 1.5)
        prefs.decrement(pageMargins)
        XCTAssertEqual(prefs[pageMargins], 1.0)
        prefs.decrement(pageMargins)
        XCTAssertEqual(prefs[pageMargins], 1.0)

        // from arbitrary starting value
        prefs.set(pageMargins, to: 1.1)
        prefs.increment(pageMargins)
        XCTAssertEqual(prefs[pageMargins], 1.6)
        prefs.increment(pageMargins)
        XCTAssertEqual(prefs[pageMargins], 2.0)

        prefs.set(pageMargins, to: 1.9)
        prefs.decrement(pageMargins)
        XCTAssertEqual(prefs[pageMargins], 1.4)
        prefs.decrement(pageMargins)
        XCTAssertEqual(prefs[pageMargins], 1.0)
    }

    func testIncrementDecrementByProvidedAmount() {
        var prefs = Preferences()
        prefs.set(columnCount, to: 1)
        XCTAssertEqual(prefs[columnCount], 1)
        prefs.adjustBy(columnCount, amount: 1)
        XCTAssertEqual(prefs[columnCount], 2)
        prefs.adjustBy(columnCount, amount: 1)
        XCTAssertEqual(prefs[columnCount], 3)
        prefs.adjustBy(columnCount, amount: 1)
        XCTAssertEqual(prefs[columnCount], 4)
        prefs.adjustBy(columnCount, amount: 1)
        XCTAssertEqual(prefs[columnCount], 5)
        prefs.adjustBy(columnCount, amount: 1)
        XCTAssertEqual(prefs[columnCount], 5)
        prefs.adjustBy(columnCount, amount: -1)
        XCTAssertEqual(prefs[columnCount], 4)
        prefs.adjustBy(columnCount, amount: -1)
        XCTAssertEqual(prefs[columnCount], 3)
        prefs.adjustBy(columnCount, amount: -1)
        XCTAssertEqual(prefs[columnCount], 2)
        prefs.adjustBy(columnCount, amount: -1)
        XCTAssertEqual(prefs[columnCount], 1)
        prefs.adjustBy(columnCount, amount: -1)
        XCTAssertEqual(prefs[columnCount], 1)
    }

    // Fixtures
    
    let readingProgression: EnumSetting<ReadingProgression> = EnumSetting(
        key: SettingKey("readingProgression"),
        value: .ltr,
        values: [.ltr, .rtl]
    )

    let fontSize: PercentSetting = PercentSetting(
        key: SettingKey("fontSize"),
        value: 1.0,
        range: 0.4...5.0,
        suggestedProgression: StepsProgressionStrategy(steps: [0.5, 0.8, 1.0, 2.0, 3.0, 5.0])
            .eraseToAnyProgressionStrategy()
    )

    let pageMargins: RangeSetting<Double> = RangeSetting(
        key: SettingKey("pageMargins"),
        value: 1.0,
        range: 1.0...2.0,
        suggestedProgression: IncrementProgressionStrategy(increment: 0.5).eraseToAnyProgressionStrategy()
)

    let columnCount: RangeSetting<Int> = RangeSetting(
        key: SettingKey("columnCount"),
        value: 1,
        range: 1...5
    )

    let fit: EnumSetting<Presentation.Fit> = EnumSetting(
        key: SettingKey("fit"),
        value: .contain,
        values: [.contain, .cover, .width, .height]
    )

    let publisherStyles: Setting<Bool> = Setting(
        key: SettingKey("publisherStyles"),
        value: true
    )

    let wordSpacing: PercentSetting = PercentSetting(
        key: SettingKey("wordSpacing"),
        value: 0.0,
        activator: MockPublisherStylesSettingActivator()
    )

    class MockPublisherStylesSettingActivator: SettingActivator {
        let key = SettingKey<Bool>("publisherStyles")
        
        func isActive(with preferences: Preferences) -> Bool {
            (try? preferences.get(key) ?? true) == false
        }

        func activate(in preferences: inout Preferences) {
            preferences.set(key, to: false)
        }
    }

}
