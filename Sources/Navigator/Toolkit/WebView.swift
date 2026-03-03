//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import WebKit

/// A custom web view which:
///  - Forwards copy: menu action to an EditingActionsController.
final class WebView: WKWebView {
    private let editingActions: EditingActionsController

    init(editingActions: EditingActionsController) {
        self.editingActions = editingActions

        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = .all

        // Disable the Apple Intelligence Writing tools in the web views.
        // See https://github.com/readium/swift-toolkit/issues/509#issuecomment-2577780749
        #if compiler(>=6.0)
            if #available(iOS 18.0, *) {
                config.writingToolsBehavior = .none
            }
        #endif

        super.init(frame: .zero, configuration: config)

        // Transparent background mode: mark as non-opaque BEFORE any content loads.
        // Setting isOpaque after the first render is not reliable on WKWebView —
        // the backing store is already committed as opaque and shows the system white fill.
        if UserDefaults.standard.bool(forKey: "enableTransparentBackground") {
            isOpaque = false
            backgroundColor = .clear
            scrollView.backgroundColor = .clear
            if #available(iOS 15.0, *) {
                underPageBackgroundColor = .clear
            }

            // Inject a MutationObserver at document start so ReadiumCSS's inline
            // style overrides (setCSSProperties) are intercepted before first paint.
            // This runs for every page load for the lifetime of this WKWebView,
            // including the initial loadSpread() which fires before any delegate
            // user scripts can be added.
            let transparencyJS = """
            (function() {
              function fix(t) {
                if (!t || !t.style) return;
                t.style.setProperty('background-color', 'transparent', 'important');
                t.style.setProperty('background', 'transparent', 'important');
                t.style.setProperty('--RS__backgroundColor', 'transparent', 'important');
                t.style.setProperty('--USER__backgroundColor', 'transparent', 'important');
              }
              new MutationObserver(function(muts) {
                muts.forEach(function(m) {
                  if (m.attributeName === 'style' || m.attributeName === 'class') fix(m.target);
                });
              }).observe(document.documentElement, {attributes: true, attributeFilter: ['style', 'class']});
              fix(document.documentElement);
            })();
            """
            configuration.userContentController.addUserScript(WKUserScript(
                source: transparencyJS,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            ))
        }

        #if DEBUG && swift(>=5.8)
            if #available(macOS 13.3, iOS 16.4, *) {
                isInspectable = true
            }
        #endif
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func clearSelection() {
        evaluateJavaScript("window.getSelection().removeAllRanges()")
    }

    override func buildMenu(with builder: any UIMenuBuilder) {
        editingActions.buildMenu(with: builder)

        // Don't call super as it is the only way to remove the
        // "Copy Link with Highlight" menu item.
        // See https://github.com/readium/swift-toolkit/issues/509
//        super.buildMenu(with: builder)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        super.canPerformAction(action, withSender: sender)
            && editingActions.canPerformAction(action)
    }

    override func copy(_ sender: Any?) {
        Task {
            await editingActions.copy()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        setupDragAndDrop()
    }

    private func setupDragAndDrop() {
        if !editingActions.canCopy {
            guard
                let webScrollView = subviews.first(where: { $0 is UIScrollView }),
                let contentView = webScrollView.subviews.first(where: { $0.interactions.count > 1 }),
                let dragInteraction = contentView.interactions.first(where: { $0 is UIDragInteraction })
            else {
                return
            }
            contentView.removeInteraction(dragInteraction)
        }
    }
}
