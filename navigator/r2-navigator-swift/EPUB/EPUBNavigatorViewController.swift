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
    
    public weak var delegate: EPUBNavigatorDelegate?
    public var userSettings: UserSettings
    
    private let publication: Publication
    private let license: DRMLicense?
    private let editingActions: EditingActionsController
    /// Content insets used to add some vertical margins around reflowable EPUB publications. The insets can be configured for each size class to allow smaller margins on compact screens.
    private let contentInset: [UIUserInterfaceSizeClass: EPUBContentInsets]
    
    // FIXME: Add support to change the reading progression
    public var readingProgression: ReadingProgression
    private var spreads: [EPUBSpread]
    private let triptychView: TriptychView
    
    /// Index of the currently visible spread.
    private var currentSpreadIndex: Int {
        return triptychView.currentIndex
    }
    
    // Reading order index of the left-most resource in the visible spread.
    private var currentResourceIndex: Int? {
        return publication.readingOrder.firstIndex(withHref: spreads[currentSpreadIndex].left.href)
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

        readingProgression = publication.contentLayout.readingProgression
        spreads = [EPUBSpread](publication: publication, readingProgression: readingProgression)

        var initialIndex: Int = 0
        if let locator = locator, let foundIndex = spreads.firstIndex(withHref: locator.href) {
            initialIndex = foundIndex
        }

        triptychView = TriptychView(
            frame: CGRect.zero,
            resourcesCount: spreads.count,
            initialIndex: initialIndex,
            initialLocation: locator,
            readingProgression: readingProgression
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
        if let currentResourceIndex = currentResourceIndex {
            let progression = currentLocation?.locations?.progression
            delegate?.willExitPublication(documentIndex: currentResourceIndex, progression: progression)
        }
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
        return triptychView.goToIndex(spreadIndex, location: location, animated: animated, completion: completion)
    }
    
    /// Goes to the next or previous page in the given scroll direction.
    private func go(to direction: EPUBSpreadView.Direction, animated: Bool, completion: @escaping () -> Void) -> Bool {
        if let webView = triptychView.currentView as? EPUBSpreadView,
            webView.go(to: direction, animated: animated, completion: completion)
        {
            return true
        }
        
        let delta = readingProgression == .rtl ? -1 : 1
        switch direction {
        case .left:
            return triptychView.goToIndex(currentSpreadIndex - delta, animated: animated, completion: completion)
        case .right:
            return triptychView.goToIndex(currentSpreadIndex + delta, animated: animated, completion: completion)
        }
    }
    
    public func updateUserSettingStyle() {
        assert(Thread.isMainThread, "User settings must be updated from the main thread")
        
        guard !triptychView.isEmpty else {
            return
        }
        
        let location = currentLocation
        for (_, view) in triptychView.loadedViews {
            (view as? EPUBSpreadView)?.applyUserSettingsStyle()
        }
        
        // Re-positions the navigator to the location before applying the settings
        if let location = location {
            go(to: location)
        }
    }

    
    // MARK: - Navigator
    
    public var currentLocation: Locator? {
        guard let spreadView = triptychView.currentView as? EPUBSpreadView else {
            return nil
        }
        var location = spreadView.currentLocation
        location.title = tableOfContentsTitleByHref[location.href]
        return location
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
        return triptychView.goToIndex(spreadIndex, location: locator, animated: animated, completion: completion)
    }
    
    public func go(to link: Link, animated: Bool, completion: @escaping () -> Void) -> Bool {
        return go(to: Locator(link: link), animated: animated, completion: completion)
    }
    
    public func goForward(animated: Bool, completion: @escaping () -> Void) -> Bool {
        let direction: EPUBSpreadView.Direction = {
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
        let direction: EPUBSpreadView.Direction = {
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

extension EPUBNavigatorViewController: EPUBSpreadViewDelegate {
    
    func spreadViewWillAnimate(_ spreadView: EPUBSpreadView) {
        triptychView.isUserInteractionEnabled = false
    }
    
    func spreadViewDidAnimate(_ spreadView: EPUBSpreadView) {
        triptychView.isUserInteractionEnabled = true
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
    
    func spreadView(_ spreadView: EPUBSpreadView, didTapOnInternalLink href: String) {
        go(to: Link(href: href))
    }
    
    func spreadViewPagesDidChange(_ spreadView: EPUBSpreadView) {
        if triptychView.currentView == spreadView {
            notifyCurrentLocation()
        }
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

    func triptychView(_ triptychView: TriptychView, viewForIndex index: Int, location: Locator) -> (UIView & TriptychResourceView)? {
        let spread = spreads[index]
        let webViewType = (spread.layout == .fixed) ? EPUBFixedSpreadView.self : EPUBReflowableSpreadView.self
        let webView = webViewType.init(
            publication: publication,
            spread: spread,
            resourcesURL: resourcesURL,
            initialLocation: location,
            contentLayout: publication.contentLayout,
            readingProgression: triptychView.readingProgression,
            userSettings: userSettings,
            animatedLoad: false,  // FIXME: custom animated
            editingActions: editingActions,
            contentInset: contentInset
        )
        webView.delegate = self
        return webView
    }
    
    func triptychViewDidUpdateViews(_ triptychView: TriptychView) {
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
        var location = Locator(link: publication.readingOrder[index])
        location.locations = Locations(progression: progression)
        goToReadingOrderIndex(index, location: location)
    }
    
    @available(*, deprecated, renamed: "go(to:)")
    public func displayReadingOrderItem(with href: String) -> Int? {
        let index = publication.readingOrder.firstIndex(withHref: href)
        let moved = go(to: Link(href: href))
        return moved ? index : nil
    }
    
}
