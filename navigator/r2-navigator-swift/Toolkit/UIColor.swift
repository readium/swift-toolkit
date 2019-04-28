//
//  UIColor.swift
//  r2-navigator-swift
//
//  Created by Mickaël Menu on 15.04.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit


extension UIColor {
    
    var hexString: String? {
        return hexString(includingAlpha: true)
    }
    
    func hexString(includingAlpha: Bool) -> String? {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let red = lroundf(Float(r) * 255)
        let green = lroundf(Float(g) * 255)
        let blue = lroundf(Float(b) * 255)
        
        if includingAlpha {
            let alpha =  lroundf(Float(a) * 255)
            return String(format: "%02lX%02lX%02lX%02lX", red, green, blue, alpha)
        } else {
            return String(format: "%02lX%02lX%02lX", red, green, blue)
        }
    }
    
}
