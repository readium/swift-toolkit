//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CoreGraphics
import Foundation

/// A [PDF fragment identifier](https://pdfa.org/pdf-fragment-identifiers/)
/// locating a rectangular region on a page.
///
/// Coordinates are expressed in points.
enum PDFRectFragment: Equatable, Sendable {
    /// `highlight=lt,rt,top,btm`, in PDF user space (origin at the bottom-left
    /// corner of the page).
    case highlight(left: Double, right: Double, top: Double, bottom: Double)

    /// `viewrect=left,top,width,height`, with the origin at the top-left
    /// corner of the page.
    case viewrect(left: Double, top: Double, width: Double, height: Double)

    /// Parses all the rect fragments found in the given locator `fragments`,
    /// preserving their order.
    ///
    /// A locator may carry several `highlight=` fragments, one per line of
    /// text.
    static func parse(fragments: [String]) -> [PDFRectFragment] {
        fragments.flatMap { parse(fragment: $0) }
    }

    /// Parses the rect fragments found in a single fragment string, which may
    /// combine several parameters (e.g. `page=3&highlight=10,20,30,5`).
    static func parse(fragment: String) -> [PDFRectFragment] {
        fragment
            .components(separatedBy: CharacterSet(charactersIn: "&#"))
            .compactMap { component in
                let parts = component.components(separatedBy: "=")
                guard parts.count == 2 else {
                    return nil
                }
                let values = parts[1].components(separatedBy: ",").compactMap(Double.init)
                guard values.count == 4 else {
                    return nil
                }
                switch parts[0] {
                case "highlight":
                    return .highlight(left: values[0], right: values[1], top: values[2], bottom: values[3])
                case "viewrect":
                    return .viewrect(left: values[0], top: values[1], width: values[2], height: values[3])
                default:
                    return nil
                }
            }
    }

    /// Converts the fragment to a rect in PDF user space (origin at the
    /// bottom-left corner), for a page with the given crop box.
    func rect(inPageBounds pageBounds: CGRect) -> CGRect {
        switch self {
        case let .highlight(left, right, top, bottom):
            return CGRect(x: left, y: bottom, width: right - left, height: top - bottom)
        case let .viewrect(left, top, width, height):
            return CGRect(
                x: pageBounds.minX + left,
                y: pageBounds.maxY - top - height,
                width: width,
                height: height
            )
        }
    }

    /// Generates a standard-syntax `highlight=` fragment for a rect in PDF
    /// user space.
    static func highlightFragment(for rect: CGRect) -> String {
        "highlight=\(format(rect.minX)),\(format(rect.maxX)),\(format(rect.maxY)),\(format(rect.minY))"
    }

    /// Formats a coordinate with up to two fraction digits, dropping trailing
    /// zeros.
    private static func format(_ value: CGFloat) -> String {
        var string = String(format: "%.2f", value)
        while string.hasSuffix("0") {
            string.removeLast()
        }
        if string.hasSuffix(".") {
            string.removeLast()
        }
        return string
    }
}
