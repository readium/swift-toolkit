//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

private func position(_ time: TimeInterval) -> TemporalSelector {
    .position(TemporalPosition(time: time)!)
}

private func clip(_ start: TimeInterval, _ end: TimeInterval) -> TemporalSelector {
    .clip(TemporalClip(start: start, end: end)!)
}

private func selector(_ fragment: String) -> TemporalSelector? {
    URLFragment(rawValue: fragment).flatMap(TemporalSelector.init(fragment:))
}

enum TemporalSelectorTests {
    struct Validity {
        @Test("a position accepts a finite time which is not negative")
        func validPosition() {
            #expect(TemporalPosition(time: 0)?.time == 0)
            #expect(TemporalPosition(time: 71.5)?.time == 71.5)
        }

        @Test("a position rejects a negative or non finite time", arguments: [
            -1, -0.001, -.leastNonzeroMagnitude, .infinity, -.infinity, .nan,
        ] as [TimeInterval])
        func invalidPosition(time: TimeInterval) {
            #expect(TemporalPosition(time: time) == nil)
        }

        @Test("a negative zero is normalized to 0")
        func negativeZero() throws {
            let position = try #require(TemporalPosition(time: -0.0))
            #expect(position.time.sign == .plus)
            #expect(TemporalSelector.position(position).fragment == "t=0")

            let clip = try #require(TemporalClip(start: -0.0, end: 20))
            #expect(clip.start.sign == .plus)
        }

        @Test("a clip starts at 0 by default")
        func clipDefaultStart() {
            #expect(TemporalClip(end: 20) == TemporalClip(start: 0, end: 20))
            #expect(TemporalClip(end: 20)?.start == 0)
        }

        @Test("a clip rejects invalid times or a start not before its end", arguments: [
            (20, 10),
            (10, 10),
            (0, 0),
            (-1, 10),
            (0, -1),
            (.nan, 10),
            (0, .nan),
            (0, .infinity),
            (5, .infinity),
            (.infinity, .infinity),
            (-.infinity, 10),
        ] as [(TimeInterval, TimeInterval)])
        func invalidClip(start: TimeInterval, end: TimeInterval) {
            #expect(TemporalClip(start: start, end: end) == nil)
        }
    }

    struct Start {
        @Test("start is the time of a position")
        func position() {
            #expect(ReadiumSharedTests.position(71.5).start == 71.5)
        }

        @Test("start is the start of a clip")
        func clip() {
            #expect(ReadiumSharedTests.clip(10, 20).start == 10)
        }

        @Test("isAtStart is true only for a position at 0")
        func isAtStart() {
            #expect(ReadiumSharedTests.position(0).isAtStart)
            #expect(!ReadiumSharedTests.position(0.001).isAtStart)
            #expect(!ReadiumSharedTests.clip(0, 20).isAtStart)
            #expect(!ReadiumSharedTests.clip(10, 20).isAtStart)
        }
    }

    struct Parsing {
        @Test("accepted fragments", arguments: [
            // Seconds
            ("t=0", position(0)),
            ("t=71", position(71)),
            ("t=71.5", position(71.5)),
            ("t=10.0", position(10)),
            ("t=10.", position(10)),
            ("t=0.001", position(0.001)),
            ("t=007", position(7)),
            // `npt:` prefix
            ("t=npt:10", position(10)),
            ("t=npt:10,20", clip(10, 20)),
            ("t=npt:0:01:30.5", position(90.5)),
            ("t=npt:,20", clip(0, 20)),
            // Clock forms
            ("t=01:30", position(90)),
            ("t=01:30.5", position(90.5)),
            ("t=59:59", position(3599)),
            ("t=1:30:00", position(5400)),
            ("t=0:02:00", position(120)),
            ("t=0:01:30.5", position(90.5)),
            ("t=100:00:00", position(360_000)),
            ("t=00:00", position(0)),
            ("t=00:00:00", position(0)),
            ("t=01:30.", position(90)),
            // A clock form is the same time as its seconds form.
            ("t=01:01.029", position(61.029)),
            ("t=01:01.096", position(61.096)),
            ("t=1:01:01.154", position(3661.154)),
            // Clips
            ("t=10,20", clip(10, 20)),
            ("t=10.0,20.0", clip(10, 20)),
            ("t=,20", clip(0, 20)),
            ("t=0,20", clip(0, 20)),
            ("t=01:00,01:30", clip(60, 90)),
            ("t=10,0:01:00", clip(10, 60)),
            ("t=10.,20", clip(10, 20)),
            // Several dimensions
            ("t=10&track=audio", position(10)),
            ("track=audio&t=10", position(10)),
            ("xywh=0,0,10,10&t=10,20&track=audio", clip(10, 20)),
            ("t=5&t=10", position(10)),
            ("t=10&t=invalid", position(10)),
            ("t=10&t=", position(10)),
            ("t=10&&", position(10)),
            // A clip which is not valid is skipped like any invalid dimension.
            ("t=1,2&t=5,3", clip(1, 2)),
            ("t=10&t=20,10", position(10)),
        ] as [(String, TemporalSelector)])
        func accepted(fragment: String, expected: TemporalSelector) {
            #expect(selector(fragment) == expected)
        }

        @Test("rejected fragments", arguments: [
            // Not a temporal dimension
            "10,20",
            "start=10",
            "T=10",
            "at=10",
            "t",
            "t=",
            "t=npt:",
            "page=2",
            // Other time formats
            "t=smpte:0:02:00",
            "t=smpte-25:0:02:00:00",
            "t=clock:2011-01-01T00:00:00Z",
            "t=NPT:10",
            "t=npt:npt:10",
            "t=10,npt:20",
            // Percent-encoded
            "t=%31%30",
            "t=10%2C20",
            // Seconds
            "t=-5",
            "t=+5",
            "t=1e3",
            "t=inf",
            "t=nan",
            "t=0x10",
            "t=.5",
            "t=1.2.3",
            "t=1.-5",
            "t= 10",
            "t=10s",
            "t=١٠",
            "t=" + String(repeating: "9", count: 400),
            // Clock forms
            "t=1:30",
            "t=01:60",
            "t=60:00",
            "t=001:30",
            "t=1:30:60",
            "t=1:60:00",
            "t=1:3:00",
            "t=:30",
            "t=01:",
            "t=:01:30",
            "t=1:00:00:00",
            "t=0:0:0",
            "t=" + String(repeating: "9", count: 400) + ":00:00",
            "t=1:00,1:30",
            // Clips
            "t=10,",
            "t=10.0,",
            "t=,",
            "t=20,10",
            "t=10,10",
            "t=,0",
            "t=0.0,0.0",
            "t=10,20,30",
            "t=10,abc",
            "t=abc,20",
        ])
        func rejected(fragment: String) {
            #expect(selector(fragment) == nil)
        }

        @Test("temporalSelector parses the fragment")
        func temporalSelector() {
            #expect(URLFragment(rawValue: "t=10")?.temporalSelector == position(10))
            #expect(URLFragment(rawValue: "page=2")?.temporalSelector == nil)
        }
    }

    struct Writing {
        @Test("written forms", arguments: [
            (position(0), "t=0"),
            (position(10), "t=10"),
            (position(71), "t=71"),
            (position(71.5), "t=71.5"),
            (position(0.001), "t=0.001"),
            (position(0.1 + 0.2), "t=0.30000000000000004"),
            (position(3600), "t=3600"),
            (position(123_456_789), "t=123456789"),
            // Values for which the description of a `Double` uses an exponent.
            (position(0.0001), "t=0.0001"),
            (position(0.00001), "t=0.00001"),
            (position(0.000012345), "t=0.000012345"),
            (position(1e15), "t=1000000000000000"),
            (position(1e16), "t=10000000000000000"),
            (position(1.5e16), "t=15000000000000000"),
            (position(1.2345678901234568e17), "t=123456789012345680"),
            (clip(10, 20), "t=10,20"),
            (clip(0, 20), "t=0,20"),
            (clip(0, 5.123), "t=0,5.123"),
            (clip(1.5, 1e16), "t=1.5,10000000000000000"),
        ] as [(TemporalSelector, String)])
        func written(selector: TemporalSelector, expected: String) {
            #expect(selector.fragment.rawValue == expected)
        }

        @Test("a written fragment parses back to the same selector", arguments: [
            position(0),
            position(10),
            position(71.5),
            position(0.1 + 0.2),
            position(1.0 / 3.0),
            position(98.76543210987654),
            position(4321.000000001),
            position(0.00001),
            position(1e-9),
            position(9.999e-5),
            position(1e-4),
            position(9_007_199_254_740_992),
            position(1e22),
            position(1e23),
            position(.leastNonzeroMagnitude),
            position(.leastNormalMagnitude),
            position(1e16),
            position(1.2345678901234568e17),
            position(.greatestFiniteMagnitude),
            clip(10, 20),
            clip(0, 20),
            clip(1.0 / 3.0, 2.0 / 3.0),
            clip(0.00001, 1e16),
            clip(0.1, 0.1.nextUp),
        ])
        func roundTrip(selector: TemporalSelector) {
            #expect(TemporalSelector(fragment: selector.fragment) == selector)
        }

        @Test("a written fragment only contains plain decimal numbers", arguments: [
            position(.leastNonzeroMagnitude),
            position(.greatestFiniteMagnitude),
            position(1.0 / 3.0),
            clip(1e-9, 1e21),
        ])
        func plainDigits(selector: TemporalSelector) {
            #expect(selector.fragment.rawValue.hasPrefix("t="))
            let times = selector.fragment.rawValue.dropFirst(2)
                .split(separator: ",", omittingEmptySubsequences: false)
            #expect(times.count <= 2)
            for time in times {
                let parts = time.split(separator: ".", omittingEmptySubsequences: false)
                #expect(parts.count <= 2)
                #expect(parts.allSatisfy { !$0.isEmpty && $0.allSatisfy { "0123456789".contains($0) } })
            }
        }
    }
}
