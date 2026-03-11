//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

public extension InputObserving where Self == DoubleTapPointerObserver {
    /// Recognizes a double-tap input event.
    ///
    /// - Parameters:
    ///   - maxInterval: Maximum time between the two taps to recognize the
    ///     gesture, in seconds.
    ///   - maxDistance: Maximum distance (in points) the pointer can move
    ///     between the two taps.
    ///   - onDoubleTap: Called when the double tap is recognized. Returns
    ///     whether the event was consumed.
    static func doubleTap(
        maxInterval: TimeInterval = 0.3,
        maxDistance: CGFloat = 44,
        onDoubleTap: @MainActor @escaping (DoubleTapEvent) async -> Bool
    ) -> DoubleTapPointerObserver {
        DoubleTapPointerObserver(
            maxInterval: maxInterval,
            maxDistance: maxDistance,
            onDoubleTap: onDoubleTap
        )
    }
}

/// Pointer observer recognizing a double-tap gesture.
///
/// The observer tracks two consecutive tap gestures (down → up without
/// movement) within a configurable time interval and distance threshold.
@MainActor public final class DoubleTapPointerObserver: InputObserving, Loggable {
    private let maxInterval: TimeInterval
    private let maxDistance: CGFloat
    private let onDoubleTap: @MainActor (DoubleTapEvent) async -> Bool

    public init(
        maxInterval: TimeInterval = 0.3,
        maxDistance: CGFloat = 44,
        onDoubleTap: @MainActor @escaping (DoubleTapEvent) async -> Bool
    ) {
        self.maxInterval = maxInterval
        self.maxDistance = maxDistance
        self.onDoubleTap = onDoubleTap
    }

    private enum State {
        case idle
        /// First pointer went down.
        case firstDown(id: AnyHashable, location: CGPoint)
        /// First tap completed, waiting for the second tap.
        case waitingSecondTap(location: CGPoint, timestamp: Date)
        /// Second pointer went down.
        case secondDown(id: AnyHashable, location: CGPoint, firstLocation: CGPoint)
        /// Double tap recognized.
        case recognized
        /// Gesture failed, waiting for all pointers to lift.
        case failed(activePointers: Set<AnyHashable>)
    }

    private var state: State = .idle

    /// Tracks the target element info from the second tap's `down` event.
    private var lastTargetElementInfo: PointerEvent.TargetElementInfo?

    public func didReceive(_ event: PointerEvent) async -> Bool {
        // Only recognize touch pointers.
        guard event.pointer.type == .touch else {
            return false
        }

        state = transition(state: state, event: event)

        if case .recognized = state {
            state = .idle
            let target = lastTargetElementInfo.map { info in
                GestureTarget(
                    frame: info.frame,
                    content: info.src.map { .media(Link(href: $0)) },
                    rawContent: info.outerHTML.map { .init(type: "text/html", data: $0) }
                )
            }
            lastTargetElementInfo = nil
            return await onDoubleTap(DoubleTapEvent(location: event.location, target: target))
        }

        return false
    }

    public func didReceive(_ event: KeyEvent) async -> Bool {
        false
    }

    private func transition(state: State, event: PointerEvent) -> State {
        let id = event.pointer.id

        switch (state, event.phase) {
        // -- First tap --

        case (.idle, .down):
            return .firstDown(id: id, location: event.location)

        case let (.firstDown(firstID, _), .down) where firstID != id:
            return .failed(activePointers: [firstID, id])

        case let (.firstDown(firstID, _), .cancel) where firstID == id:
            return .idle

        case let (.firstDown(firstID, location), .move) where firstID == id:
            if distance(location, event.location) > maxDistance {
                return .failed(activePointers: [firstID])
            }
            return state

        case let (.firstDown(firstID, location), .up) where firstID == id:
            return .waitingSecondTap(location: location, timestamp: Date())

        // -- Waiting for second tap --

        case let (.waitingSecondTap(firstLocation, timestamp), .down):
            let elapsed = Date().timeIntervalSince(timestamp)
            if elapsed > maxInterval {
                lastTargetElementInfo = nil
                return .firstDown(id: id, location: event.location)
            }
            if distance(firstLocation, event.location) > maxDistance {
                lastTargetElementInfo = nil
                return .firstDown(id: id, location: event.location)
            }
            lastTargetElementInfo = event.targetElementInfo
            return .secondDown(id: id, location: event.location, firstLocation: firstLocation)

        // -- Second tap --

        case let (.secondDown(secondID, _, _), .down) where secondID != id:
            return .failed(activePointers: [secondID, id])

        case let (.secondDown(secondID, _, _), .cancel) where secondID == id:
            return .idle

        case let (.secondDown(secondID, location, _), .move) where secondID == id:
            if distance(location, event.location) > maxDistance {
                return .failed(activePointers: [secondID])
            }
            return state

        case let (.secondDown(secondID, _, _), .up) where secondID == id:
            return .recognized

        // -- Failed --

        case var (.failed(activePointers), .down):
            activePointers.insert(id)
            return .failed(activePointers: activePointers)

        case var (.failed(activePointers), .up),
             var (.failed(activePointers), .cancel):
            activePointers.remove(id)
            return activePointers.isEmpty ? .idle : .failed(activePointers: activePointers)

        default:
            return state
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
