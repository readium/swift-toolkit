//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

struct TransformingResourceTests {
    @Test func sourceURLIsNil() {
        let resource = DataResource(string: "hello")
        let sut = TransformingResource(resource) { $0 }
        #expect(sut.sourceURL == nil)
    }

    @Test func estimatedLengthIsNil() async throws {
        let resource = DataResource(string: "hello")
        let sut = TransformingResource(resource) { $0 }
        let result = try await sut.estimatedLength().get()
        #expect(result == nil)
    }

    @Test func propertiesForwardedFromResource() async throws {
        let expected = ResourceProperties {
            $0.filename = "chapter.html"
        }
        let resource = FakeResource(properties: .success(expected))
        let sut = TransformingResource(resource) { $0 }
        let actual = try await sut.properties().get()
        #expect(actual == expected)
    }

    @Test func transformApplied() async throws {
        let resource = DataResource(string: "hello")
        let sut = TransformingResource(resource) { data in
            data.map {
                String(data: $0, encoding: .utf8)!
                    .uppercased()
                    .data(using: .utf8)!
            }
        }
        let data = try await sut.read().get()
        #expect(data == "HELLO".data(using: .utf8)!)
    }

    @Test func rangeRead() async throws {
        let resource = DataResource(data: Data([0, 1, 2, 3, 4, 5, 6, 7]))
        let sut = TransformingResource(resource) { $0 }
        let data = try await sut.read(range: 2 ..< 5).get()
        #expect(data == Data([2, 3, 4]))
    }

    struct Map {
        @Test func mapTransformsData() async throws {
            let resource = DataResource(data: Data([1, 2, 3]))
            let sut = resource.map { data in
                Data(data.map { $0 + 10 })
            }
            let data = try await sut.read().get()
            #expect(data == Data([11, 12, 13]))
        }

        @Test func mapAsStringTransformsText() async throws {
            let resource = DataResource(string: "hello")
            let sut = resource.mapAsString { $0.uppercased() }
            let data = try await sut.read().get()
            #expect(data == "HELLO".data(using: .utf8)!)
        }
    }

    /// This suite reproduces the crash reported in the wild where multiple
    /// concurrent callers to `TransformingResource.data()` cause a data race:
    /// `_data` is written by multiple tasks simultaneously.
    ///
    /// Run with Thread Sanitizer enabled to reliably detect the race. Without
    /// TSan, the `transformCalledOnce` test will still fail most of the time
    /// because `callCount > 1`.
    struct ConcurrentAccess {
        /// Verifies that the `transform` closure is called exactly once, even
        /// when multiple concurrent tasks all call `read()` at the same time.
        @Test func transformCalledOnce() async {
            let counter = Counter()
            let resource = DataResource(string: "hello")
            let sut = TransformingResource(resource) { data in
                // Sleep to widen the race window so concurrent callers all
                // enter this branch before any of them finishes writing to `_data`.
                try? await Task.sleep(seconds: 0.5)
                await counter.increment()
                return data
            }

            await withTaskGroup(of: Void.self) { group in
                for _ in 0 ..< 50 {
                    group.addTask { _ = await sut.read() }
                }
            }

            let count = await counter.count
            #expect(count == 1, "transform() should be called exactly once, but was called \(count) times")
        }

        /// Verifies that every concurrent caller receives the same correct
        /// data.
        @Test func concurrentReadsReturnSameData() async throws {
            let expected = "hello".data(using: .utf8)!
            let resource = DataResource(string: "hello")
            let sut = TransformingResource(resource) { data in
                try? await Task.sleep(seconds: 0.5)
                return data
            }

            var results: [ReadResult<Data>] = []
            await withTaskGroup(of: ReadResult<Data>.self) { group in
                for _ in 0 ..< 50 {
                    group.addTask { await sut.read() }
                }
                for await result in group {
                    results.append(result)
                }
            }

            #expect(results.count == 50)
            for result in results {
                let data = try result.get()
                #expect(data == expected)
            }
        }

        private actor Counter {
            private(set) var count = 0

            func increment() {
                count += 1
            }
        }
    }
}
