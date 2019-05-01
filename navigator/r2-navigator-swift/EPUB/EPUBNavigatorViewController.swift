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
    
    public weak var delegate: EPUBNavigatorDelegate?
    public var userSettings: UserSettings
    
    private let publication: Publication
    private let license: DRMLicense?
    private let editingActions: EditingActionsController
    /// Content insets used to add some vertical margins around reflowable EPUB publications. The insets can be configured for each size class to allow smaller margins on compact screens.
    private let contentInset: [UIUserInterfaceSizeClass: EPUBContentInsets]
    
    private let triptychView: TriptychView
    private var initialProgression: Double?

    public init(publication: Publication, license: DRMLicense? = nil, initialLocation: Locator? = nil, editingActions: [EditingAction] = EditingAction.defaultActions, contentInset: [UIUserInterfaceSizeClass: EPUBContentInsets]? = nil) {
        self.publication = publication
        self.license = license
        self.editingActions = EditingActionsController(actions: editingActions, license: license)
        self.contentInset = contentInset ?? [
            .compact: (top: 20, bottom: 20),
            .regular: (top: 44, bottom: 44)
        ]

        userSettings = UserSettings()
        publication.userProperties.properties = userSettings.userProperties.properties

        var initialIndex: Int = 0
        if let initialLocation = initialLocation, let foundIndex = publication.readingOrder.firstIndex(withHref: initialLocation.href) {
            initialIndex = foundIndex
            initialProgression = initialLocation.locations?.progression
        }
        
        triptychView = TriptychView(
            frame: CGRect.zero,
            viewCount: publication.readingOrder.count,
            initialIndex: initialIndex,
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
        view.backgroundColor = .clear
        triptychView.backgroundColor = .clear
        triptychView.delegate = self
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
    
    public func go(to locator: Locator, animated: Bool, completion: @escaping () -> Void) -> Bool {
        return false
    }
    
    public func go(to link: Link, animated: Bool, completion: @escaping () -> Void) -> Bool {
        return false
    }
    
    public func goForward(animated: Bool, completion: @escaping () -> Void) -> Bool {
        return false
    }
    
    public func goBackward(animated: Bool, completion: @escaping () -> Void) -> Bool {
        return false
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
        triptychView.performTransition { triptych in
            triptych.moveTo(index: index)
        }
    }
    
    /// Display the readingOrder item at `index` with scroll `progression`
    ///
    /// - Parameter index: The index of the readingOrder item to display.
    public func displayReadingOrderItem(at index: Int, progression: Double) {
        guard publication.readingOrder.indices.contains(index) else {
            return
        }
        
        triptychView.performTransition(animated: true, delayedFadeIn: true) { triptych in
            // This is so the webview will move to it's correct progression if it's not loaded into the triptych view
            self.initialProgression = progression
            triptych.moveTo(index: index)
            if let webView = triptych.currentView as? WebView {
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
        triptychView.performTransition { triptych in
            triptych.moveTo(index: index, id: id)
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

extension EPUBNavigatorViewController: TriptychViewDelegate {

    func triptychView(_ view: TriptychView, viewForIndex index: Int, location: BinaryLocation) -> UIView {
        guard let baseURL = publication.baseURL else {
            return UIView()
        }
        
        let link = publication.readingOrder[index]
        // Check if link is FXL.
        let hasFixedLayout = (publication.metadata.rendition?.layout == .fixed && link.properties.layout == nil) || link.properties.layout == .fixed

        let webViewType = hasFixedLayout ? FixedWebView.self : ReflowableWebView.self
        let webView = webViewType.init(
            baseURL: baseURL,
            initialLocation: location,
            readingProgression: view.readingProgression,
            animatedLoad: false,  // FIXME: custom animated
            editingActions: editingActions,
            contentInset: contentInset
        )

        if let url = publication.url(to: link) {
            webView.viewDelegate = self
            webView.load(url)
            webView.userSettings = userSettings

            // Load last saved regionIndex for the first view.
            if initialProgression != nil {
                webView.progression = initialProgression
                initialProgression = nil
            }
        }
        return webView
    }
    
    func viewsDidUpdate(documentIndex: Int) {
        // notice that you should set the delegate before you load views
        // otherwise, when open the publication, you may miss the first invocation
        notifyCurrentLocation()

        // FIXME: Deprecated, to be removed at some point.
        delegate?.didChangedDocumentPage(currentDocumentIndex: documentIndex)
        if let currentView = triptychView.currentView {
            let cw = currentView as! WebView
            if let pages = cw.totalPages {
                delegate?.didChangedPaginatedDocumentPage(currentPage: cw.currentPage(), documentTotalPage: pages)
            }
        }
    }
    
}


// MARK: - Deprecated

@available(*, deprecated, renamed: "EPUBNavigatorViewController")
public typealias NavigatorViewController = EPUBNavigatorViewController

@available(*, deprecated, message: "Use the `animated` parameter of `goTo` functions instead")
public enum PageTransition {
    case none
    case animated
}

extension EPUBNavigatorViewController {
    
    /// This initializer is deprecated.
    /// Replace `pageTransition` by the `animated` property of the `goTo` functions.
    /// Replace `disableDragAndDrop` by `EditingAction.copy`, since drag and drop is equivalent to copy.
    /// Replace `initialIndex` and `initialProgression` by `initialLocation`.
    @available(*, deprecated, renamed: "init(publication:license:initialLocation:editingActions:contentInset:)")
    public convenience init(for publication: Publication, license: DRMLicense? = nil, initialIndex: Int, initialProgression: Double?, pageTransition: PageTransition = .none, disableDragAndDrop: Bool = false, editingActions: [EditingAction] = EditingAction.defaultActions, contentInset: [UIUserInterfaceSizeClass: EPUBContentInsets]? = nil) {
        var initialIndex = initialIndex
        if initialIndex == -1 {
            initialIndex = publication.readingOrder.count
        }
        if !publication.readingOrder.indices.contains(initialIndex) {
            initialIndex = 0
        }
        let initialLocation = publication.readingOrder[initialIndex].locator
        
        self.init(publication: publication, license: license, initialLocation: initialLocation, editingActions: editingActions, contentInset: contentInset)
    }
    
    @available(*, deprecated, message: "Use the `animated` parameter of `goTo` functions instead")
    public var pageTransition: PageTransition {
        get { return .none }
        set {}
    }
    
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
