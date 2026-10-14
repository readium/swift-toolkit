//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

enum URLFragmentTests {
    struct RawValue {
        @Test("a valid percent-encoded fragment is kept as is", arguments: [
            "section",
            "page=2",
            "t=10,20&track=audio",
            "quz%20baz",
            "caf%C3%A9",
            "caf%c3%a9",
            "id=a%26t%3D5",
            ":~:text=start,end",
            "!$&'()*+,;=:@/?-._~",
            // Not UTF-8 once decoded.
            "%FF",
            "%C3&%A9",
        ])
        func valid(rawValue: String) {
            #expect(URLFragment(rawValue: rawValue)?.rawValue == rawValue)
        }

        @Test("an empty or invalid percent-encoded fragment is rejected", arguments: [
            "",
            // Characters which must be percent-encoded.
            "quz baz",
            "café",
            "a#b",
            "a[1]",
            "a\"b",
            "a<b>",
            "a\\b",
            "a^b",
            "a`b",
            "a{b}",
            "a|b",
            "a\nb",
            // Malformed percent-encoding.
            "%",
            "a%2",
            "a%zz",
            "100%",
        ])
        func invalid(rawValue: String) {
            #expect(URLFragment(rawValue: rawValue) == nil)
        }

        @Test("a string literal is a percent-encoded fragment")
        func stringLiteral() {
            let fragment: URLFragment = "quz%20baz"
            #expect(fragment == URLFragment(rawValue: "quz%20baz"))
        }
    }

    struct PercentDecoded {
        @Test("percentDecoded removes the percent-encoding", arguments: [
            ("section", "section"),
            ("quz%20baz", "quz baz"),
            ("caf%C3%A9", "café"),
            ("caf%c3%a9", "café"),
            ("100%25", "100%"),
            ("a+b", "a+b"),
            ("id=a%26t%3D5", "id=a&t=5"),
        ])
        func percentDecoded(rawValue: String, expected: String) {
            #expect(URLFragment(rawValue: rawValue)?.percentDecoded == expected)
        }

        @Test("percentDecoded is nil when the bytes are not valid UTF-8", arguments: [
            "%FF",
            "caf%E9",
            "%C3&%A9",
            "t=10&id=%FF",
        ])
        func notUTF8(rawValue: String) throws {
            let fragment = try #require(URLFragment(rawValue: rawValue))
            #expect(fragment.percentDecoded == nil)
        }

        @Test("init(percentDecoded:) percent-encodes the string", arguments: [
            ("section", "section"),
            ("quz baz", "quz%20baz"),
            ("café", "caf%C3%A9"),
            ("100%", "100%25"),
            ("quz%20baz", "quz%2520baz"),
            ("a#b[1]", "a%23b%5B1%5D"),
            // The delimiters allowed in a fragment are kept.
            ("t=10,20&track=audio", "t=10,20&track=audio"),
            ("!$&'()*+,;=:@/?-._~", "!$&'()*+,;=:@/?-._~"),
        ])
        func initPercentDecoded(percentDecoded: String, expected: String) {
            #expect(URLFragment(percentDecoded: percentDecoded)?.rawValue == expected)
        }

        @Test("init(percentDecoded:) rejects an empty string")
        func initPercentDecodedEmpty() {
            #expect(URLFragment(percentDecoded: "") == nil)
        }

        @Test("a percent-decoded string round-trips", arguments: [
            "section",
            "quz baz",
            "café ☕️",
            "100% #1 [a|b] {c} <d> \"e\" \\ ^ `",
            "%20",
            "a&b=c",
            "line\nbreak\ttab",
        ])
        func roundTrip(percentDecoded: String) {
            #expect(URLFragment(percentDecoded: percentDecoded)?.percentDecoded == percentDecoded)
        }
    }

    struct Parameters {
        typealias Parameter = URLFragment.Parameter

        @Test("parameters are the name-value pairs in order")
        func parameters() {
            let fragment: URLFragment = "t=10,20&track=audio&t=30"
            #expect(fragment.parameters == [
                Parameter(name: "t", value: "10,20"),
                Parameter(name: "track", value: "audio"),
                Parameter(name: "t", value: "30"),
            ])
        }

        @Test("names and values are percent-decoded after splitting")
        func decodedAfterSplitting() {
            let fragment: URLFragment = "id=a%26t%3D5&%74=10&track=caf%C3%A9%20noir"
            #expect(fragment.parameters == [
                Parameter(name: "id", value: "a&t=5"),
                Parameter(name: "t", value: "10"),
                Parameter(name: "track", value: "café noir"),
            ])
        }

        @Test("a pair is split on its first equals sign")
        func firstEqualsSign() {
            let fragment: URLFragment = "a=b=c&d=="
            #expect(fragment.parameters == [
                Parameter(name: "a", value: "b=c"),
                Parameter(name: "d", value: "="),
            ])
        }

        @Test("a plus sign is not decoded as a space")
        func plusSign() {
            let fragment: URLFragment = "track=a+b"
            #expect(fragment.parameters == [Parameter(name: "track", value: "a+b")])
        }

        @Test("an empty name or value is kept")
        func emptyNameOrValue() {
            let fragment: URLFragment = "t=&=10"
            #expect(fragment.parameters == [
                Parameter(name: "t", value: ""),
                Parameter(name: "", value: "10"),
            ])
        }

        @Test("a component without an equals sign is ignored", arguments: [
            "section",
            "t",
            "t%3D10",
            ":~:text",
            "&&",
        ])
        func withoutEqualsSign(rawValue: String) {
            #expect(URLFragment(rawValue: rawValue)?.parameters == [])
        }

        @Test("a pair whose name or value is not valid UTF-8 is ignored")
        func notUTF8() {
            let fragment: URLFragment = "id=%FF&t=10&%FF=1&track=caf%E9&%C3=%A9"
            #expect(fragment.parameters == [Parameter(name: "t", value: "10")])
        }

        @Test("empty components are ignored")
        func emptyComponents() {
            let fragment: URLFragment = "&t=10&&track=audio&"
            #expect(fragment.parameters == [
                Parameter(name: "t", value: "10"),
                Parameter(name: "track", value: "audio"),
            ])
        }

        @Test("parameters(named:) returns the values of the matching parameters in order")
        func parametersNamed() {
            let fragment: URLFragment = "t=5&track=audio&t=10&%74=15&T=20"
            #expect(fragment.parameters(named: "t") == ["5", "10", "15"])
            #expect(fragment.parameters(named: "track") == ["audio"])
            #expect(fragment.parameters(named: "id") == [])
        }

        @Test("init(parameters:) joins the pairs in order")
        func initParameters() {
            let fragment = URLFragment(parameters: [
                Parameter(name: "t", value: "10,20"),
                Parameter(name: "track", value: "audio"),
                Parameter(name: "t", value: "30"),
            ])
            #expect(fragment?.rawValue == "t=10,20&track=audio&t=30")
        }

        @Test("init(parameters:) percent-encodes the names and values", arguments: [
            (Parameter(name: "track", value: "a&b"), "track=a%26b"),
            (Parameter(name: "track", value: "a=b"), "track=a%3Db"),
            (Parameter(name: "a&b=c", value: "1"), "a%26b%3Dc=1"),
            (Parameter(name: "id", value: "100%"), "id=100%25"),
            (Parameter(name: "id", value: "%20"), "id=%2520"),
            (Parameter(name: "id", value: "a#b"), "id=a%23b"),
            (Parameter(name: "track", value: "café noir"), "track=caf%C3%A9%20noir"),
            (Parameter(name: "café", value: "1"), "caf%C3%A9=1"),
            // A plus sign is kept, because it is not read as a space.
            (Parameter(name: "track", value: "a+b"), "track=a+b"),
            // An empty name or value is kept.
            (Parameter(name: "t", value: ""), "t="),
            (Parameter(name: "", value: "10"), "=10"),
        ])
        func initParametersPercentEncodes(parameter: Parameter, expected: String) {
            #expect(URLFragment(parameters: [parameter])?.rawValue == expected)
        }

        @Test("init(parameters:) rejects an empty list")
        func initParametersEmpty() {
            #expect(URLFragment(parameters: []) == nil)
        }

        @Test("parameters round-trip", arguments: [
            [
                Parameter(name: "id", value: "a&t=5"),
                Parameter(name: "a=b&c", value: "café ☕️"),
            ],
            [
                Parameter(name: "id", value: "100% #1 [a|b] {c} <d> \"e\" \\ ^ `"),
                Parameter(name: "%20", value: "%26"),
                Parameter(name: "track", value: "a+b"),
            ],
        ])
        func roundTrip(parameters: [Parameter]) {
            #expect(URLFragment(parameters: parameters)?.parameters == parameters)
        }
    }
}
