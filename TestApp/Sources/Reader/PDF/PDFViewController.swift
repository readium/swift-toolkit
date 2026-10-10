//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumNavigator
import ReadiumShared
import SwiftUI
import UIKit

final class PDFViewController: VisualReaderViewController<PDFNavigatorViewController> {
    private let preferencesStore: AnyUserPreferencesStore<PDFPreferences>

    init(
        publication: Publication,
        locator: Locator?,
        bookId: Book.Id,
        books: BookRepository,
        bookmarks: BookmarkRepository,
        highlights: HighlightRepository,
        initialPreferences: PDFPreferences,
        preferencesStore: AnyUserPreferencesStore<PDFPreferences>
    ) throws {
        self.preferencesStore = preferencesStore

        var templates = PDFDecorationTemplate.defaultTemplates()
        templates.merge(Self.debugDecorationTemplates(), uniquingKeysWith: { _, new in new })

        let navigator = try PDFNavigatorViewController(
            publication: publication,
            initialLocation: locator,
            config: PDFNavigatorViewController.Configuration(
                preferences: initialPreferences,
                editingActions: EditingAction.defaultActions
                    .appending(EditingAction(
                        title: "Highlight",
                        action: #selector(highlightSelection)
                    )),
                decorationTemplates: templates
            )
        )

        super.init(navigator: navigator, publication: publication, bookId: bookId, books: books, bookmarks: bookmarks, highlights: highlights)

        navigator.delegate = self
    }

    @objc func highlightSelection() {
        if let selection = navigator.currentSelection {
            let highlight = Highlight(bookId: bookId, locator: selection.locator, color: .yellow)
            saveHighlight(highlight)
            navigator.clearSelection()
        }
    }

    override func presentUserPreferences() {
        Task {
            let userPrefs = await UserPreferences(
                model: UserPreferencesViewModel(
                    bookId: bookId,
                    preferences: try! preferencesStore.preferences(for: bookId),
                    configurable: navigator,
                    store: preferencesStore
                ),
                onClose: { [weak self] in
                    self?.dismiss(animated: true)
                }
            )
            let vc = UIHostingController(rootView: userPrefs)
            vc.modalPresentationStyle = .formSheet
            present(vc, animated: true)
        }
    }

    // MARK: - Debug decorations

    /// Decorations added with the debug toolbar button, to exercise the
    /// various decoration templates.
    private var debugDecorations: [Decoration] = []

    override func makeNavigationBarButtons() -> [UIBarButtonItem] {
        var buttons = super.makeNavigationBarButtons()
        buttons.append(UIBarButtonItem(image: UIImage(systemName: "wand.and.stars"), style: .plain, target: self, action: #selector(addRandomDebugDecoration)))
        return buttons
    }

    /// Adds a decoration with a random style over the current selection, or
    /// over the whole visible page when nothing is selected.
    @objc private func addRandomDebugDecoration() {
        let locator = navigator.currentSelection?.locator
            // A page-level decoration must not carry any text context, or it
            // would be resolved with a text search instead.
            ?? navigator.currentLocation?.copy(text: { $0 = .init() })
        guard let locator = locator else {
            return
        }

        let tint: UIColor = [.systemRed, .systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemTeal].randomElement()!
        let style: Decoration.Style = [
            .highlight(tint: tint, isActive: Bool.random()),
            .highlight(tint: tint, expand: 4),
            .underline(tint: tint),
            .strikethrough(tint: tint),
            .outline(tint: tint),
            .mask(tint: tint),
//            Decoration.Style(id: "debug-frame", config: Decoration.Style.HighlightConfig(tint: tint)),
//            Decoration.Style(id: "debug-sidemark", config: Decoration.Style.HighlightConfig(tint: tint)),
//            Decoration.Style(id: "debug-block", config: Decoration.Style.HighlightConfig(tint: tint)),
        ].randomElement()!

        debugDecorations.append(Decoration(
            id: "debug-\(UUID().uuidString)",
            locator: locator,
            style: style
        ))
        navigator.apply(decorations: debugDecorations, in: "debug")
        navigator.clearSelection()

        toast("Added \(style.id.rawValue) decoration", on: view, duration: 1)
    }

    /// Templates exercising the layout/width/renderer matrix beyond the
    /// built-in highlight and underline.
    private static func debugDecorationTemplates() -> [Decoration.Style.Id: PDFDecorationTemplate] {
        func tint(of decoration: Decoration) -> UIColor {
            (decoration.style.config as? Decoration.Style.HighlightConfig)?.tint ?? .systemRed
        }

        return [
            // A dashed outline drawn around the decoration's bounding box.
            "debug-frame": PDFDecorationTemplate(
                layout: .bounds,
                renderer: .draw { decoration, rects, context in
                    context.setStrokeColor(tint(of: decoration).cgColor)
                    context.setLineWidth(2)
                    context.setLineDash(phase: 0, lengths: [6, 3])
                    for rect in rects {
                        context.stroke(rect.insetBy(dx: 1, dy: 1))
                    }
                }
            ),
            // A vertical bar in the margin, spanning the decoration's lines.
            "debug-sidemark": PDFDecorationTemplate(
                layout: .bounds,
                width: .page,
                renderer: .draw { decoration, rects, context in
                    let color = tint(of: decoration)
                    for rect in rects {
                        context.setFillColor(color.withAlphaComponent(0.08).cgColor)
                        context.fill(rect)
                        context.setFillColor(color.cgColor)
                        context.fill(CGRect(x: rect.minX + 8, y: rect.minY, width: 4, height: rect.height))
                    }
                }
            ),
            // One bordered block per line, stretched to the bounding box width.
            "debug-block": PDFDecorationTemplate(
                layout: .boxes,
                width: .bounds,
                renderer: .view { decoration, frame in
                    let color = tint(of: decoration)
                    let view = UIView(frame: frame)
                    view.backgroundColor = color.withAlphaComponent(0.2)
                    view.layer.borderColor = color.cgColor
                    view.layer.borderWidth = 1
                    return view
                }
            ),
        ]
    }
}

extension PDFViewController: PDFNavigatorDelegate {}
