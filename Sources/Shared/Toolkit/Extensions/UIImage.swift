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
    typealias ReleaseDocument = @convention(c) (CFTypeRef) -> Void

    static let createFromData: CreateFromData? = load("CGSVGDocumentCreateFromData")
    static let getCanvasSize: GetCanvasSize? = load("CGSVGDocumentGetCanvasSize")
    static let drawInContext: DrawInContext? = load("CGContextDrawSVGDocument")
    static let releaseDocument: ReleaseDocument? = load("CGSVGDocumentRelease")

    private static func load<T>(_ name: String) -> T? {
        guard let sym = dlsym(dlopen(nil, RTLD_LAZY), name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }
}

extension UIImage {
    /// Creates a `UIImage` by rendering an SVG document from the given data,
    /// scaled down to fit `maxSize` while preserving the aspect ratio.
    ///
    /// If the SVG canvas is smaller than `maxSize`, it is rendered at its
    /// native size to avoid upscaling embedded bitmaps.
    ///
    /// Returns `nil` if the data is not a valid SVG or if SVG rendering is
    /// unavailable on the current platform.
    static func fromSVG(_ data: Data, maxSize: CGSize) -> UIImage? {
        guard
            let createFromData = CoreSVG.createFromData,
            let getCanvasSize = CoreSVG.getCanvasSize,
            let drawInContext = CoreSVG.drawInContext,
            let releaseDocument = CoreSVG.releaseDocument,
            let document = createFromData(data as CFData, nil)
        else {
            return nil
        }
        let svgDocument = document.takeUnretainedValue()
        defer { releaseDocument(svgDocument) }

        let canvasSize = getCanvasSize(svgDocument)
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            return nil
        }

        // Render at the smaller of the canvas size and the requested max
        // size, preserving the SVG aspect ratio.
        let renderSize: CGSize
        if canvasSize.width <= maxSize.width, canvasSize.height <= maxSize.height {
            renderSize = canvasSize
        } else {
            let targetRect = AVMakeRect(
                aspectRatio: canvasSize,
                insideRect: CGRect(origin: .zero, size: maxSize)
            )
            renderSize = targetRect.size
        }

        let renderer = UIGraphicsImageRenderer(size: renderSize)
        return renderer.image { ctx in
            let cgContext = ctx.cgContext
            let scaleX = renderSize.width / canvasSize.width
            let scaleY = renderSize.height / canvasSize.height
            cgContext.translateBy(x: 0, y: renderSize.height)
            cgContext.scaleBy(x: scaleX, y: -scaleY)
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
