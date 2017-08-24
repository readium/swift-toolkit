//
//  UIImageExtension.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 8/24/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import UIKit

/// SO 33545910/1585121 - Heberti Almeida (inspired).
extension UIImage {
    class func imageWithTextView(textView: UITextView) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(textView.bounds.size, false, 0.0)
        textView.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
}
