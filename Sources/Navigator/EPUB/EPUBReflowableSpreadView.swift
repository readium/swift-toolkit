//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit
import WebKit
import R2Shared


/// A view rendering a spread of resources with a reflowable layout.
final class EPUBReflowableSpreadView: EPUBSpreadView {

    private var topConstraint: NSLayoutConstraint!
    private var bottomConstraint: NSLayoutConstraint!
    
    private static let reflowableScript = loadScript(named: "readium-reflowable")
    
    required init(publication: Publication, spread: EPUBSpread, resourcesURL: URL, readingProgression: ReadingProgression, userSettings: UserSettings, scripts: [WKUserScript], animatedLoad: Bool, editingActions: EditingActionsController, contentInset: [UIUserInterfaceSizeClass: EPUBContentInsets]) {
        var scripts = scripts
        
        let layout = ReadiumCSSLayout(languages: publication.metadata.languages, readingProgression: readingProgression)
        scripts.append(WKUserScript(
            source: "window.readiumCSSBaseURL = '\(resourcesURL.appendingPathComponent(layout.readiumCSSBasePath))'",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        
        scripts.append(WKUserScript(source: Self.reflowableScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        
        super.init(publication: publication, spread: spread, resourcesURL: resourcesURL, readingProgression: readingProgression, userSettings: userSettings, scripts: scripts, animatedLoad: animatedLoad, editingActions: editingActions, contentInset: contentInset)
    }

    override func setupWebView() {
        super.setupWebView()
        
        scrollView.bounces = false
        // Since iOS 16, the default value of alwaysBounceX seems to be true
        // for web views.
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false

        scrollView.isPagingEnabled = !isScrollEnabled
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        topConstraint = webView.topAnchor.constraint(equalTo: topAnchor)
        topConstraint.priority = .defaultHigh
        bottomConstraint = webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        bottomConstraint.priority = .defaultHigh
        NSLayoutConstraint.activate([
            topConstraint, bottomConstraint,
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(iOS 11.0, *)
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateContentInset()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateContentInset()
    }
    
    override func loadSpread() {
        guard spread.links.count == 1 else {
            log(.error, "Only one document at a time can be displayed in a reflowable spread")
            return
        }
        let link = spread.leading
        guard let url = link.url(relativeTo: publication.baseURL) else {
            log(.error, "Can't get URL for link \(link.href)")
            return
        }
        webView.load(URLRequest(url: url))
    }

    override func applyUserSettingsStyle() {
        super.applyUserSettingsStyle()
        
        let properties = userSettings.userProperties.properties
        let propertiesScript = properties.reduce("") { script, property in
            let value: String = {
                // Scroll mode depends both on the user settings, and on the fact that VoiceOver is activated or not, so we need to generate the value dynamically.
                // FIXME: This would be handled in a better way by decoupling the user settings from the actual ReadiumCSS properties sent to the WebView, which should be private details of the EPUBNavigator implementation and not shared with the host app.
                if let switchable = property as? Switchable, property.name == ReadiumCSSName.scroll.rawValue {
                    return switchable.values[isScrollEnabled]!
                } else {
                    return property.toString()
                }
            }()
            return script + "readium.setProperty(\"\(property.name)\", \"\(value)\");\n"
        }
        evaluateScript(propertiesScript) { res in
            if case .failure(let error) = res {
                self.log(.error, error)
            }
        }

        // Disables paginated mode if scroll is on.
        scrollView.isPagingEnabled = !isScrollEnabled
        
        updateContentInset()
    }

    private func updateContentInset() {
        if (isScrollEnabled) {
            topConstraint.constant = 0
            bottomConstraint.constant = 0
            scrollView.contentInset = UIEdgeInsets(top: notchAreaInsets.top, left: 0, bottom: notchAreaInsets.bottom, right: 0)
            
        } else {
            var insets = contentInset[traitCollection.verticalSizeClass]
                ?? contentInset[.regular]
                ?? contentInset[.unspecified]
                ?? (top: 0, bottom: 0)
            
            // Increases the insets by the notch area (eg. iPhone X) to make sure that the content is not overlapped by the screen notch.
            insets.top += notchAreaInsets.top
            insets.bottom += notchAreaInsets.bottom
            
            topConstraint.constant = insets.top
            bottomConstraint.constant = -insets.bottom
            scrollView.contentInset = .zero
        }
    }
    
    override func convertPointToNavigatorSpace(_ point: CGPoint) -> CGPoint {
        var point = point
        if isScrollEnabled {
            // Starting from iOS 12, the contentInset are not taken into account in the JS touch event.
            if #available(iOS 12.0, *) {
                if scrollView.contentOffset.x < 0 {
                    point.x += abs(scrollView.contentOffset.x)
                }
                if scrollView.contentOffset.y < 0 {
                    point.y += abs(scrollView.contentOffset.y)
                }
            } else {
                point.x += scrollView.contentInset.left
                point.y += scrollView.contentInset.top
            }
        }
        point.x += webView.frame.minX
        point.y += webView.frame.minY
        return point
    }

    override func convertRectToNavigatorSpace(_ rect: CGRect) -> CGRect {
        var rect = rect
        rect.origin = convertPointToNavigatorSpace(rect.origin)
        return rect
    }

    /// MARK: - Location and progression
    
    override func progression(in href: String) -> Double {
        guard spread.leading.href == href, let progression = progression else {
            return 0
        }
        return progression
    }

    override func spreadDidLoad() {
        if let linkJSON = serializeJSONString(spread.leading.json) {
            evaluateScript("readium.link = \(linkJSON);")
        }

        // FIXME: Better solution for delaying scrolling to pending location
        // This delay is used to wait for the web view pagination to settle and give the CSS and webview time to layout
        // correctly before attempting to scroll to the target progression, otherwise we might end up at the wrong spot.
        // 0.2 seconds seems like a good value for it to work on an iPhone 5s.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let location = self.pendingLocation
            self.go(to: location) {
                // The rendering is sometimes very slow. So in case we don't show the first page of the resource, we add
                // a generous delay before showing the spread again.
                let delayed = !location.isStart
                DispatchQueue.main.asyncAfter(deadline: .now() + (delayed ? 0.3 : 0)) {
                    self.showSpread()
                }
            }
        }
    }
    
    override func go(to direction: EPUBSpreadView.Direction, animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        guard !isScrollEnabled else {
            return super.go(to: direction, animated: animated, completion: completion)
        }
        
        let factor: CGFloat = {
            switch direction {
            case .left:
                return -1
            case .right:
                return 1
            }
        }()

        let offsetX = scrollView.bounds.width * factor
        var newOffset = scrollView.contentOffset
        newOffset.x += offsetX
        let rounded = round(newOffset.x / offsetX) * offsetX
        newOffset.x = rounded
        guard 0..<scrollView.contentSize.width ~= newOffset.x else {
            return false
        }
        
        scrollView.setContentOffset(newOffset, animated: animated)
        
        // This delay is only used when turning pages in a single resource if the page turn is animated. The delay is roughly the length of the animation.
        // FIXME: completion should be implemented using scroll view delegates
        DispatchQueue.main.asyncAfter(
            deadline: .now() + (animated ? 0.3 : 0),
            execute: completion
        )

        return true
    }
    
    // Location to scroll to in the resource once the page is loaded.
    private var pendingLocation: PageLocation = .start

    private let goToCompletions = CompletionList()

    override func go(to location: PageLocation, completion: (() -> Void)?) {
        let completion = goToCompletions.add(completion)

        guard spreadLoaded else {
            // Delays moving to the location until the document is loaded.
            pendingLocation = location
            return
        }

        switch location {
        case .locator(let locator):
            go(to: locator) { _ in completion() }
        case .start:
            go(toProgression: 0) { _ in completion() }
        case .end:
            go(toProgression: 1) { _ in completion() }
        }
    }

    private func go(to locator: Locator, completion: @escaping (Bool) -> Void) {
        guard ["", "#"].contains(locator.href) || spread.contains(href: locator.href) else {
            log(.warning, "The locator's href is not in the spread")
            completion(false)
            return
        }

        if locator.text.highlight != nil {
            go(toText: locator.text, completion: completion)
        // FIXME: find the first fragment matching a tag ID (need a regex)
        } else if let id = locator.locations.fragments.first, !id.isEmpty {
            go(toTagID: id, completion: completion)
        } else {
            let progression = locator.locations.progression ?? 0
            go(toProgression: progression, completion: completion)
        }
    }

    /// Scrolls at given progression (from 0.0 to 1.0)
    private func go(toProgression progression: Double, completion: @escaping (Bool) -> Void) {
        guard progression >= 0 && progression <= 1 else {
            log(.warning, "Scrolling to invalid progression \(progression)")
            completion(false)
            return
        }
        
        // Note: The JS layer does not take into account the scroll view's content inset. So it can't be used to reliably scroll to the top or the bottom of the page in scroll mode.
        if isScrollEnabled && [0, 1].contains(progression) {
            var contentOffset = scrollView.contentOffset
            contentOffset.y = (progression == 0)
                ? -scrollView.contentInset.top
                : (scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom)
            scrollView.contentOffset = contentOffset
            completion(true)
        } else {
            let dir = readingProgression.rawValue
            evaluateScript("readium.scrollToPosition(\'\(progression)\', \'\(dir)\')") { _ in completion(true) }
        }
    }
    
    /// Scrolls at the tag with ID `tagID`.
    private func go(toTagID tagID: String, completion: @escaping (Bool) -> Void) {
        evaluateScript("readium.scrollToId(\'\(tagID)\');") { result in
            switch result {
            case .success(let value):
                completion((value as? Bool) ?? false)
            case .failure(let error):
                self.log(.error, error)
                completion(false)
            }
        }
    }

    /// Scrolls at the snippet matching the given text context.
    private func go(toText text: Locator.Text, completion: @escaping (Bool) -> Void) {
        guard let json = text.jsonString else {
            completion(false)
            return
        }
        evaluateScript("readium.scrollToText(\(json));") { result in
            switch result {
            case .success(let value):
                completion((value as? Bool) ?? false)
            case .failure(let error):
                self.log(.error, error)
                completion(false)
            }
        }
    }


    // MARK: - Progression
    
    // Current progression in the page.
    private var progression: Double?
    // To check if a progression change was cancelled or not.
    private var previousProgression: Double?
    
    // Called by the javascript code to notify that scrolling ended.
    private func progressionDidChange(_ body: Any) {
        guard spreadLoaded, let bodyString = body as? String, var newProgression = Double(bodyString) else {
            return
        }
        newProgression = min(max(newProgression, 0.0), 1.0)
        
        if previousProgression == nil {
            previousProgression = progression
        }
        progression = newProgression
    }
    
    @objc private func notifyPagesDidChange() {
        guard previousProgression != progression else {
            return
        }
        previousProgression = nil
        delegate?.spreadViewPagesDidChange(self)
    }
    
    
    // MARK: - Scripts
    
    override func registerJSMessages() {
        super.registerJSMessages()
        registerJSMessage(named: "progressionChanged") { [weak self] in self?.progressionDidChange($0) }
    }

    // MARK: - WKNavigationDelegate
    
    override func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        super.webView(webView, didFinish: navigation)
        
        // Fixes https://github.com/readium/r2-navigator-swift/issues/141 by disabling the native
        // double-tap gesture.
        // It's an acceptable fix because reflowable resources are not supposed to handle double-tap
        // since there's no zooming capabilities. This doesn't prevent JavaScript to handle
        // double-tap manually.
        webView.removeDoubleTapGestureRecognizer()
    }
    
    
    // MARK: - UIScrollViewDelegate
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        super.scrollViewDidScroll(scrollView)

        // Makes sure we always receive the "ending scroll" event.
        // ie. https://stackoverflow.com/a/1857162/1474476
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(notifyPagesDidChange), object: nil)
        perform(#selector(notifyPagesDidChange), with: nil, afterDelay: 0.3)
    }

}

/// Determines the Readium CSS stylesheets to use depending on the publication languages and
/// reading progression.
// FIXME: To move in a dedicated native Readium CSS module
private enum ReadiumCSSLayout: String {
    case ltr
    case rtl
    case cjkVertical
    case cjkHorizontal
    
    init(languages: [String], readingProgression: ReadingProgression) {
        let isCJK: Bool = {
            guard
                languages.count == 1,
                let language = languages.first?.split(separator: "-").first.map(String.init)?.lowercased()
            else {
                return false
            }
            return ["zh", "ja", "ko"].contains(language)
        }()
        
        switch readingProgression {
        case .rtl, .btt:
            self = isCJK ? .cjkVertical : .rtl
        case .ltr, .ttb, .auto:
            self = isCJK ? .cjkHorizontal : .ltr
        }
    }
    
    var readiumCSSBasePath: String {
        let folder: String = {
            switch self {
            case .ltr:
                return ""
            case .rtl:
                return "rtl/"
            case .cjkVertical:
                return "cjk-vertical/"
            case .cjkHorizontal:
                return "cjk-horizontal/"
            }
        }()
        return "readium-css/\(folder)"
    }
    
    func readiumCSSPath(for name: String) -> String {
        return "\(readiumCSSBasePath)ReadiumCSS-\(name).css"
    }
    
}
