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
            #expect(SMILParser.parseClockValue("1:32:29") == 5549.0)
        }

        @Test func zero() {
            #expect(SMILParser.parseClockValue("0:00:00") == 0.0)
        }

        @Test func fractionalSeconds() {
            #expect(SMILParser.parseClockValue("0:01:30.5") == 90.5)
        }

        @Test func largeHours() {
            #expect(SMILParser.parseClockValue("100:00:00") == 360_000.0)
        }
    }

    @Suite("partial clock: mm:ss[.fraction]") struct PartialClock {
        @Test func basic() {
            #expect(SMILParser.parseClockValue("23:45") == 1425.0)
        }

        @Test func zero() {
            #expect(SMILParser.parseClockValue("0:00") == 0.0)
        }

        @Test func singleDigitMinutes() {
            #expect(SMILParser.parseClockValue("8:44") == 524.0)
        }

        @Test func fractionalSeconds() {
            #expect(SMILParser.parseClockValue("0:30.5") == 30.5)
        }
    }

    @Suite("timecount values") struct Timecount {
        @Test func hours() {
            #expect(SMILParser.parseClockValue("2h") == 7200.0)
        }

        @Test func fractionalHours() {
            #expect(SMILParser.parseClockValue("1.5h") == 5400.0)
        }

        @Test func minutes() {
            #expect(SMILParser.parseClockValue("30min") == 1800.0)
        }

        @Test func fractionalMinutes() {
            #expect(SMILParser.parseClockValue("0.5min") == 30.0)
        }

        @Test func seconds() {
            #expect(SMILParser.parseClockValue("45s") == 45.0)
        }

        @Test func fractionalSeconds() {
            #expect(SMILParser.parseClockValue("2.5s") == 2.5)
        }

        @Test func milliseconds() {
            #expect(SMILParser.parseClockValue("500ms") == 0.5)
        }

        @Test("milliseconds suffix takes priority over seconds suffix")
        func millisecondsPriority() {
            #expect(SMILParser.parseClockValue("1000ms") == 1.0)
        }

        @Test func plainNumber() {
            #expect(SMILParser.parseClockValue("120") == 120.0)
        }

        @Test func plainFractionalNumber() {
            #expect(SMILParser.parseClockValue("1.5") == 1.5)
        }
    }

    @Suite("whitespace handling") struct Whitespace {
        @Test func leadingAndTrailingSpaces() {
            #expect(SMILParser.parseClockValue("  30s  ") == 30.0)
        }

        @Test func leadingAndTrailingSpacesOnClock() {
            #expect(SMILParser.parseClockValue(" 1:30 ") == 90.0)
        }
    }

    @Suite("invalid input returns nil") struct Invalid {
        @Test func empty() {
            #expect(SMILParser.parseClockValue("") == nil)
        }

        @Test func whitespaceOnly() {
            #expect(SMILParser.parseClockValue("   ") == nil)
        }

        @Test func letters() {
            #expect(SMILParser.parseClockValue("abc") == nil)
        }

        @Test func unknownSuffix() {
            #expect(SMILParser.parseClockValue("1m") == nil)
        }

        @Test func nonNumericHours() {
            #expect(SMILParser.parseClockValue("x:00:00") == nil)
        }

        @Test func nonNumericMinutes() {
            #expect(SMILParser.parseClockValue("1:xx:00") == nil)
        }

        @Test func nonNumericSeconds() {
            #expect(SMILParser.parseClockValue("1:00:xx") == nil)
        }
    }
}
