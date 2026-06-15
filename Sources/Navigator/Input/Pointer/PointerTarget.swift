//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import UIKit

/// Semantic element targeted by a pointer event in the navigator.
public enum PointerTarget: Equatable {
    case image(ImagePointerTarget)
}

/// A bitmap image targeted by a pointer tap.
public struct ImagePointerTarget: Equatable {
    /// Frame in navigator view coordinates (matches ``PointerEvent/location`` space).
    public var frame: CGRect

    /// Publication-relative URL suitable for ``Publication/get(_:)``.
    public var href: AnyURL

    /// Caption or accessibility label, when available.
    public var caption: String?

    public init(frame: CGRect, href: AnyURL, caption: String? = nil) {
        self.frame = frame
        self.href = href
        self.caption = caption
    }
}
