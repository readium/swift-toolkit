//
//  UIImage.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 31/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import func AVFoundation.AVMakeRect

extension UIImage {
    
    func scaleToFit(maxSize: CGSize) -> UIImage {
        if size.width <= maxSize.width && size.height <= maxSize.height {
            return self
        }

        let targetRect = AVMakeRect(aspectRatio: size, insideRect: CGRect(origin: .zero, size: maxSize))
        if #available(iOS 10.0, *) {
            let renderer = UIGraphicsImageRenderer(size: targetRect.size)
            return renderer.image { _ in
                draw(in: targetRect)
            }
        } else {
            // FIXME: We're going to move to iOS 10 soon, so for now the fallback doesn't rescale the image
            return self
        }
    }
    
}
