//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import PDFKit
import ReadiumShared
import UIKit

/// A decoration with fully resolved rendering geometry on a PDF page.
struct PDFDecorationRenderItem {
    let decoration: Decoration
    let group: DecorationGroup
    /// Final rects handed to the template renderer, in PDF user space (origin
    /// at the bottom-left corner).
    let rects: [CGRect]
    let template: PDFDecorationTemplate
}

/// A unit of rendering in the overlay view: one subview per unit.
enum PDFDecorationRenderUnit {
    /// A single decoration rendered on its own (`.view` and `.draw`
    /// templates).
    case single(PDFDecorationRenderItem)
    /// All the decorations of a (group, style) pair rendered as one merged
    /// view (`.viewMerged` templates).
    case merged([PDFDecorationRenderItem])
}

/// Identifies the (group, style) pair merged into a single render unit.
private struct MergeKey: Hashable {
    let group: DecorationGroup
    let style: Decoration.Style.Id
}

extension Array where Element == PDFDecorationRenderItem {
    /// Groups the render items into render units, preserving the z-order.
    ///
    /// Items with a `.viewMerged` template are merged per (group, style)
    /// across the whole page — even non-contiguous ones — and the merged unit
    /// sits in z-order at the first such item's position.
    func renderUnits() -> [PDFDecorationRenderUnit] {
        var units: [PDFDecorationRenderUnit] = []
        var mergedIndexes: [MergeKey: Int] = [:]

        for item in self {
            guard case .viewMerged = item.template.renderer else {
                units.append(.single(item))
                continue
            }
            let key = MergeKey(group: item.group, style: item.decoration.style.id)
            if let index = mergedIndexes[key], case let .merged(items) = units[index] {
                units[index] = .merged(items + [item])
            } else {
                mergedIndexes[key] = units.count
                units.append(.merged([item]))
            }
        }
        return units
    }
}

extension CGRect {
    /// Converts a rect from PDF user space to the overlay view's UIKit space.
    ///
    /// PDFKit installs the overlay view in the page's coordinate space and
    /// applies the zoom and rotation transforms itself; the only conversion
    /// needed here is flipping between PDF user space's bottom-left origin
    /// and UIKit's top-left origin within the page.
    func convertedFromPDFSpace(pageBounds: CGRect) -> CGRect {
        CGRect(
            x: minX - pageBounds.minX,
            y: pageBounds.maxY - maxY,
            width: width,
            height: height
        )
    }
}

@available(iOS 16.0, *)
@MainActor
protocol PDFDecorationOverlayDataSource: AnyObject {
    /// Returns the decorations to render over the page at `pageIndex`, in
    /// ascending z-order.
    func decorationOverlayProvider(
        _ provider: PDFDecorationOverlayProvider,
        decorationsForPageAt pageIndex: Int,
        in document: PDFKit.PDFDocument
    ) -> [PDFDecorationRenderItem]
}

/// Vends and configures the per-page overlay views rendering the decorations.
@available(iOS 16.0, *)
@MainActor
final class PDFDecorationOverlayProvider: NSObject {
    weak var dataSource: PDFDecorationOverlayDataSource?

    /// Maximum rasterization scale for `.draw` templates. The backing-store
    /// memory grows quadratically with the scale and PDFKit allows deep zoom,
    /// so drawings get blurry past this cap.
    private static let maxRasterizationScale: CGFloat = 4

    /// Overlay views for the pages currently (or recently) displayed. The
    /// keys are weak so the provider doesn't retain pages of the shared
    /// cached document.
    private let overlays = NSMapTable<PDFPage, PDFDecorationOverlayView>(
        keyOptions: [.weakMemory, .objectPointerPersonality],
        valueOptions: .strongMemory
    )

    private var contentsScale: CGFloat = UIScreen.main.scale

    /// Reconfigures all the live overlay views from the data source, e.g.
    /// after the decorations changed.
    func refresh(in pdfView: PDFView) {
        guard let document = pdfView.document else {
            return
        }
        for page in overlays.keyEnumerator().allObjects.compactMap({ $0 as? PDFPage }) {
            if let overlay = overlays.object(forKey: page) {
                configure(overlay, for: page, in: document)
            }
        }
    }

    /// Keeps `.draw` canvases sharp under zoom by updating their
    /// rasterization scale, capped at `maxRasterizationScale`.
    func didChangeScaleFactor(of pdfView: PDFView) {
        let screenScale = pdfView.window?.screen.scale ?? UIScreen.main.scale
        contentsScale = min(max(pdfView.scaleFactor, 1), Self.maxRasterizationScale) * screenScale

        for overlay in overlays.objectEnumerator()?.allObjects ?? [] {
            (overlay as? PDFDecorationOverlayView)?.contentsScale = contentsScale
        }
    }

    private func configure(_ overlay: PDFDecorationOverlayView, for page: PDFPage, in document: PDFKit.PDFDocument) {
        let pageIndex = document.index(for: page)
        guard pageIndex != NSNotFound else {
            return
        }
        overlay.configure(
            items: dataSource?.decorationOverlayProvider(self, decorationsForPageAt: pageIndex, in: document) ?? [],
            pageBounds: page.bounds(for: .cropBox),
            contentsScale: contentsScale
        )
    }
}

@available(iOS 16.0, *)
extension PDFDecorationOverlayProvider: @preconcurrency PDFPageOverlayViewProvider {
    func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> UIView? {
        guard let document = view.document else {
            return nil
        }
        // PDFKit recycles overlay views across pages, so the view is fully
        // reconfigured for the requested page on every call.
        let overlay = overlays.object(forKey: page) ?? {
            let overlay = PDFDecorationOverlayView()
            overlays.setObject(overlay, forKey: page)
            return overlay
        }()
        configure(overlay, for: page, in: document)
        return overlay
    }

    func pdfView(_ pdfView: PDFView, willEndDisplayingOverlayView overlayView: UIView, for page: PDFPage) {
        overlays.removeObject(forKey: page)
    }
}

/// The overlay view hosting the decorations of a single page.
///
/// Each decoration gets one lightweight subview — a container for its `.view`
/// rect views, or a canvas view whose `draw(_:)` invokes the `.draw` closure —
/// so all decorations stack purely by subview order. `.draw` templates are
/// deliberately not drawn in this view's own `draw(_:)`: subviews would
/// always composite above them, breaking the z-order.
@available(iOS 16.0, *)
private final class PDFDecorationOverlayView: UIView {
    private var canvases: [PDFDecorationCanvasView] = []

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var contentsScale: CGFloat = 1 {
        didSet {
            guard contentsScale != oldValue else {
                return
            }
            for canvas in canvases {
                canvas.layer.contentsScale = contentsScale
                canvas.setNeedsDisplay()
            }
        }
    }

    func configure(items: [PDFDecorationRenderItem], pageBounds: CGRect, contentsScale: CGFloat) {
        for subview in subviews {
            subview.removeFromSuperview()
        }
        canvases.removeAll()
        self.contentsScale = contentsScale

        let pageFrame = CGRect(origin: .zero, size: pageBounds.size)

        for unit in items.renderUnits() {
            switch unit {
            case let .single(item):
                let rects = item.rects.map { $0.convertedFromPDFSpace(pageBounds: pageBounds) }

                switch item.template.renderer {
                case let .view(makeView):
                    let container = UIView(frame: pageFrame)
                    container.isUserInteractionEnabled = false
                    container.clipsToBounds = item.template.clipsToPageBounds
                    for rect in rects {
                        let view = makeView(item.decoration, rect)
                        view.frame = rect
                        view.isUserInteractionEnabled = false
                        container.addSubview(view)
                    }
                    addSubview(container)

                case let .draw(draw):
                    let canvas = PDFDecorationCanvasView(
                        frame: pageFrame,
                        decoration: item.decoration,
                        rects: rects,
                        drawer: draw
                    )
                    canvas.clipsToBounds = item.template.clipsToPageBounds
                    canvas.layer.contentsScale = contentsScale
                    canvases.append(canvas)
                    addSubview(canvas)

                case .viewMerged:
                    // `renderUnits()` always yields `.viewMerged` items in a
                    // `.merged` unit.
                    continue
                }

            case let .merged(mergedItems):
                guard
                    let template = mergedItems.first?.template,
                    case let .viewMerged(makeView) = template.renderer
                else {
                    continue
                }
                let decorations = mergedItems.map { item in
                    (item.decoration, item.rects.map { $0.convertedFromPDFSpace(pageBounds: pageBounds) })
                }
                let view = makeView(decorations, pageFrame)
                view.frame = pageFrame
                view.isUserInteractionEnabled = false
                view.clipsToBounds = template.clipsToPageBounds
                addSubview(view)
            }
        }
    }
}

/// Renders a single `.draw` decoration template.
@available(iOS 16.0, *)
private final class PDFDecorationCanvasView: UIView {
    private let decoration: Decoration
    private let rects: [CGRect]
    private let drawer: @MainActor @Sendable (Decoration, [CGRect], CGContext) -> Void

    init(
        frame: CGRect,
        decoration: Decoration,
        rects: [CGRect],
        drawer: @escaping @MainActor @Sendable (Decoration, [CGRect], CGContext) -> Void
    ) {
        self.decoration = decoration
        self.rects = rects
        self.drawer = drawer
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        drawer(decoration, rects, context)
    }
}
