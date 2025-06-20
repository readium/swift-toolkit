//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import SwiftSoup
import UIKit

/// An `HTMLDecorationTemplate` renders a `Decoration` into a set of HTML elements and associated stylesheet.
public struct HTMLDecorationTemplate {
    /// Determines the number of created HTML elements and their position relative to the matching DOM range.
    public enum Layout: String {
        /// A single HTML element covering the smallest region containing all CSS border boxes.
        case bounds
        /// One HTML element for each CSS border box (e.g. line of text).
        case boxes
    }

    /// Indicates how the width of each created HTML element expands in the viewport.
    public enum Width: String {
        /// Smallest width fitting the CSS border box.
        case wrap
        /// Fills the bounds layout.
        case bounds
        /// Fills the anchor page, useful for dual page.
        case viewport
        /// Fills the whole viewport.
        case page
    }

    let layout: Layout
    let width: Width
    let element: (Decoration) -> String
    let stylesheet: String?

    public init(layout: Layout, width: Width = .wrap, element: @escaping (Decoration) -> String = { _ in "<div/>" }, stylesheet: String? = nil) {
        self.layout = layout
        self.width = width
        self.element = element
        self.stylesheet = stylesheet
    }

    public init(layout: Layout, width: Width = .wrap, element: String = "<div/>", stylesheet: String? = nil) {
        self.init(layout: layout, width: width, element: { _ in element }, stylesheet: stylesheet)
    }

    public var json: [String: Any] {
        [
            "layout": layout.rawValue,
            "width": width.rawValue,
            "stylesheet": stylesheet as Any,
        ]
    }

    /// Creates the default list of decoration styles with associated HTML templates.
    public static func defaultTemplates(
        defaultTint: UIColor = .yellow,
        lineWeight: Int = 2,
        cornerRadius: Int = 3,
        alpha: Double = 0.3
    ) -> [Decoration.Style.Id: HTMLDecorationTemplate] {
        let padding = UIEdgeInsets(top: 0, left: 1, bottom: 0, right: 1)
        return [
            .highlight: .highlight(defaultTint: defaultTint, padding: padding, lineWeight: lineWeight, cornerRadius: cornerRadius, alpha: alpha),
            .underline: .underline(defaultTint: defaultTint, padding: padding, lineWeight: lineWeight, cornerRadius: cornerRadius, alpha: alpha),
        ]
    }

    /// Creates a new decoration template for the `highlight` style.
    public static func highlight(defaultTint: UIColor, padding: UIEdgeInsets, lineWeight: Int, cornerRadius: Int, alpha: Double) -> HTMLDecorationTemplate {
        makeTemplate(asHighlight: true, defaultTint: defaultTint, padding: padding, lineWeight: lineWeight, cornerRadius: cornerRadius, alpha: alpha)
    }

    /// Creates a new decoration template for the `underline` style.
    public static func underline(defaultTint: UIColor, padding: UIEdgeInsets, lineWeight: Int, cornerRadius: Int, alpha: Double) -> HTMLDecorationTemplate {
        makeTemplate(asHighlight: false, defaultTint: defaultTint, padding: padding, lineWeight: lineWeight, cornerRadius: cornerRadius, alpha: alpha)
    }

    /// - Parameter asHighlight: When true, the non active style is of an highlight. Otherwise, it is an underline.
    private static func makeTemplate(asHighlight: Bool, defaultTint: UIColor, padding: UIEdgeInsets, lineWeight: Int, cornerRadius: Int, alpha: Double) -> HTMLDecorationTemplate {
        let className = makeUniqueClassName(key: asHighlight ? "highlight" : "underline")
        return HTMLDecorationTemplate(
            layout: .boxes,
            element: { decoration in
                let config = decoration.style.config as! Decoration.Style.HighlightConfig
                let tint = config.tint ?? defaultTint
                let isActive = config.isActive
                var css = ""
                if asHighlight || isActive {
                    css += "background-color: \(tint.cssValue(alpha: alpha)) !important;"
                }
                if !asHighlight || isActive {
                    css += "--underline-color: \(tint.cssValue());"
                }
                return "<div class=\"\(className)\" style=\"\(css)\"/>"
            },
            stylesheet:
            """
            .\(className) {
                margin: \(-padding.top)px \(-padding.left)px 0 0;
                padding: 0 \(padding.left + padding.right)px \(padding.top + padding.bottom)px 0;
                border-radius: \(cornerRadius)px;
                box-sizing: border-box;
                border: 0 solid var(--underline-color);
            }

            /* Horizontal (default) */
            [data-writing-mode="horizontal-tb"].\(className) {
                border-bottom-width: \(lineWeight)px;
            }

            /* Vertical right-to-left */
            [data-writing-mode="vertical-rl"].\(className),
            [data-writing-mode="sideways-rl"].\(className) {
                border-left-width: \(lineWeight)px;
            }

            /* Vertical left-to-right */
            [data-writing-mode="vertical-lr"].\(className),
            [data-writing-mode="sideways-lr"].\(className) {
                border-right-width: \(lineWeight)px;
            }    
            """
        )
    }

    private static var classNamesId = 0
    private static func makeUniqueClassName(key: String) -> String {
        classNamesId += 1
        return "readium-\(key)-\(classNamesId)"
    }
}
