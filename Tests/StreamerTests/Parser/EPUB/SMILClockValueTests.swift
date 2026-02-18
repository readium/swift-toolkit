//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumStreamer
import Testing

/// https://www.w3.org/TR/SMIL/smil-timing.html#Timing-ClockValueSyntax
@Suite enum SMILClockValueTests {
    @Suite("full clock: hh:mm:ss[.fraction]") struct FullClock {
        @Test func basic() {
            #expect(parseSmilClockValue("1:32:29") == 5549.0)
        }

        @Test func zero() {
            #expect(parseSmilClockValue("0:00:00") == 0.0)
        }

        @Test func fractionalSeconds() {
            #expect(parseSmilClockValue("0:01:30.5") == 90.5)
        }

        @Test func largeHours() {
            #expect(parseSmilClockValue("100:00:00") == 360_000.0)
        }
    }

    @Suite("partial clock: mm:ss[.fraction]") struct PartialClock {
        @Test func basic() {
            #expect(parseSmilClockValue("23:45") == 1425.0)
        }

        @Test func zero() {
            #expect(parseSmilClockValue("0:00") == 0.0)
        }

        @Test func singleDigitMinutes() {
            #expect(parseSmilClockValue("8:44") == 524.0)
        }

        @Test func fractionalSeconds() {
            #expect(parseSmilClockValue("0:30.5") == 30.5)
        }
    }

    @Suite("timecount values") struct Timecount {
        @Test func hours() {
            #expect(parseSmilClockValue("2h") == 7200.0)
        }

        @Test func fractionalHours() {
            #expect(parseSmilClockValue("1.5h") == 5400.0)
        }

        @Test func minutes() {
            #expect(parseSmilClockValue("30min") == 1800.0)
        }

        @Test func fractionalMinutes() {
            #expect(parseSmilClockValue("0.5min") == 30.0)
        }

        @Test func seconds() {
            #expect(parseSmilClockValue("45s") == 45.0)
        }

        @Test func fractionalSeconds() {
            #expect(parseSmilClockValue("2.5s") == 2.5)
        }

        @Test func milliseconds() {
            #expect(parseSmilClockValue("500ms") == 0.5)
        }

        @Test("milliseconds suffix takes priority over seconds suffix")
        func millisecondsPriority() {
            #expect(parseSmilClockValue("1000ms") == 1.0)
        }

        @Test func plainNumber() {
            #expect(parseSmilClockValue("120") == 120.0)
        }

        @Test func plainFractionalNumber() {
            #expect(parseSmilClockValue("1.5") == 1.5)
        }
    }

    @Suite("whitespace handling") struct Whitespace {
        @Test func leadingAndTrailingSpaces() {
            #expect(parseSmilClockValue("  30s  ") == 30.0)
        }

        @Test func leadingAndTrailingSpacesOnClock() {
            #expect(parseSmilClockValue(" 1:30 ") == 90.0)
        }
    }

    @Suite("invalid input returns nil") struct Invalid {
        @Test func empty() {
            #expect(parseSmilClockValue("") == nil)
        }

        @Test func whitespaceOnly() {
            #expect(parseSmilClockValue("   ") == nil)
        }

        @Test func letters() {
            #expect(parseSmilClockValue("abc") == nil)
        }

        @Test func unknownSuffix() {
            #expect(parseSmilClockValue("1m") == nil)
        }

        @Test func nonNumericHours() {
            #expect(parseSmilClockValue("x:00:00") == nil)
        }

        @Test func nonNumericMinutes() {
            #expect(parseSmilClockValue("1:xx:00") == nil)
        }

        @Test func nonNumericSeconds() {
            #expect(parseSmilClockValue("1:00:xx") == nil)
        }
    }
}
