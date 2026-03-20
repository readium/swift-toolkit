//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import func AVFoundation.AVMakeRect
import CoreGraphics
import Foundation
import UIKit

private enum CoreSVG {
    typealias CreateFromData = @convention(c) (CFData, CFDictionary?) -> Unmanaged<CFTypeRef>?
    typealias GetCanvasSize = @convention(c) (CFTypeRef) -> CGSize
    typealias DrawInContext = @convention(c) (CGContext, CFTypeRef) -> Void

    static let createFromData: CreateFromData? = load("CGSVGDocumentCreateFromData")
    static let getCanvasSize: GetCanvasSize? = load("CGSVGDocumentGetCanvasSize")
    static let drawInContext: DrawInContext? = load("CGContextDrawSVGDocument")

    private static func load<T>(_ name: String) -> T? {
        guard let sym = dlsym(dlopen(nil, RTLD_LAZY), name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }
}

extension UIImage {
    /// Creates a `UIImage` by rendering an SVG document from the given data.
    ///
    /// Returns `nil` if the data is not a valid SVG or if SVG rendering is
    /// unavailable on the current platform.
    static func fromSVG(_ data: Data) -> UIImage? {
        guard
            let createFromData = CoreSVG.createFromData,
            let getCanvasSize = CoreSVG.getCanvasSize,
            let drawInContext = CoreSVG.drawInContext,
            let document = createFromData(data as CFData, nil)
        else {
            return nil
        }
        let svgDocument = document.takeRetainedValue()
        let size = getCanvasSize(svgDocument)
        guard size.width > 0, size.height > 0 else {
            return nil
        }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cgContext = ctx.cgContext
            cgContext.translateBy(x: 0, y: size.height)
            cgContext.scaleBy(x: 1, y: -1)
            drawInContext(cgContext, svgDocument)
        }
    }

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
