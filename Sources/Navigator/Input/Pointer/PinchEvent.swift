//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents a pinch gesture event emitted by a navigator.
public struct PinchEvent: Equatable {
    /// Phase of this pinch event.
    public let phase: Phase

    /// Center point of the pinch gesture relative to the navigator's view.
    public let center: CGPoint

    /// Scale factor relative to the start of the pinch gesture.
    ///
    /// A value greater than 1.0 indicates a zoom-in (spread apart), and a
    /// value less than 1.0 indicates a zoom-out (pinch together).
    public let scale: CGFloat

    /// Metadata about the element at the center of the pinch, if available.
    public let target: GestureTarget?

    public init(phase: Phase, center: CGPoint, scale: CGFloat, target: GestureTarget? = nil) {
        self.phase = phase
        self.center = center
        self.scale = scale
        self.target = target
    }

    /// Phase of a pinch gesture event.
    public enum Phase: Equatable, CustomStringConvertible {
        /// The pinch gesture started.
        case start

        /// The pinch gesture changed (fingers moved).
        case changed

        /// The pinch gesture ended.
        case end

        /// The pinch gesture was cancelled.
        case cancel

        public var description: String {
            switch self {
            case .start: "start"
            case .changed: "changed"
            case .end: "end"
            case .cancel: "cancel"
            }
        }
    }
}
