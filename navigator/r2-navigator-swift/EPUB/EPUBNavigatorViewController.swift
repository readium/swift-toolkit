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
import SwiftSoup


public protocol EPUBNavigatorDelegate: VisualNavigatorDelegate {
    
    // MARK: - Deprecated
    
    // Implement `NavigatorDelegate.navigator(didTapAt:)` instead.
    func middleTapHandler()

    // Implement `NavigatorDelegate.navigator(locationDidChange:)` instead, to save the last read location.
    func willExitPublication(documentIndex: Int, progression: Double?)
    func didChangedDocumentPage(currentDocumentIndex: Int)
    func didNavigateViaInternalLinkTap(to documentIndex: Int)

    /// Implement `NavigatorDelegate.navigator(presentError:)` instead.
    func presentError(_ error: NavigatorError)

}

public extension EPUBNavigatorDelegate {
    
    func middleTapHandler() {}
    func willExitPublication(documentIndex: Int, progression: Double?) {}
    func didChangedDocumentPage(currentDocumentIndex: Int) {}
    func didNavigateViaInternalLinkTap(to documentIndex: Int) {}
    func presentError(_ error: NavigatorError) {}

}


public typealias EPUBContentInsets = (top: CGFloat, bottom: CGFloat)

open class EPUBNavigatorViewController: UIViewController, VisualNavigator, Loggable {
    
    public struct Configuration {
        /// Authorized actions to be displayed in the selection menu.
        public var editingActions: [EditingAction] = EditingAction.defaultActions
        
        /// Content insets used to add some vertical margins around reflowable EPUB publications. The insets can be configured for each size class to allow smaller margins on compact screens.
        public var contentInset: [UIUserInterfaceSizeClass: EPUBContentInsets] = [
            .compact: (top: 20, bottom: 20),
            .regular: (top: 44, bottom: 44)
        ]
        
        /// Number of positions (as in `Publication.positionList`) to preload before the current page.
        public var preloadPreviousPositionCount = 2
        
        /// Number of positions (as in `Publication.positionList`) to preload after the current page.
        public var preloadNextPositionCount = 6
        
        public init() {}
    }
    
    public weak var delegate: EPUBNavigatorDelegate? {
        didSet { notifyCurrentLocation() }
    }
    public var userSettings: UserSettings
    
    private let config: Configuration
    private let publication: Publication
    private let license: DRMLicense?
    private let editingActions: EditingActionsController

    public var readingProgression: ReadingProgression {
        didSet { reloadSpreads() }
    }

    /// Base URL on the resources server to the files in Static/
    /// Used to serve Readium CSS.
    private let resourcesURL: URL?

    public init(publication: Publication, license: DRMLicense? = nil, initialLocation: Locator? = nil, resourcesServer: ResourcesServer, config: Configuration = .init()) {
        self.publication = publication
        self.license = license
        self.editingActions = EditingActionsController(actions: config.editingActions, license: license)
        self.userSettings = UserSettings()
        publication.userProperties.properties = self.userSettings.userProperties.properties
        self.readingProgression = publication.contentLayout.readingProgression
        self.config = config
        self.paginationView = PaginationView(frame: .zero, preloadPreviousPositionCount: config.preloadPreviousPositionCount, preloadNextPositionCount: config.preloadNextPositionCount)

        self.resourcesURL = {
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
        self.paginationView.delegate = self
        reloadSpreads(at: initialLocation)
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        paginationView.backgroundColor = .clear
        paginationView.frame = view.bounds
        paginationView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        view.addSubview(paginationView)
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // FIXME: Deprecated, to be removed at some point.
        if let currentResourceIndex = currentResourceIndex {
            let progression = currentLocation?.locations.progression
            delegate?.willExitPublication(documentIndex: currentResourceIndex, progression: progression)
        }
    }
    
    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { [weak self] context in
            self?.reloadSpreads()
        })
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
    private func goToReadingOrderIndex(_ index: Int, location: Locator? = nil, animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        let href = publication.readingOrder[index].href
        guard let spreadIndex = spreads.firstIndex(withHref: href) else {
            return false
        }
        return paginationView.goToIndex(spreadIndex, location: PageLocation(location), animated: animated, completion: completion)
    }
    
    /// Goes to the next or previous page in the given scroll direction.
    private func go(to direction: EPUBSpreadView.Direction, animated: Bool, completion: @escaping () -> Void) -> Bool {
        if let spreadView = paginationView.currentView as? EPUBSpreadView,
            spreadView.go(to: direction, animated: animated, completion: completion)
        {
            return true
        }
        
        let isRTL = (readingProgression == .rtl)
        let delta = isRTL ? -1 : 1
        switch direction {
        case .left:
            let location: PageLocation = isRTL ? .start : .end
            return paginationView.goToIndex(currentSpreadIndex - delta, location: location, animated: animated, completion: completion)
        case .right:
            let location: PageLocation = isRTL ? .end : .start
            return paginationView.goToIndex(currentSpreadIndex + delta, location: location, animated: animated, completion: completion)
        }
    }
    
    
    // MARK: - User settings
    
    public func updateUserSettingStyle() {
        assert(Thread.isMainThread, "User settings must be updated from the main thread")
        
        guard !paginationView.isEmpty else {
            return
        }
        
        reloadSpreads()
        
        let location = currentLocation
        for (_, view) in paginationView.loadedViews {
            (view as? EPUBSpreadView)?.applyUserSettingsStyle()
        }
        
        // Re-positions the navigator to the location before applying the settings
        if let location = location {
            go(to: location)
        }
    }

    
    // MARK: - Pagination and spreads
    
    private let paginationView: PaginationView
    private var spreads: [EPUBSpread] = []

    /// Index of the currently visible spread.
    private var currentSpreadIndex: Int {
        return paginationView.currentIndex
    }

    // Reading order index of the left-most resource in the visible spread.
    private var currentResourceIndex: Int? {
        return publication.readingOrder.firstIndex(withHref: spreads[currentSpreadIndex].left.href)
    }

    private func reloadSpreads(at locator: Locator? = nil) {
        let isLandscape = (view.bounds.width > view.bounds.height)
        let pageCountPerSpread = EPUBSpread.pageCountPerSpread(for: publication, userSettings: userSettings, isLandscape: isLandscape)
        guard spreads.first?.pageCount != pageCountPerSpread else {
            // Already loaded with the expected amount of spreads.
            return
        }

        let locator = locator ?? currentLocation
        spreads = EPUBSpread.makeSpreads(for: publication, readingProgression: readingProgression, pageCountPerSpread: pageCountPerSpread)
        
        let initialIndex: Int = {
            if let href = locator?.href, let foundIndex = spreads.firstIndex(withHref: href) {
                return foundIndex
            } else {
                return 0
            }
        }()
        
        paginationView.reloadAtIndex(initialIndex, location: PageLocation(locator), pageCount: spreads.count, readingProgression: readingProgression)
    }

    
    // MARK: - Navigator
    
    public var currentLocation: Locator? {
        guard let spreadView = paginationView.currentView as? EPUBSpreadView else {
            return nil
        }
        
        let link = spreadView.spread.leading
        let href = link.href
        let progression = spreadView.progression(in: href)
        
        // The positions are not always available, for example a Readium WebPub doesn't have any
        // unless a Publication Positions Web Service is provided.
        if
            let positionList = publication.positionsByResource[href],
            positionList.count > 0
        {
            // Gets the current locator from the positionList, and fill its missing data.
            let positionIndex = Int(ceil(progression * Double(positionList.count - 1)))
            return positionList[positionIndex].copy(
                title: tableOfContentsTitleByHref[href],
                locations: { $0.progression = progression }
            )
        } else {
            return Locator(link: link).copy(
                locations: { $0.progression = progression }
            )
        }
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
        guard let spreadIndex = spreads.firstIndex(withHref: locator.href) else {
            return false
        }
        return paginationView.goToIndex(spreadIndex, location: .locator(locator), animated: animated, completion: completion)
    }
    
    public func go(to link: Link, animated: Bool, completion: @escaping () -> Void) -> Bool {
        return go(to: Locator(link: link), animated: animated, completion: completion)
    }
    
    public func goForward(animated: Bool, completion: @escaping () -> Void) -> Bool {
        let direction: EPUBSpreadView.Direction = {
            switch readingProgression {
            case .ltr, .ttb, .auto:
                return .right
            case .rtl, .btt:
                return .left
            }
        }()
        return go(to: direction, animated: animated, completion: completion)
    }
    
    public func goBackward(animated: Bool, completion: @escaping () -> Void) -> Bool {
        let direction: EPUBSpreadView.Direction = {
            switch readingProgression {
            case .ltr, .ttb, .auto:
                return .left
            case .rtl, .btt:
                return .right
            }
        }()
        return go(to: direction, animated: animated, completion: completion)
    }
    
}

extension EPUBNavigatorViewController: EPUBSpreadViewDelegate {
    
    func spreadViewWillAnimate(_ spreadView: EPUBSpreadView) {
        paginationView.isUserInteractionEnabled = false
    }
    
    func spreadViewDidAnimate(_ spreadView: EPUBSpreadView) {
        paginationView.isUserInteractionEnabled = true
    }
    
    func spreadView(_ spreadView: EPUBSpreadView, didTapAt point: CGPoint) {
        let point = view.convert(point, from: spreadView)
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
    
    func spreadView(_ spreadView: EPUBSpreadView, didTapOnExternalURL url: URL) {
        delegate?.navigator(self, presentExternalURL: url)
    }
    
    func spreadView(_ spreadView: EPUBSpreadView, didTapOnInternalLink href: String, tapData: TapData?) {
        
        // Check to see if this was a noteref link and give delegate the opportunity to display it.
        if
            let tapData = tapData,
            let interactive = tapData.interactiveElement,
            let (note, referrer) = getNoteData(anchor: interactive, href: href),
            let delegate = self.delegate
        {
            if !delegate.navigator(
                self,
                shouldNavigateToNoteAt: Link(href: href, type: "text/html"),
                content: note,
                referrer: referrer
            ) {
                return
            }
        }
            
        go(to: Link(href: href))
    }
    
    /// Checks if the internal link is a noteref, and retrieves both the referring text of the link and the body of the note.
    ///
    /// Uses the navigation href from didTapOnInternalLink because it is normalized to a path within the book,
    /// whereas the anchor tag may have just a hash fragment like `#abc123` which is hard to work with.
    /// We do at least validate to ensure that the two hrefs match.
    ///
    /// Uses `#id` when retrieving the body of the note, not `aside#id` because it may be a `<section>`.
    /// See https://idpf.github.io/epub-vocabs/structure/#footnotes
    /// and http://kb.daisy.org/publishing/docs/html/epub-type.html#ex
    func getNoteData(anchor: String, href: String) -> (String, String)? {
        do {
            let doc = try parse(anchor)
            guard let link = try doc.select("a[epub:type=noteref]").first() else { return nil }
            
            let anchorHref = try link.attr("href")
            guard href.hasSuffix(anchorHref) else { return nil}
            
            let hashParts = href.split(separator: "#")
            guard hashParts.count == 2 else {
                log(.error, "Could not find hash in link \(href)")
                return nil
            }
            let id = String(hashParts[1])
            var withoutFragment = String(hashParts[0])
            if withoutFragment.hasPrefix("/") {
                withoutFragment = String(withoutFragment.dropFirst())
            }
            
            guard let base = publication.baseURL else {
                log(.error, "Couldn't get publication base URL")
                return nil
            }
            
            let absolute = base.appendingPathComponent(withoutFragment)
            
            log(.debug, "Fetching note contents from \(absolute.absoluteString)")
            let contents = try String(contentsOf: absolute)
            let document = try parse(contents)
            
            guard let aside = try document.select("#\(id)").first() else {
                log(.error, "Could not find the element '#\(id)' in document \(absolute)")
                return nil
            }
            
            return (try aside.html(), try link.html())
            
        } catch {
            log(.error, "Caught error while getting note content: \(error)")
            return nil
        }
    }
    
    func spreadViewPagesDidChange(_ spreadView: EPUBSpreadView) {
        if paginationView.currentView == spreadView {
            notifyCurrentLocation()
        }
    }
    
    func spreadView(_ spreadView: EPUBSpreadView, present viewController: UIViewController) {
        present(viewController, animated: true)
    }

}

extension EPUBNavigatorViewController: EditingActionsControllerDelegate {
    
    func editingActionsDidPreventCopy(_ editingActions: EditingActionsController) {
        delegate?.navigator(self, presentError: .copyForbidden)
        // FIXME: Deprecated, to be removed at some point.
        delegate?.presentError(.copyForbidden)
    }
    
}

extension EPUBNavigatorViewController: PaginationViewDelegate {
    
    func paginationView(_ paginationView: PaginationView, pageViewAtIndex index: Int) -> (UIView & PageView)? {
        let spread = spreads[index]
        let spreadViewType = (spread.layout == .fixed) ? EPUBFixedSpreadView.self : EPUBReflowableSpreadView.self
        let spreadView = spreadViewType.init(
            publication: publication,
            spread: spread,
            resourcesURL: resourcesURL,
            contentLayout: publication.contentLayout,
            readingProgression: readingProgression,
            userSettings: userSettings,
            animatedLoad: false,  // FIXME: custom animated
            editingActions: editingActions,
            contentInset: config.contentInset
        )
        spreadView.delegate = self
        return spreadView
    }
    
    func paginationViewDidUpdateViews(_ paginationView: PaginationView) {
        // notice that you should set the delegate before you load views
        // otherwise, when open the publication, you may miss the first invocation
        notifyCurrentLocation()

        // FIXME: Deprecated, to be removed at some point.
        if let currentResourceIndex = currentResourceIndex {
            delegate?.didChangedDocumentPage(currentDocumentIndex: currentResourceIndex)
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
    @available(*, deprecated, renamed: "init(publication:license:initialLocation:resourcesServer:config:)")
    public convenience init(for publication: Publication, license: DRMLicense? = nil, initialIndex: Int, initialProgression: Double?, pageTransition: PageTransition = .none, disableDragAndDrop: Bool = false, editingActions: [EditingAction] = EditingAction.defaultActions, contentInset: [UIUserInterfaceSizeClass: EPUBContentInsets]? = nil) {
        fatalError("This initializer is not available anymore.")
    }
    
    /// This initializer is deprecated.
    /// Use the new Configuration object.
    @available(*, deprecated, renamed: "init(publication:license:initialLocation:resourcesServer:config:)")
    public convenience init(publication: Publication, license: DRMLicense? = nil, initialLocation: Locator? = nil, editingActions: [EditingAction] = EditingAction.defaultActions, contentInset: [UIUserInterfaceSizeClass: EPUBContentInsets]? = nil, resourcesServer: ResourcesServer) {
        var config = Configuration()
        config.editingActions = editingActions
        if let contentInset = contentInset {
            config.contentInset = contentInset
        }
        self.init(publication: publication, license: license, initialLocation: initialLocation, resourcesServer: resourcesServer, config: config)
    }

    @available(*, deprecated, message: "Use the `animated` parameter of `goTo` functions instead")
    public var pageTransition: PageTransition {
        get { return .none }
        set {}
    }
    
    @available(*, deprecated, message: "Bookmark model is deprecated, use your own model and `currentLocation`")
    public var currentPosition: Bookmark? {
        guard let publicationID = publication.metadata.identifier,
            let locator = currentLocation,
            let currentResourceIndex = currentResourceIndex else
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
        goToReadingOrderIndex(index)
    }
    
    @available(*, deprecated, renamed: "go(to:)")
    public func displayReadingOrderItem(at index: Int, progression: Double) {
        let locator = Locator(link: publication.readingOrder[index]).copy(
            locations: { $0.progression = progression }
        )
        goToReadingOrderIndex(index, location: locator)
    }
    
    @available(*, deprecated, renamed: "go(to:)")
    public func displayReadingOrderItem(with href: String) -> Int? {
        let index = publication.readingOrder.firstIndex(withHref: href)
        let moved = go(to: Link(href: href))
        return moved ? index : nil
    }
    
}
