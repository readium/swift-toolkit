//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumInternal
import Testing

@Suite struct RangeTests {
    @Suite struct HTTPByteRangeParsing {
        let totalLength: UInt64 = 10000

        // MARK: - Closed range: bytes=N-M

        @Test func closedRange() {
            #expect(Range(httpRange: "bytes=0-1023", in: totalLength) == 0 ..< 1024)
        }

        @Test func closedRangeStartingAtNonZero() {
            #expect(Range(httpRange: "bytes=500-999", in: totalLength) == 500 ..< 1000)
        }

        @Test func closedRangeSingleByte() {
            #expect(Range(httpRange: "bytes=0-0", in: totalLength) == 0 ..< 1)
        }

        @Test func closedRangeClampedToTotalLength() {
            #expect(Range(httpRange: "bytes=9000-20000", in: totalLength) == 9000 ..< 10000)
        }

        @Test func closedRangeEndEqualsTotalLength() {
            #expect(Range(httpRange: "bytes=9000-9999", in: totalLength) == 9000 ..< 10000)
        }

        @Test func closedRangeReversedIsNil() {
            #expect(Range(httpRange: "bytes=500-100", in: totalLength) == nil)
        }

        @Test func closedRangeStartBeyondTotalLengthIsNil() {
            #expect(Range(httpRange: "bytes=10000-10001", in: totalLength) == nil)
        }

        // MARK: - Open-ended range: bytes=N-

        @Test func openEndedRange() {
            #expect(Range(httpRange: "bytes=1024-", in: totalLength) == 1024 ..< 10000)
        }

        @Test func openEndedRangeFromStart() {
            #expect(Range(httpRange: "bytes=0-", in: totalLength) == 0 ..< 10000)
        }

        @Test func openEndedRangeAtLastByte() {
            #expect(Range(httpRange: "bytes=9999-", in: totalLength) == 9999 ..< 10000)
        }

        @Test func openEndedRangeAtTotalLengthIsNil() {
            #expect(Range(httpRange: "bytes=10000-", in: totalLength) == nil)
        }

        @Test func openEndedRangeBeyondTotalLengthIsNil() {
            #expect(Range(httpRange: "bytes=20000-", in: totalLength) == nil)
        }

        // MARK: - Suffix range: bytes=-N

        @Test func suffixRange() {
            #expect(Range(httpRange: "bytes=-512", in: totalLength) == 9488 ..< 10000)
        }

        @Test func suffixRangeLargerThanTotalLength() {
            #expect(Range(httpRange: "bytes=-20000", in: totalLength) == 0 ..< 10000)
        }

        @Test func suffixRangeEqualToTotalLength() {
            #expect(Range(httpRange: "bytes=-10000", in: totalLength) == 0 ..< 10000)
        }

        @Test func suffixRangeZeroIsNil() {
            #expect(Range(httpRange: "bytes=-0", in: totalLength) == nil)
        }

        // MARK: - Malformed / absent

        @Test func emptyStringIsNil() {
            #expect(Range(httpRange: "", in: totalLength) == nil)
        }

        @Test func missingPrefixIsNil() {
            #expect(Range(httpRange: "0-1023", in: totalLength) == nil)
        }

        @Test func wrongPrefixIsNil() {
            #expect(Range(httpRange: "chars=0-1023", in: totalLength) == nil)
        }

        @Test func nonNumericStartIsNil() {
            #expect(Range(httpRange: "bytes=abc-1023", in: totalLength) == nil)
        }

        @Test func nonNumericEndIsNil() {
            #expect(Range(httpRange: "bytes=0-abc", in: totalLength) == nil)
        }

        @Test func missingDashIsNil() {
            #expect(Range(httpRange: "bytes=1024", in: totalLength) == nil)
        }

        // MARK: - Zero total length

        @Test func zeroTotalLengthClosedRangeIsNil() {
            #expect(Range(httpRange: "bytes=0-0", in: 0) == nil)
        }

        @Test func zeroTotalLengthOpenEndedIsNil() {
            #expect(Range(httpRange: "bytes=0-", in: 0) == nil)
        }

        @Test func zeroTotalLengthSuffixIsNil() {
            #expect(Range(httpRange: "bytes=-0", in: 0) == nil)
        }
    }
}
