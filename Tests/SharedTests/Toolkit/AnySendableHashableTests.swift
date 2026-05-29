//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

@Suite("AnySendableHashable")
struct AnySendableHashableTests {
    @Test("Equality")
    func equality() {
        #expect(AnySendableHashable(1) == AnySendableHashable(1))
        #expect(AnySendableHashable(1) != AnySendableHashable(2))
        #expect(AnySendableHashable(1) != AnySendableHashable("1"))
    }

    @Test("Hashing")
    func hashing() {
        #expect(AnySendableHashable(1).hashValue == AnySendableHashable(1).hashValue)
    }

    @Test("Unwrapping")
    func unwrapping() {
        let h = AnySendableHashable(42)
        #expect(h.unwrap(as: Int.self) == 42)
        #expect(h.unwrap(as: String.self) == nil)

        let s = AnySendableHashable("hello")
        #expect(s.unwrap(as: String.self) == "hello")
        #expect(s.unwrap(as: Int.self) == nil)
    }

    @Test("Nested wrapping is flattened")
    func nestedWrapping() {
        let h1 = AnySendableHashable(1)
        let h2 = AnySendableHashable(h1)
        let h3 = AnySendableHashable(h2)

        #expect(h1 == h2)
        #expect(h1 == h3)
        #expect(h2 == h3)

        #expect(h3.unwrap(as: Int.self) == 1)
        #expect(!(h3.base is AnySendableHashable))
    }

    @Test("As dictionary key")
    func asDictionaryKey() {
        let dict: [AnySendableHashable: String] = [
            AnySendableHashable(1): "one",
            AnySendableHashable("1"): "string one",
        ]

        #expect(dict[AnySendableHashable(1)] == "one")
        #expect(dict[AnySendableHashable("1")] == "string one")
    }

    struct ComplexType: Hashable, Sendable {
        let id: Int
        let name: String
    }

    @Test("Complex type")
    func complexType() {
        let val = ComplexType(id: 1, name: "test")
        let h = AnySendableHashable(val)

        #expect(h.unwrap(as: ComplexType.self) == val)
        #expect(h == AnySendableHashable(ComplexType(id: 1, name: "test")))
        #expect(h != AnySendableHashable(ComplexType(id: 2, name: "test")))
    }
}
