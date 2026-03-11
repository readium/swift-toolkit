//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents a double-tap gesture event emitted by a navigator.
public struct DoubleTapEvent: Equatable {
    /// Location of the double-tap relative to the navigator's view.
    public let location: CGPoint

    /// Metadata about the element that was double-tapped, if available.
    public let target: GestureTarget?

    public init(location: CGPoint, target: GestureTarget? = nil) {
        self.location = location
        self.target = target
    }
}
