//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import Testing

private final class RecyclableSpy: Recyclable {
    var canBeRecycled: Bool

    init(canBeRecycled: Bool = true) {
        self.canBeRecycled = canBeRecycled
    }
}

@Suite("RecyclingPool")
struct RecyclingPoolTests {
    @Test("hands back a pooled instance")
    func popsPushedElement() {
        var pool = RecyclingPool<RecyclableSpy>(capacity: 2)
        let element = RecyclableSpy()

        pool.push(element)

        #expect(pool.pop() === element)
        #expect(pool.pop() == nil)
    }

    @Test("is empty until something is pooled")
    func emptyPool() {
        var pool = RecyclingPool<RecyclableSpy>(capacity: 2)

        #expect(pool.isEmpty)
        #expect(pool.pop() == nil)
    }

    @Test("refuses instances that are already ineligible")
    func rejectsIneligibleOnPush() {
        var pool = RecyclingPool<RecyclableSpy>(capacity: 2)

        pool.push(RecyclableSpy(canBeRecycled: false))

        #expect(pool.isEmpty)
    }

    /// An instance can stop being eligible after it was pooled, for example
    /// because a setting baked into it changed in the meantime. Checking only
    /// on the way in would hand it out anyway.
    @Test("discards instances that became ineligible while pooled")
    func rejectsIneligibleOnPop() {
        var pool = RecyclingPool<RecyclableSpy>(capacity: 3)
        let stale = RecyclableSpy()
        let usable = RecyclableSpy()

        pool.push(usable)
        pool.push(stale)
        stale.canBeRecycled = false

        #expect(pool.pop() === usable)
        #expect(pool.isEmpty)
    }

    @Test("hands out nothing when every pooled instance went stale")
    func allPooledElementsBecameIneligible() {
        var pool = RecyclingPool<RecyclableSpy>(capacity: 3)
        let elements = [RecyclableSpy(), RecyclableSpy()]

        for element in elements {
            pool.push(element)
        }
        for element in elements {
            element.canBeRecycled = false
        }

        #expect(pool.pop() == nil)
        #expect(pool.isEmpty)
    }

    /// A settings toggle can invalidate everything sitting in a full pool.
    /// Those entries will never be handed out, so they must not keep usable
    /// ones from being pooled.
    @Test("does not let stale instances take up capacity")
    func staleElementsDoNotConsumeCapacity() {
        var pool = RecyclingPool<RecyclableSpy>(capacity: 2)
        let stale = RecyclableSpy()
        let usable = RecyclableSpy()
        pool.push(stale)
        pool.push(usable)

        stale.canBeRecycled = false
        let fresh = RecyclableSpy()
        pool.push(fresh)

        #expect(pool.count == 2)
        #expect(pool.pop() === fresh)
        #expect(pool.pop() === usable)
        #expect(pool.pop() == nil)
    }

    /// A caller holding resources on a rejected instance's behalf has to know
    /// it was rejected, so it can release them instead of letting them go with
    /// it.
    @Test("reports whether the instance was kept")
    func pushReportsAcceptance() {
        var pool = RecyclingPool<RecyclableSpy>(capacity: 1)

        #expect(pool.push(RecyclableSpy()) == true)
        #expect(pool.push(RecyclableSpy()) == false, "The pool is full")
        #expect(pool.push(RecyclableSpy(canBeRecycled: false)) == false, "The instance is not reusable")
    }

    @Test("drops instances offered beyond its capacity")
    func honoursCapacity() {
        var pool = RecyclingPool<RecyclableSpy>(capacity: 2)

        for _ in 0 ..< 5 {
            pool.push(RecyclableSpy())
        }

        #expect(pool.count == 2)
    }

    @Test("keeps nothing when built with no capacity")
    func zeroCapacity() {
        var pool = RecyclingPool<RecyclableSpy>(capacity: 0)

        pool.push(RecyclableSpy())

        #expect(pool.isEmpty)
        #expect(pool.pop() == nil)
    }

    @Test("forgets everything on removeAll")
    func removesAll() {
        var pool = RecyclingPool<RecyclableSpy>(capacity: 2)
        pool.push(RecyclableSpy())

        pool.removeAll()

        #expect(pool.isEmpty)
        #expect(pool.pop() == nil)
    }
}
