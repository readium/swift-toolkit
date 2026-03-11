//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

public extension InputObserving where Self == PinchPointerObserver {
    /// Recognizes a pinch (zoom) input event from two touch pointers.
    ///
    /// - Parameter onPinch: Called for each pinch event phase. Returns whether
    ///   the event was consumed.
    static func pinch(
        onPinch: @MainActor @escaping (PinchEvent) async -> Bool
    ) -> PinchPointerObserver {
        PinchPointerObserver(onPinch: onPinch)
    }
}

/// Pointer observer recognizing a two-finger pinch gesture.
///
/// Tracks two simultaneous touch pointers and computes the scale factor
/// relative to the initial distance between them.
@MainActor public final class PinchPointerObserver: InputObserving, Loggable {
    private let onPinch: @MainActor (PinchEvent) async -> Bool

    public init(
        onPinch: @MainActor @escaping (PinchEvent) async -> Bool
    ) {
        self.onPinch = onPinch
    }

    private enum State {
        case idle
        /// One pointer is down, waiting for a second.
        case onePointer(id: AnyHashable, location: CGPoint)
        /// Two pointers are down, pinch in progress.
        case pinching(
            first: PointerInfo,
            second: PointerInfo,
            initialDistance: CGFloat
        )
        /// More than two pointers or gesture cancelled.
        case failed(activePointers: Set<AnyHashable>)
    }

    private struct PointerInfo {
        let id: AnyHashable
        var location: CGPoint
    }

    private var state: State = .idle

    /// Tracks the target element info captured at the start of the pinch.
    private var pinchTarget: GestureTarget?

    public func didReceive(_ event: PointerEvent) async -> Bool {
        // Only recognize touch pointers.
        guard event.pointer.type == .touch else {
            return false
        }

        let (newState, pinchEvent) = transition(state: state, event: event)
        state = newState

        if let pinchEvent {
            return await onPinch(pinchEvent)
        }

        return false
    }

    public func didReceive(_ event: KeyEvent) async -> Bool {
        false
    }

    private func transition(
        state: State,
        event: PointerEvent
    ) -> (State, PinchEvent?) {
        let id = event.pointer.id

        switch (state, event.phase) {
        // -- Waiting for pointers --

        case (.idle, .down):
            return (.onePointer(id: id, location: event.location), nil)

        case let (.onePointer(firstID, firstLocation), .down) where firstID != id:
            let initialDistance = distance(firstLocation, event.location)
            guard initialDistance > 0 else {
                return (.failed(activePointers: [firstID, id]), nil)
            }
            let first = PointerInfo(id: firstID, location: firstLocation)
            let second = PointerInfo(id: id, location: event.location)
            let center = midpoint(firstLocation, event.location)
            pinchTarget = event.targetElementInfo.map { info in
                GestureTarget(
                    frame: info.frame,
                    content: info.src.map { .media(Link(href: $0)) },
                    rawContent: info.outerHTML.map { .init(type: "text/html", data: $0) }
                )
            }
            let pinchEvent = PinchEvent(phase: .start, center: center, scale: 1.0, target: pinchTarget)
            return (
                .pinching(first: first, second: second, initialDistance: initialDistance),
                pinchEvent
            )

        case let (.onePointer(firstID, _), .up) where firstID == id,
             let (.onePointer(firstID, _), .cancel) where firstID == id:
            return (.idle, nil)

        case let (.onePointer(firstID, location), .move) where firstID == id:
            return (.onePointer(id: firstID, location: event.location), nil)

        // -- Pinching --

        case let (.pinching(first, second, initialDistance), .move):
            var first = first
            var second = second
            if id == first.id {
                first.location = event.location
            } else if id == second.id {
                second.location = event.location
            } else {
                return (state, nil)
            }
            let currentDistance = distance(first.location, second.location)
            let scale = currentDistance / initialDistance
            let center = midpoint(first.location, second.location)
            let pinchEvent = PinchEvent(phase: .changed, center: center, scale: scale, target: pinchTarget)
            return (
                .pinching(first: first, second: second, initialDistance: initialDistance),
                pinchEvent
            )

        case let (.pinching(first, second, initialDistance), .up):
            if id == first.id || id == second.id {
                let currentDistance = distance(first.location, second.location)
                let scale = currentDistance / initialDistance
                let center = midpoint(first.location, second.location)
                let pinchEvent = PinchEvent(phase: .end, center: center, scale: scale, target: pinchTarget)
                pinchTarget = nil
                let remainingID = id == first.id ? second.id : first.id
                let remainingLocation = id == first.id ? second.location : first.location
                return (.onePointer(id: remainingID, location: remainingLocation), pinchEvent)
            }
            return (state, nil)

        case let (.pinching(first, second, initialDistance), .cancel):
            if id == first.id || id == second.id {
                let currentDistance = distance(first.location, second.location)
                let scale = currentDistance / initialDistance
                let center = midpoint(first.location, second.location)
                let pinchEvent = PinchEvent(phase: .cancel, center: center, scale: scale, target: pinchTarget)
                pinchTarget = nil
                let remainingID = id == first.id ? second.id : first.id
                let remainingLocation = id == first.id ? second.location : first.location
                return (.onePointer(id: remainingID, location: remainingLocation), pinchEvent)
            }
            return (state, nil)

        case let (.pinching(first, second, initialDistance), .down):
            // Third pointer - cancel the pinch.
            let currentDistance = distance(first.location, second.location)
            let scale = currentDistance / initialDistance
            let center = midpoint(first.location, second.location)
            let pinchEvent = PinchEvent(phase: .cancel, center: center, scale: scale, target: pinchTarget)
            pinchTarget = nil
            return (.failed(activePointers: [first.id, second.id, id]), pinchEvent)

        // -- Failed --

        case var (.failed(activePointers), .down):
            activePointers.insert(id)
            return (.failed(activePointers: activePointers), nil)

        case var (.failed(activePointers), .up),
             var (.failed(activePointers), .cancel):
            activePointers.remove(id)
            return (activePointers.isEmpty ? .idle : .failed(activePointers: activePointers), nil)

        default:
            return (state, nil)
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}
