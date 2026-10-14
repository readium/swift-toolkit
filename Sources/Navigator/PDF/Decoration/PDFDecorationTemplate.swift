//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import UIKit

/// A `PDFDecorationTemplate` renders a `Decoration` on top of a PDF page.
///
/// The rendering happens in page space: PDFKit applies the zoom and rotation
/// transforms itself, so the produced views and drawings stay glued to the
/// page content.
public struct PDFDecorationTemplate: Sendable {
    /// Determines the set of rects handed to the renderer.
    public enum Layout: Sendable {
        /// One rect per resolved line of text.
        case boxes
        /// A single rect covering the smallest region containing all the line
        /// boxes, computed per page.
        case bounds
    }

    /// Indicates how far each rect extends horizontally.
    ///
    /// The spec's fourth option, `viewport` ("fills the whole viewport"), is
    /// deliberately omitted: the overlay lives in page space, so
    /// viewport-relative geometry doesn't exist there.
    public enum Width: Sendable {
        /// Smallest width fitting the text.
        case wrap
        /// Fills the decoration's bounding box.
        case bounds
        /// Fills the anchor page, e.g. for a sidemark.
        case page
    }

    public enum Renderer: Sendable {
        /// Called once per layout rect (`.boxes` → N calls for an N-line
        /// highlight; `.bounds` → 1 call with the bounding box).
        ///
        /// The overlay sizes and positions the returned view to the rect and
        /// force-disables its user interaction, so decorations never intercept
        /// PDFKit's text-selection gestures or the navigator's tap handling.
        case view(@MainActor @Sendable (_ decoration: Decoration, _ frame: CGRect) -> UIView)

        /// Called once per decoration with the full layout rect set
        /// (`[lineRect...]` for `.boxes`, `[boundingBox]` for `.bounds`), in
        /// the view coordinates of the drawn `context`.
        ///
        /// The drawing is rasterized and rescaled when zooming in, up to a
        /// maximum rasterization scale; past it, the drawing gets blurry.
        /// Prefer `view` with plain `UIView`s when possible, as solid-color
        /// views stay sharp at any zoom level.
        case draw(@MainActor @Sendable (_ decoration: Decoration, _ rects: [CGRect], _ context: CGContext) -> Void)

        /// Called once per (group, style) per page with every decoration of
        /// that style in the group, producing a single page-sized view (e.g. a
        /// mask overlay).
        ///
        /// The merged view is inserted in z-order at the position of the first
        /// merged decoration. The overlay sizes the returned view to
        /// `pageFrame` and force-disables its user interaction.
        case viewMerged(@MainActor @Sendable (_ decorations: [(Decoration, [CGRect])], _ pageFrame: CGRect) -> UIView)
    }

    public var layout: Layout
    public var width: Width
    public var renderer: Renderer

    /// Indicates whether the rendered decorations are clipped to the page
    /// bounds. Disable it for templates meant to bleed into the margins,
    /// e.g. a sidemark.
    public var clipsToPageBounds: Bool

    public init(layout: Layout, width: Width = .wrap, clipsToPageBounds: Bool = true, renderer: Renderer) {
        self.layout = layout
        self.width = width
        self.clipsToPageBounds = clipsToPageBounds
        self.renderer = renderer
    }

    /// Computes the final set of rects handed to the renderer, from the
    /// resolved line boxes.
    ///
    /// All the rects share the same coordinate space; the widths are adjusted
    /// against `pageBounds`, the page's crop box.
    ///
    /// `expand` inflates each line box on every side before the union and
    /// width adjustments, so:
    /// - under `width: .bounds` or `.page` the horizontal inflation is
    ///   overwritten by the width adjustment — `expand` is effectively
    ///   vertical-only there;
    /// - the rects may exceed `pageBounds` — painting outside the page is
    ///   controlled by `clipsToPageBounds`.
    func layoutRects(for lineRects: [CGRect], pageBounds: CGRect, expand: CGFloat = 0) -> [CGRect] {
        let lineRects = (expand != 0)
            ? lineRects.map { $0.insetBy(dx: -expand, dy: -expand) }
            : lineRects

        guard let bounds = lineRects.union() else {
            return []
        }

        var rects: [CGRect]
        switch layout {
        case .boxes:
            rects = lineRects
        case .bounds:
            rects = [bounds]
        }

        switch width {
        case .wrap:
            break
        case .bounds:
            rects = rects.map { CGRect(x: bounds.minX, y: $0.minY, width: bounds.width, height: $0.height) }
        case .page:
            rects = rects.map { CGRect(x: pageBounds.minX, y: $0.minY, width: pageBounds.width, height: $0.height) }
        }
        return rects
    }

    /// Creates the default list of decoration styles with associated PDF
    /// templates.
    ///
    /// - Parameters:
    ///   - defaultTint: Default highlight/underline color when the decoration
    ///     has no tint set.
    ///   - alpha: Opacity of the highlight fill color (0–1).
    ///   - activeAlpha: Opacity of the highlight fill color when the
    ///     decoration is active (0–1).
    ///   - lineWeight: Thickness in page points of the underline and
    ///     strikethrough strokes, and of the outline border.
    public static func defaultTemplates(
        defaultTint: UIColor = .yellow,
        alpha: CGFloat = 0.3,
        activeAlpha: CGFloat = 0.45,
        lineWeight: CGFloat = 2
    ) -> [Decoration.Style.Id: PDFDecorationTemplate] {
        [
            .highlight: .highlight(defaultTint: defaultTint, alpha: alpha, activeAlpha: activeAlpha),
            .underline: .underline(defaultTint: defaultTint, alpha: alpha, lineWeight: lineWeight),
            .strikethrough: .strikethrough(defaultTint: defaultTint, lineWeight: lineWeight),
            .outline: .outline(defaultTint: defaultTint, lineWidth: lineWeight),
            .mask: .mask(defaultTint: defaultTint, alpha: alpha),
        ]
    }

    /// Creates a new decoration template for the `highlight` style.
    public static func highlight(defaultTint: UIColor, alpha: CGFloat = 0.3, activeAlpha: CGFloat = 0.45) -> PDFDecorationTemplate {
        PDFDecorationTemplate(
            layout: .boxes,
            renderer: .view { decoration, frame in
                let (tint, isActive) = decoration.style.highlightConfig(defaultTint: defaultTint)
                let view = UIView(frame: frame)
                view.backgroundColor = tint.withAlphaComponent(isActive ? activeAlpha : alpha)
                return view
            }
        )
    }

    /// Creates a new decoration template for the `underline` style.
    public static func underline(defaultTint: UIColor, alpha: CGFloat = 0.3, lineWeight: CGFloat = 2) -> PDFDecorationTemplate {
        PDFDecorationTemplate(
            layout: .boxes,
            renderer: .view { decoration, frame in
                let (tint, isActive) = decoration.style.highlightConfig(defaultTint: defaultTint)
                let view = UIView(frame: frame)
                if isActive {
                    view.backgroundColor = tint.withAlphaComponent(alpha)
                }
                let line = UIView(frame: CGRect(x: 0, y: frame.height - lineWeight, width: frame.width, height: lineWeight))
                line.backgroundColor = tint
                line.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
                view.addSubview(line)
                return view
            }
        )
    }

    /// Creates a new decoration template for the `strikethrough` style.
    ///
    /// Like `underline`, but the line sits at the vertical center of each
    /// line box.
    public static func strikethrough(defaultTint: UIColor, lineWeight: CGFloat = 2) -> PDFDecorationTemplate {
        PDFDecorationTemplate(
            layout: .boxes,
            renderer: .view { decoration, frame in
                let tint = decoration.style.tint(defaultTint: defaultTint)
                let view = UIView(frame: frame)
                let line = UIView(frame: CGRect(x: 0, y: (frame.height - lineWeight) / 2, width: frame.width, height: lineWeight))
                line.backgroundColor = tint
                line.autoresizingMask = [.flexibleWidth, .flexibleTopMargin, .flexibleBottomMargin]
                view.addSubview(line)
                return view
            }
        )
    }

    /// Creates a new decoration template for the `outline` style, drawing a
    /// border around each line box.
    public static func outline(defaultTint: UIColor, lineWidth: CGFloat = 2) -> PDFDecorationTemplate {
        PDFDecorationTemplate(
            layout: .boxes,
            renderer: .view { decoration, frame in
                let view = UIView(frame: frame)
                view.layer.borderColor = decoration.style.tint(defaultTint: defaultTint).cgColor
                view.layer.borderWidth = lineWidth
                return view
            }
        )
    }

    /// Creates a new decoration template for the `mask` style, dimming the
    /// whole page except the decorated text.
    ///
    /// All the `mask` decorations of a group render as a single page-sized
    /// tinted view whose mask layer punches a hole at every decoration's
    /// rects. The rendering is vector-based, so it stays sharp at any zoom
    /// level without rasterization.
    ///
    /// The page is tinted with the tint of the first mask decoration rendered
    /// on each page (falling back to `defaultTint`); use a uniform tint or
    /// the default for a consistent color across pages.
    ///
    /// Known limitations:
    /// - A single tint per page.
    /// - Masks in different groups on one page dim each other's holes — keep
    ///   all the masks in a single group.
    public static func mask(defaultTint: UIColor, alpha: CGFloat = 0.3) -> PDFDecorationTemplate {
        PDFDecorationTemplate(
            layout: .boxes,
            renderer: .viewMerged { decorations, pageFrame in
                let tint = decorations.first?.0.style.tint(defaultTint: defaultTint) ?? defaultTint
                let view = UIView(frame: pageFrame)
                view.backgroundColor = tint.withAlphaComponent(alpha)

                let path = UIBezierPath(rect: pageFrame)
                for (_, rects) in decorations {
                    for rect in rects {
                        path.append(UIBezierPath(rect: rect))
                    }
                }
                let mask = CAShapeLayer()
                mask.frame = pageFrame
                mask.fillRule = .evenOdd
                mask.path = path.cgPath
                view.layer.mask = mask
                return view
            }
        )
    }
}

private extension Decoration.Style {
    func highlightConfig(defaultTint: UIColor) -> (tint: UIColor, isActive: Bool) {
        let config = config as? Decoration.Style.HighlightConfig
        return (config?.tint ?? defaultTint, config?.isActive ?? false)
    }

    func tint(defaultTint: UIColor) -> UIColor {
        (config?.base as? BuiltInDecorationConfig)?.tint ?? defaultTint
    }
}
