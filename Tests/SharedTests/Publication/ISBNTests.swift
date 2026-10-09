//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

struct ISBNTests {
    @Test(arguments: [
        ("0306406152", "0306406152"),
        ("9780306406157", "9780306406157"),
        ("9791090636071", "9791090636071"),
        ("080442957X", "080442957X"),
        ("080442957x", "080442957X"),
        ("978-0-306-40615-7", "9780306406157"),
        ("978 0 306 40615 7", "9780306406157"),
        (" 0-306-40615-2 ", "0306406152"),
        ("0-8044-2957-x", "080442957X"),
    ])
    func normalizes(rawValue: String, expected: String) {
        #expect(ISBN(rawValue: rawValue)?.rawValue == expected)
    }

    @Test(arguments: [
        // Wrong check digit.
        "0306406153",
        "9780306406158",
        "0804429570",
        // Wrong length.
        "",
        "-",
        "030640615",
        "03064061522",
        "978030640615",
        "97803064061577",
        // `X` elsewhere than at the end of an ISBN-10, with a valid sum.
        "03064X6157",
        "978030640614X",
        // Other characters.
        "03064O6152",
        "B00JCDK5ME",
        "urn:isbn:9780306406157",
        // Arabic-Indic digits.
        "٩٧٨٠٣٠٦٤٠٦١٥٧",
    ])
    func rejects(rawValue: String) {
        #expect(ISBN(rawValue: rawValue) == nil)
    }

    @Test func urn() {
        #expect(ISBN(rawValue: "9780306406157")?.urn == "urn:isbn:9780306406157")
    }

    @Test func comparesTheNormalizedForm() {
        #expect(ISBN(rawValue: "978-0-306-40615-7") == ISBN(rawValue: "9780306406157"))
        #expect(ISBN(rawValue: "0306406152") != ISBN(rawValue: "9780306406157"))
    }
}
