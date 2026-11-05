//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

struct AsyncThrowingMemoizerTests {
    @Test func cachesTheFirstSuccess() async throws {
        let calls = CallCounter()
        let memoizer = AsyncThrowingMemoizer { () async throws(ReadError) -> Int in
            await calls.increment()
        }

        #expect(try await memoizer() == 1)
        #expect(try await memoizer() == 1)
        #expect(await calls.count == 1)
    }

    @Test func computesAgainAfterAFailure() async throws {
        let calls = CallCounter()
        let memoizer = AsyncThrowingMemoizer { () async throws(ReadError) -> Int in
            let call = await calls.increment()
            guard call > 1 else {
                throw .decoding("Broken")
            }
            return call
        }

        await #expect(throws: ReadError.self) {
            try await memoizer()
        }
        #expect(try await memoizer() == 2)
        #expect(try await memoizer() == 2)
        #expect(await calls.count == 2)
    }
}

// MARK: - Helpers

/// Counts the computations, returning the number of each one.
private actor CallCounter {
    private(set) var count = 0

    func increment() -> Int {
        count += 1
        return count
    }
}
