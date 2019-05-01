//
//  EPUBNavigatorViewController.swift
//  r2-navigator-swift
//
//  Created by Winnie Quinn, Alexandre Camilleri on 8/23/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import UIKit
import R2Shared
import WebKit
import SafariServices


public protocol EPUBNavigatorDelegate: NavigatorDelegate {
    
    // MARK: - Deprecated
    
    // Implement `NavigatorDelegate.navigator(didTapAt:)` instead.
    func middleTapHandler()

    // Implement `NavigatorDelegate.navigator(locationDidChange:)` instead, to save the last read location.
    func willExitPublication(documentIndex: Int, progression: Double?)
    func didChangedDocumentPage(currentDocumentIndex: Int)
    func didChangedPaginatedDocumentPage(currentPage: Int, documentTotalPage: Int)
    func didNavigateViaInternalLinkTap(to documentIndex: Int)

    /// Implement `NavigatorDelegate.navigator(presentError:)` instead.
    func presentError(_ error: NavigatorError)
    
    // Implement `NavigatorDelegate.navigator(presentExternalURL:)` instead.
    func didTapExternalUrl(_ : URL)

}

public extension EPUBNavigatorDelegate {
    
    func middleTapHandler() {}
    func willExitPublication(documentIndex: Int, progression: Double?) {}
    func didChangedDocumentPage(currentDocumentIndex: Int) {}
    func didChangedPaginatedDocumentPage(currentPage: Int, documentTotalPage: Int) {}
    func didNavigateViaInternalLinkTap(to documentIndex: Int) {}
    func presentError(_ error: NavigatorError) {}
    func didTapExternalUrl(_ url: URL) {
        UIApplication.shared.openURL(url)
    }

}


public typealias EPUBContentInsets = (top: CGFloat, bottom: CGFloat)

open class EPUBNavigatorViewController: UIViewController, Navigator {
    
    private let delegatee: Delegatee!
    fileprivate let triptychView: TriptychView
    public var userSettings: UserSettings
    fileprivate var initialProgression: Double?
    //
    public let publication: Publication
    public let license: DRMLicense?
    public weak var delegate: EPUBNavigatorDelegate?

    public let pageTransition: PageTransition
    public let disableDragAndDrop: Bool

    fileprivate let editingActions: EditingActionsController

    /// Content insets used to add some vertical margins around reflowable EPUB publications. The insets can be configured for each size class to allow smaller margins on compact screens.
    public let contentInset: [UIUserInterfaceSizeClass: EPUBContentInsets]

    /// - Parameters:
    ///   - publication: The publication.
    ///   - initialIndex: Inital index of -1 will open the publication's at the end.
    public init(for publication: Publication, license: DRMLicense? = nil, initialIndex: Int, initialProgression: Double?, pageTransition: PageTransition = .none, disableDragAndDrop: Bool = false, editingActions: [EditingAction] = EditingAction.defaultActions, contentInset: [UIUserInterfaceSizeClass: EPUBContentInsets]? = nil) {
        self.publication = publication
        self.license = license
        self.initialProgression = initialProgression
        self.pageTransition = pageTransition
        self.disableDragAndDrop = disableDragAndDrop
        self.contentInset = contentInset ?? [
            .compact: (top: 20, bottom: 20),
            .regular: (top: 44, bottom: 44)
        ]
      
        self.editingActions = EditingActionsController(actions: editingActions, license: license)

        userSettings = UserSettings()
        publication.userProperties.properties = userSettings.userProperties.properties
        delegatee = Delegatee()
        var index = initialIndex

        if initialIndex == -1 {
            index = publication.readingOrder.count
        }
        
        triptychView = TriptychView(
            frame: CGRect.zero,
            viewCount: publication.readingOrder.count,
            initialIndex: index,
            readingProgression: publication.contentLayout.readingProgression
        )
        
        super.init(nibName: nil, bundle: nil)
        
        self.editingActions.delegate = self
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        delegatee.parent = self
        view.backgroundColor = .clear
        triptychView.backgroundColor = .clear
        triptychView.delegate = delegatee
        triptychView.frame = view.bounds
        triptychView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        view.addSubview(triptychView)
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // FIXME: Deprecated, to be removed at some point.
        delegate?.willExitPublication(documentIndex: triptychView.index, progression: triptychView.currentDocumentProgression)
    }
    
    /// Mapping between reading order hrefs and the table of contents title.
    lazy var tableOfContentsTitleByHref: [String: String] = {
        func fulfill(linkList: [Link]) -> [String: String] {
            var result = [String: String]()
            
            for link in linkList {
                if let title = link.title {
                    result[link.href] = title
                }
                let subResult = fulfill(linkList: link.children)
                result.merge(subResult) { (current, another) -> String in
                    return current
                }
            }
            return result
        }
        
        return fulfill(linkList: publication.tableOfContents)
    }()

    
    // MARK: - Navigator
    
    public var readingProgression: ReadingProgression {
        return publication.contentLayout.readingProgression
    }
    
    public var currentLocation: Locator? {
        let resource = publication.readingOrder[triptychView.index]
        return Locator(
            href: resource.href,
            type: resource.type ?? "text/html",
            title: tableOfContentsTitleByHref[resource.href],
            locations: Locations(
                progression: triptychView.currentDocumentProgression ?? 0
            )
        )
    }

    /// Last current location notified to the delegate.
    /// Used to avoid sending twice the same location.
    private var notifiedCurrentLocation: Locator?
    
    fileprivate func notifyCurrentLocation() {
        guard let delegate = delegate,
            let location = currentLocation,
            location != notifiedCurrentLocation else
        {
            return
        }
        notifiedCurrentLocation = location
        delegate.navigator(self, locationDidChange: location)
    }
    
}

extension EPUBNavigatorViewController {

    /// Display the readingOrder item at `index`.
    ///
    /// - Parameter index: The index of the readingOrder item to display.
    public func displayReadingOrderItem(at index: Int) {
        guard publication.readingOrder.indices.contains(index) else {
            return
        }
        performTriptychViewTransition {
            self.triptychView.moveTo(index: index)
        }
    }
    
    /// Display the readingOrder item at `index` with scroll `progression`
    ///
    /// - Parameter index: The index of the readingOrder item to display.
    public func displayReadingOrderItem(at index: Int, progression: Double) {
        guard publication.readingOrder.indices.contains(index) else {
            return
        }
        
        performTriptychViewTransitionDelayed {
            // This is so the webview will move to it's correct progression if it's not loaded into the triptych view
            self.initialProgression = progression
            self.triptychView.moveTo(index: index)
            if let webView = self.triptychView.currentView as? WebView {
                // This is needed for when the webView is loaded into the triptychView
                webView.scrollAt(position: progression)
            }
        }
    }
    
    /// Load resource with the corresponding href.
    ///
    /// - Parameter href: The href of the resource to load. Can contain a tag id.
    /// - Returns: The readingOrder index for the link
    public func displayReadingOrderItem(with href: String) -> Int? {
        // remove id if any
        let components = href.components(separatedBy: "#")
        guard let href = components.first else {
            return nil
        }
        guard let index = publication.readingOrder.index(where: { $0.href.contains(href) }) else {
            return nil
        }
        // If any id found, set the scroll position to it, else to the
        // beggining of the document.
        let id = (components.count > 1 ? components.last : "")

        // Jumping set to true to avoid clamping.
        performTriptychViewTransition {
            self.triptychView.moveTo(index: index, id: id)
        }
        return index
    }

    public func updateUserSettingStyle() {
        guard let views = triptychView.views?.array else {
            return
        }
        for view in views {
            let webview = view as? WebView

            webview?.applyUserSettingsStyle()
        }
    }
}

extension EPUBNavigatorViewController: WebViewDelegate {
    
    func willAnimatePageChange() {
        triptychView.isUserInteractionEnabled = false
    }
    
    func didEndPageAnimation() {
        triptychView.isUserInteractionEnabled = true
    }
    
    func handleTapOnLink(with url: URL) {
        delegate?.navigator(self, presentExternalURL: url)
        // FIXME: Deprecated, to be removed at some point.
        delegate?.didTapExternalUrl(url)
    }
    
    func handleTapOnInternalLink(with href: String) {
        guard let index = displayReadingOrderItem(with: href) else { return }
        
        // FIXME: Deprecated, to be removed at some point.
        delegate?.didNavigateViaInternalLinkTap(to: index)
    }
    
    func documentPageDidChange(webView: WebView, currentPage: Int, totalPage: Int) {
        if triptychView.currentView == webView {
            notifyCurrentLocation()

            // FIXME: Deprecated, to be removed at some point.
            delegate?.didChangedPaginatedDocumentPage(currentPage: currentPage, documentTotalPage: totalPage)
        }
    }
    
    /// Display next document (readingOrder item).
    func displayRightDocument() {
        let delta = triptychView.readingProgression == .rtl ? -1:1
        self.displayReadingOrderItem(at: self.triptychView.index + delta)
    }

    /// Display previous document (readingOrder item).
    func displayLeftDocument() {
        let delta = triptychView.readingProgression == .rtl ? -1:1
        self.displayReadingOrderItem(at: self.triptychView.index - delta)
    }

    func publicationBaseUrl() -> URL? {
        return publication.baseURL
    }

    internal func handleCenterTap() {
        // FIXME: Real point
        delegate?.navigator(self, didTapAt: view.center)
        
        // FIXME: Deprecated, to be removed at some point.
        delegate?.middleTapHandler()
    }

}

extension EPUBNavigatorViewController: EditingActionsControllerDelegate {
    
    func editingActionsDidPreventCopy(_ editingActions: EditingActionsController) {
        delegate?.navigator(self, presentError: .copyForbidden)
        // FIXME: Deprecated, to be removed at some point.
        delegate?.presentError(.copyForbidden)
    }
    
}

/// Used to hide conformance to package-private delegate protocols.
private final class Delegatee: NSObject {
    weak var parent: EPUBNavigatorViewController!
    fileprivate var firstView = true
}

extension Delegatee: TriptychViewDelegate {

    public func triptychView(_ view: TriptychView, viewForIndex index: Int, location: BinaryLocation) -> UIView {
        guard let baseURL = parent.publication.baseURL else {
            return UIView()
        }
        
        let link = parent.publication.readingOrder[index]
        // Check if link is FXL.
        let hasFixedLayout = (parent.publication.metadata.rendition?.layout == .fixed && link.properties.layout == nil) || link.properties.layout == .fixed

        let webViewType = hasFixedLayout ? FixedWebView.self : ReflowableWebView.self
        let webView = webViewType.init(
            baseURL: baseURL,
            initialLocation: location,
            readingProgression: view.readingProgression,
            pageTransition: parent.pageTransition,
            disableDragAndDrop: parent.disableDragAndDrop,
            editingActions: parent.editingActions,
            contentInset: parent.contentInset
        )

        if let url = parent.publication.url(to: link) {
            webView.viewDelegate = parent
            webView.load(url)
            webView.userSettings = parent.userSettings

            // Load last saved regionIndex for the first view.
            if parent.initialProgression != nil {
                webView.progression = parent.initialProgression
                parent.initialProgression = nil
            }
        }
        return webView
    }
    
    func viewsDidUpdate(documentIndex: Int) {
        // notice that you should set the delegate before you load views
        // otherwise, when open the publication, you may miss the first invocation
        parent.notifyCurrentLocation()

        // FIXME: Deprecated, to be removed at some point.
        parent.delegate?.didChangedDocumentPage(currentDocumentIndex: documentIndex)
        if let currentView = parent.triptychView.currentView {
            let cw = currentView as! WebView
            if let pages = cw.totalPages {
                parent.delegate?.didChangedPaginatedDocumentPage(currentPage: cw.currentPage(), documentTotalPage: pages)
            }
        }
    }
}


extension EPUBNavigatorViewController {
    
    public var contentView: UIView {
        return triptychView
    }
    
    func performTriptychViewTransition(commitTransition: @escaping () -> ()) {
        switch pageTransition {
        case .none:
            commitTransition()
        case .animated:
            fadeTriptychView(alpha: 0) {
                commitTransition()
                self.fadeTriptychView(alpha: 1, completion: { })
            }
        }
    }
    
    /*
     This is used when we want to jump to a document with proression. The rendering is sometimes very slow in this case so we have a generous delay before we show the view again.
     */
    func performTriptychViewTransitionDelayed(commitTransition: @escaping () -> ()) {
        switch pageTransition {
        case .none:
            commitTransition()
        case .animated:
            fadeTriptychView(alpha: 0) {
                commitTransition()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                    self.fadeTriptychView(alpha: 1, completion: { })
                })
            }
        }
    }
    
    private func fadeTriptychView(alpha: CGFloat, completion: @escaping () -> ()) {
        UIView.animate(withDuration: 0.15, animations: {
            self.triptychView.alpha = alpha
        }) { _ in
            completion()
        }
    }
}


// MARK: - Deprecated

@available(*, deprecated, renamed: "EPUBNavigatorViewController")
public typealias NavigatorViewController = EPUBNavigatorViewController

extension EPUBNavigatorViewController {
    
    @available(*, deprecated, message: "Bookmark model is deprecated, use your own model and `currentLocation`")
    public var currentPosition: Bookmark? {
        guard let publicationID = publication.metadata.identifier,
            let locator = currentLocation else
        {
            return nil
        }
        return Bookmark(
            publicationID: publicationID,
            resourceIndex: triptychView.index,
            locator: locator
        )
    }
    
    @available(*, deprecated, message: "Use `publication.readingOrder` instead")
    public func getReadingOrder() -> [Link] { return publication.readingOrder }
    
    @available(*, deprecated, message: "Use `publication.tableOfContents` instead")
    public func getTableOfContents() -> [Link] { return publication.tableOfContents }

}
