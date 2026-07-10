//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class ReadErrorTests: XCTestCase {
    /// A `ReadError` is passed through as-is, instead of being wrapped in
    /// another `ReadError` losing its semantics.
    func testWrapPassesThroughReadError() {
        let error: Error = ReadError.access(.http(.cancelled))
        XCTAssertEqual(ReadError.wrap(error), .access(.http(.cancelled)))
    }

    func testWrapCancellationError() {
        XCTAssertEqual(ReadError.wrap(CancellationError()), .cancelled)
    }

    func testIsCancellation() {
        XCTAssertTrue(ReadError.cancelled.isCancellation)
        XCTAssertTrue(ReadError.access(.http(.cancelled)).isCancellation)
        XCTAssertTrue(ReadError.decoding(ReadError.cancelled).isCancellation)
        XCTAssertTrue(ReadError.decoding(ReadError.access(.http(.cancelled))).isCancellation)
        XCTAssertTrue(ReadError.decoding(CancellationError()).isCancellation)

        XCTAssertFalse(ReadError.decoding("Invalid data").isCancellation)
        XCTAssertFalse(ReadError.access(.http(.rangeNotSupported)).isCancellation)
        XCTAssertFalse(ReadError.access(.fileSystem(.fileNotFound(nil))).isCancellation)
    }
}
