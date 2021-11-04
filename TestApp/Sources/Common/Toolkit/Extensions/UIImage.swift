//
//  UIImage.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 8/24/17.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
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
