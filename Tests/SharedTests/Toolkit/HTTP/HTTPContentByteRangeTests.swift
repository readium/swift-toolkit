//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

struct HTTPContentByteRangeTests {
    @Test func normalRange() {
        #expect(HTTPContentByteRange(header: "bytes 0-100/1000") == HTTPContentByteRange(range: 0 ... 100, size: 1000))
    }

    @Test func unknownSize() {
        #expect(HTTPContentByteRange(header: "bytes 0-100/*") == HTTPContentByteRange(range: 0 ... 100, size: nil))
    }

    @Test func unknownRange() {
        #expect(HTTPContentByteRange(header: "bytes */1000") == HTTPContentByteRange(range: nil, size: 1000))
    }

    @Test func zeroSize() {
        #expect(HTTPContentByteRange(header: "bytes */0") == HTTPContentByteRange(range: nil, size: 0))
    }

    @Test func rejectsNegativeSize() {
        #expect(HTTPContentByteRange(header: "bytes 0-100/-5") == nil)
    }

    @Test func rejectsNonBytesUnit() {
        #expect(HTTPContentByteRange(header: "tokens 0-100/1000") == nil)
    }

    @Test func rejectsInvertedRange() {
        #expect(HTTPContentByteRange(header: "bytes 100-0/1000") == nil)
    }

    @Test func toleratesExtraWhitespace() {
        #expect(HTTPContentByteRange(header: "bytes  5 - 50 / 200 ") == HTTPContentByteRange(range: 5 ... 50, size: 200))
    }
}
