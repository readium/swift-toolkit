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


public protocol EPUBNavigatorDelegate: VisualNavigatorDelegate {
    
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

}

public extension EPUBNavigatorDelegate {
    
    func middleTapHandler() {}
    func willExitPublication(documentIndex: Int, progression: Double?) {}
    func didChangedDocumentPage(currentDocumentIndex: Int) {}
    func didChangedPaginatedDocumentPage(currentPage: Int, documentTotalPage: Int) {}
    func didNavigateViaInternalLinkTap(to documentIndex: Int) {}
    func presentError(_ error: NavigatorError) {}

}


public typealias EPUBContentInsets = (top: CGFloat, bottom: CGFloat)

open class EPUBNavigatorViewController: UIViewController, VisualNavigator, Loggable {
    
    public weak var delegate: EPUBNavigatorDelegate?
    public var userSettings: UserSettings
    
    private let publication: Publication
    private let license: DRMLicense?
    private let editingActions: EditingActionsController
    /// Content insets used to add some vertical margins around reflowable EPUB publications. The insets can be configured for each size class to allow smaller margins on compact screens.
    private let contentInset: [UIUserInterfaceSizeClass: EPUBContentInsets]
    
    private let triptychView: TriptychView
    
    /// Index of the currently visible reading order resource.
    private var currentResourceIndex: Int {
        return triptychView.currentIndex
    }

    /// Base URL on the resources server to the files in Static/
    /// Used to serve the ReadiumCSS files.
    private let resourcesURL: URL?

    public init(publication: Publication, license: DRMLicense? = nil, initialLocation locator: Locator? = nil, editingActions: [EditingAction] = EditingAction.defaultActions, contentInset: [UIUserInterfaceSizeClass: EPUBContentInsets]? = nil, resourcesServer: ResourcesServer) {
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
        var initialLocation: Locations = Locations(progression: 0)
        if let locator = locator, let foundIndex = publication.readingOrder.firstIndex(withHref: locator.href) {
            initialIndex = foundIndex
            if let locations = locator.locations {
                initialLocation = locations
            }
        }
        
        triptychView = TriptychView(
            frame: CGRect.zero,
            resourcesCount: publication.readingOrder.count,
            initialIndex: initialIndex,
            initialLocation: initialLocation,
            readingProgression: publication.contentLayout.readingProgression
        )
        
        resourcesURL = {
            do {
                guard let baseURL = Bundle(for: EPUBNavigatorViewController.self).resourceURL else {
                    return nil
                }
                return try resourcesServer.serve(
                   baseURL.appendingPathComponent("Static"),
                    at: "/r2-navigator/epub"
                )
            } catch {
                EPUBNavigatorViewController.log(.error, error)
                return nil
            }
        }()
        
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
        let progression = (triptychView.currentView as? DocumentWebView)?.progression
        delegate?.willExitPublication(documentIndex: currentResourceIndex, progression: progression)
    }

    /// Mapping between reading order hrefs and the table of contents title.
    private lazy var tableOfContentsTitleByHref: [String: String] = {
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
    
    /// Goes to the reading order resource at given `index`, and given content location.
    @discardableResult
    private func goToIndex(_ index: Int, location: Locations? = nil, animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        return triptychView.goToIndex(index, location: location, animated: animated, completion: completion)
    }
    
    /// Goes to the next or previous page in the given scroll direction.
    private func go(to direction: DocumentWebView.Direction, animated: Bool, completion: @escaping () -> Void) -> Bool {
        guard let webView = triptychView.currentView as? DocumentWebView else {
            return false
        }
        return webView.go(to: direction, animated: animated, completion: completion)
    }
    
    public func updateUserSettingStyle() {
        assert(Thread.isMainThread, "User settings must be updated from the main thread")
        
        guard !triptychView.isEmpty else {
            return
        }
        
        let location = currentLocation
        for (_, view) in triptychView.loadedViews {
            (view as? DocumentWebView)?.applyUserSettingsStyle()
        }
        
        // Re-positions the navigator to the location before applying the settings
        if let location = location {
            go(to: location)
        }
    }

    
    // MARK: - Navigator
    
    public var readingProgression: ReadingProgression {
        return publication.contentLayout.readingProgression
    }
    
    public var currentLocation: Locator? {
        let resource = publication.readingOrder[currentResourceIndex]
        return Locator(
            href: resource.href,
            type: resource.type ?? "text/html",
            title: tableOfContentsTitleByHref[resource.href],
            locations: Locations(
                progression: (triptychView.currentView as? DocumentWebView)?.progression ?? 0
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
        guard let index = publication.readingOrder.firstIndex(withHref: locator.href) else {
            return false
        }
        
        return goToIndex(index, location: locator.locations, animated: animated, completion: completion)
    }
    
    public func go(to link: Link, animated: Bool, completion: @escaping () -> Void) -> Bool {
        return go(to: Locator(link: link), animated: animated, completion: completion)
    }
    
    public func goForward(animated: Bool, completion: @escaping () -> Void) -> Bool {
        let direction: DocumentWebView.Direction = {
            switch readingProgression {
            case .ltr, .auto:
                return .right
            case .rtl:
                return .left
            }
        }()
        return go(to: direction, animated: animated, completion: completion)
    }
    
    public func goBackward(animated: Bool, completion: @escaping () -> Void) -> Bool {
        let direction: DocumentWebView.Direction = {
            switch readingProgression {
            case .ltr, .auto:
                return .left
            case .rtl:
                return .right
            }
        }()
        return go(to: direction, animated: animated, completion: completion)
    }
    
}

extension EPUBNavigatorViewController: DocumentWebViewDelegate {
    
    func willAnimatePageChange() {
        triptychView.isUserInteractionEnabled = false
    }
    
    func didEndPageAnimation() {
        triptychView.isUserInteractionEnabled = true
    }
    
    func webView(_ webView: DocumentWebView, didTapAt point: CGPoint) {
        let point = view.convert(point, from: webView)
        delegate?.navigator(self, didTapAt: point)
        // FIXME: Deprecated, to be removed at some point.
        delegate?.middleTapHandler()
        
        // Uncomment to debug the coordinates of the tap point.
//        let tapView = UIView(frame: .init(x: 0, y: 0, width: 50, height: 50))
//        view.addSubview(tapView)
//        tapView.backgroundColor = .red
//        tapView.center = point
//        tapView.layer.cornerRadius = 25
//        tapView.layer.masksToBounds = true
//        UIView.animate(withDuration: 0.8, animations: {
//            tapView.alpha = 0
//        }) { _ in
//            tapView.removeFromSuperview()
//        }
    }
    
    func handleTapOnLink(with url: URL) {
        delegate?.navigator(self, presentExternalURL: url)
    }
    
    func handleTapOnInternalLink(with href: String) {
        go(to: Link(href: href))
    }
    
    func documentPageDidChange(webView: DocumentWebView, currentPage: Int, totalPage: Int) {
        if triptychView.currentView == webView {
            notifyCurrentLocation()

            // FIXME: Deprecated, to be removed at some point.
            delegate?.didChangedPaginatedDocumentPage(currentPage: currentPage, documentTotalPage: totalPage)
        }
    }
    
    /// Display next document (readingOrder item).
    @discardableResult
    func displayRightDocument(animated: Bool, completion: @escaping () -> Void) -> Bool {
        let delta = triptychView.readingProgression == .rtl ? -1 : 1
        return goToIndex(currentResourceIndex + delta, animated: animated, completion: completion)
    }

    /// Display previous document (readingOrder item).
    @discardableResult
    func displayLeftDocument(animated: Bool, completion: @escaping () -> Void) -> Bool {
        let delta = triptychView.readingProgression == .rtl ? -1 : 1
        return goToIndex(currentResourceIndex - delta, animated: animated, completion: completion)
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

    func triptychView(_ triptychView: TriptychView, viewForIndex index: Int, location: Locations) -> (UIView & TriptychResourceView)? {
        guard let baseURL = publication.baseURL else {
            return nil
        }
        
        let link = publication.readingOrder[index]
        // Check if link is FXL.
        let hasFixedLayout = (publication.metadata.rendition?.layout == .fixed && link.properties.layout == nil) || link.properties.layout == .fixed

        let webViewType = hasFixedLayout ? FixedDocumentWebView.self : ReflowableDocumentWebView.self
        let webView = webViewType.init(
            baseURL: baseURL,
            resourcesURL: resourcesURL,
            initialLocation: location,
            contentLayout: publication.contentLayout,
            readingProgression: triptychView.readingProgression,
            animatedLoad: false,  // FIXME: custom animated
            editingActions: editingActions,
            contentInset: contentInset
        )

        if let url = publication.url(to: link) {
            webView.viewDelegate = self
            webView.load(url)
            webView.userSettings = userSettings
        }
        return webView
    }
    
    func triptychViewDidUpdateViews(_ triptychView: TriptychView) {
        // notice that you should set the delegate before you load views
        // otherwise, when open the publication, you may miss the first invocation
        notifyCurrentLocation()

        // FIXME: Deprecated, to be removed at some point.
        delegate?.didChangedDocumentPage(currentDocumentIndex: currentResourceIndex)
        if let currentView = triptychView.currentView as? DocumentWebView, let pages = currentView.totalPages {
            delegate?.didChangedPaginatedDocumentPage(currentPage: currentView.currentPage, documentTotalPage: pages)
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
        fatalError("This initializer is not available anymore.")
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
            resourceIndex: currentResourceIndex,
            locator: locator
        )
    }

    @available(*, deprecated, message: "Use `publication.readingOrder` instead")
    public func getReadingOrder() -> [Link] { return publication.readingOrder }
    
    @available(*, deprecated, message: "Use `publication.tableOfContents` instead")
    public func getTableOfContents() -> [Link] { return publication.tableOfContents }

    @available(*, deprecated, renamed: "go(to:)")
    public func displayReadingOrderItem(at index: Int) {
        goToIndex(index)
    }
    
    @available(*, deprecated, renamed: "go(to:)")
    public func displayReadingOrderItem(at index: Int, progression: Double) {
        goToIndex(index, location: Locations(progression: progression))
    }
    
    @available(*, deprecated, renamed: "go(to:)")
    public func displayReadingOrderItem(with href: String) -> Int? {
        let index = publication.readingOrder.firstIndex(withHref: href)
        let moved = go(to: Link(href: href))
        return moved ? index : nil
    }
    
}
