//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import func AVFoundation.AVMakeRect
import Foundation
#if os(iOS)
import UIKit

extension UIImage {
    func scaleToFit(maxSize: CGSize) -> UIImage {
        if size.width <= maxSize.width, size.height <= maxSize.height {
            return self
        }

        let targetRect = AVMakeRect(aspectRatio: size, insideRect: CGRect(origin: .zero, size: maxSize))
        let renderer = UIGraphicsImageRenderer(size: targetRect.size)
        return renderer.image { _ in
            draw(in: targetRect)
        }
    }
}

#else
import AppKit

extension NSImage {
    func scaleToFit(maxSize: CGSize) -> NSImage {
        if self.size.width <= maxSize.width, self.size.height <= maxSize.height {
            return self
        }
        
        let targetRect = AVMakeRect(aspectRatio: self.size, insideRect: NSRect(origin: .zero, size: maxSize))
        let newImage = NSImage(size: targetRect.size, flipped: false) { (dstRect) -> Bool in
            self.draw(in: dstRect)
            return true
        }
        return newImage
    }
}
#endif
