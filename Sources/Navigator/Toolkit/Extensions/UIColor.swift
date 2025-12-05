//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import UIKit

public extension UIColor {
    /// Converts the color to a CSS expression.
    ///
    /// - Parameter alpha: When set, overrides the actual color alpha.
    func cssValue(alpha: Double? = nil) -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return "black"
        }
        let red = Int(r * 255)
        let green = Int(g * 255)
        let blue = Int(b * 255)
        return "rgba(\(red), \(green), \(blue), \(alpha ?? Double(a)))"
    }
}
