//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension InputObserving where Self == DragPointerObserver {
    static func drag(
        onStart: @MainActor @escaping (PointerEvent) -> Bool = { _ in false },
        onMove: @MainActor @escaping (PointerEvent) -> Bool = { _ in false },
        onEnd: @MainActor @escaping (PointerEvent) -> Bool = { _ in false },
        onCancel: @MainActor @escaping (PointerEvent) -> Bool = { _ in false }
    ) -> DragPointerObserver {
        DragPointerObserver(
            onStart: onStart,
            onMove: onMove,
            onEnd: onEnd,
            onCancel: onCancel
        )
    }
}

/// Pointer observer recognizing drag gestures.
@MainActor public final class DragPointerObserver: InputObserving {
    private let onStart: @MainActor (PointerEvent) -> Bool
    private let onMove: @MainActor (PointerEvent) -> Bool
    private let onEnd: @MainActor (PointerEvent) -> Bool
    private let onCancel: @MainActor (PointerEvent) -> Bool

    public init(
        onStart: @MainActor @escaping (PointerEvent) -> Bool,
        onMove: @MainActor @escaping (PointerEvent) -> Bool,
        onEnd: @MainActor @escaping (PointerEvent) -> Bool,
        onCancel: @MainActor @escaping (PointerEvent) -> Bool
    ) {
        self.onStart = onStart
        self.onMove = onMove
        self.onEnd = onEnd
        self.onCancel = onCancel
    }

    private var state: State = .idle

    private enum State {
        case idle
        case pending(id: AnyHashable, startLocation: CGPoint)
        case dragging(id: AnyHashable, lastEvent: PointerEvent)
        case failed(activePointers: Set<AnyHashable>)
    }

    private enum Action {
        case start(PointerEvent)
        case move(PointerEvent)
        case end(PointerEvent)
        case cancel(PointerEvent)
        case none
    }

    public func didReceive(_ event: KeyEvent) async -> Bool {
        false
    }

    public func didReceive(_ event: PointerEvent) async -> Bool {
        let (newState, action) = transition(state: state, event: event)
        state = newState

        switch action {
        case let .start(event):
            return onStart(event)
        case let .move(event):
            return onMove(event)
        case let .end(event):
            return onEnd(event)
        case let .cancel(event):
            return onCancel(event)
        case .none:
            return false
        }
    }

    private func transition(state: State, event: PointerEvent) -> (State, Action) {
        let id = event.pointer.id

        switch (state, event.phase) {
        case (.idle, .down):
            return (.pending(id: id, startLocation: event.location), .none)

        case let (.pending(pendingID, _), .down) where pendingID != id:
            return (.failed(activePointers: [pendingID, id]), .none)

        case let (.pending(pendingID, _), .cancel) where pendingID == id:
            return (.idle, .none)

        case let (.pending(pendingID, startLocation), .move) where pendingID == id:
            // Check if pointer has moved enough to start dragging.
            if abs(startLocation.x - event.location.x) > 1 || abs(startLocation.y - event.location.y) > 1 {
                return (.dragging(id: pendingID, lastEvent: event), .start(event))
            } else {
                return (.pending(id: pendingID, startLocation: startLocation), .none)
            }

        case let (.pending(pendingID, _), .up) where pendingID == id:
            // Pointer went up without moving - this is a tap, not a drag.
            return (.idle, .none)

        case let (.dragging(draggingID, lastEvent), .down) where draggingID != id:
            // Second pointer detected during drag - cancel the drag
            return (.failed(activePointers: [draggingID, id]), .cancel(lastEvent))

        case let (.dragging(draggingID, lastEvent), .cancel) where draggingID == id:
            return (.idle, .cancel(lastEvent))

        case let (.dragging(draggingID, _), .move) where draggingID == id:
            return (.dragging(id: draggingID, lastEvent: event), .move(event))

        case let (.dragging(draggingID, _), .up) where draggingID == id:
            return (.idle, .end(event))

        case var (.failed(activePointers), .down):
            activePointers.insert(id)
            return (.failed(activePointers: activePointers), .none)

        case var (.failed(activePointers), .up),
             var (.failed(activePointers), .cancel):
            activePointers.remove(id)
            if activePointers.isEmpty {
                return (.idle, .none)
            } else {
                return (.failed(activePointers: activePointers), .none)
            }

        default:
            return (state, .none)
        }
    }
}
