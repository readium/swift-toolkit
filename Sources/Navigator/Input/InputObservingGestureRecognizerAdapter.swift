//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import UIKit
import UIKit.UIGestureRecognizerSubclass

/// A ``UIGestureRecognizer`` that will forward the touch events to an
/// ``InputObserving``. It will never recognize any gesture, only forward the
/// events.
final class InputObservingGestureRecognizerAdapter: UIGestureRecognizer {
    let observer: InputObserving

    init(observer: CompositeInputObserver) {
        self.observer = observer
        super.init(target: nil, action: nil)
    }

    /// Stores the ``PointerEvent`` that were notified to the `observer`, to
    /// cancel them if the gesture recognizer is resetted before the touches
    /// are cancelled or ended.
    private var pendingPointers: [AnyHashable: PointerEvent] = [:]

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        on(.down, touches: touches, event: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        on(.move, touches: touches, event: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        on(.cancel, touches: touches, event: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        on(.up, touches: touches, event: event)
    }

    override func reset() {
        // The gesture recognizer can be resetted without receiving the ended
        // or cancelled callbacks for touch events already sent. We will cancel
        // them manually for the observer.
        let pointersToReset = pendingPointers
        pendingPointers = [:]
        Task {
            for (_, event) in pointersToReset {
                var event = event
                event.phase = .cancel
                _ = await observer.didReceive(event)
            }
        }
    }

    private func on(_ phase: PointerEvent.Phase, touches: Set<UITouch>, event: UIEvent) {
        Task {
            for touch in touches {
                guard let view = view else {
                    continue
                }

                let pointer = Pointer(touch: touch, event: event)
                let pointerEvent = PointerEvent(
                    pointer: pointer,
                    phase: phase,
                    location: touch.location(in: view),
                    modifiers: KeyModifiers(event: event)
                )

                switch phase {
                case .down, .move:
                    pendingPointers[pointer.id] = pointerEvent
                case .up, .cancel:
                    pendingPointers.removeValue(forKey: pointer.id)
                }

                _ = await observer.didReceive(pointerEvent)
            }
        }
    }
}
