//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@preconcurrency import PDFKit
import ReadiumShared
import UIKit

public protocol PDFNavigatorDelegate: VisualNavigatorDelegate,
    SelectableNavigatorDelegate, ViewportObservingNavigatorDelegate
{
    /// Called after the `PDFDocumentView` is created.
    ///
    /// Override to customize its behavior.
    func navigator(_ navigator: PDFNavigatorViewController, setupPDFView view: PDFDocumentView)
}

public extension PDFNavigatorDelegate {
    func navigator(_ navigator: PDFNavigatorViewController, setupPDFView view: PDFDocumentView) {}
}

/// A view controller used to render a PDF `Publication`.
open class PDFNavigatorViewController:
    InputObservableViewController,
    VisualNavigator, ViewportObservingNavigator, SelectableNavigator,
    DecorableNavigator,
    Configurable, Loggable
{
    public struct Configuration: Sendable {
        /// Initial set of setting preferences.
        public var preferences: PDFPreferences

        /// Provides default fallback values and ranges for the user settings.
        public var defaults: PDFDefaults

        /// Editing actions which will be displayed in the default text selection menu.
        ///
        /// The default set of editing actions is `EditingAction.defaultActions`.
        public var editingActions: [EditingAction]

        /// Supported PDF decoration templates, indexed by decoration style.
        ///
        /// Decorations are only rendered on iOS 16+.
        public var decorationTemplates: [Decoration.Style.Id: PDFDecorationTemplate]

        @MainActor
        public init(
            preferences: PDFPreferences = PDFPreferences(),
            defaults: PDFDefaults = PDFDefaults(),
            editingActions: [EditingAction] = EditingAction.defaultActions,
            decorationTemplates: [Decoration.Style.Id: PDFDecorationTemplate] = PDFDecorationTemplate.defaultTemplates()
        ) {
            self.preferences = preferences
            self.defaults = defaults
            self.editingActions = editingActions
            self.decorationTemplates = decorationTemplates
        }
    }

    enum Error: Swift.Error {
        /// The provided publication is restricted. Check that any DRM was
        /// properly unlocked using a Content Protection.
        case publicationRestricted

        case openPDFFailed
    }

    public weak var delegate: PDFNavigatorDelegate?
    public private(set) var pdfView: PDFDocumentView?
    private var pdfViewDefaultBackgroundColor: UIColor!

    public let publication: Publication
    private let initialLocation: Locator?
    private let config: Configuration
    private let editingActions: EditingActionsController
    /// Reading order index of the current resource.
    private var currentResourceIndex: Int?

    // Holds a reference to make sure they are not garbage-collected.
    private var tapGestureController: PDFTapGestureController?
    private var clickGestureController: PDFTapGestureController?
    private var swipeLeftGestureRecognizer: UISwipeGestureRecognizer?
    private var swipeRightGestureRecognizer: UISwipeGestureRecognizer?

    public init(
        publication: Publication,
        initialLocation: Locator?,
        config: Configuration = .init(),
        delegate: PDFNavigatorDelegate? = nil
    ) throws {
        guard !publication.isRestricted else {
            throw Error.publicationRestricted
        }

        self.publication = publication
        self.initialLocation = initialLocation
        self.config = config
        self.delegate = delegate
        editingActions = EditingActionsController(
            actions: config.editingActions,
            publication: publication
        )

        settings = PDFSettings(
            preferences: config.preferences,
            defaults: config.defaults,
            metadata: publication.metadata
        )

        super.init(nibName: nil, bundle: nil)

        editingActions.delegate = self
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override open func viewDidLoad() {
        super.viewDidLoad()

        Task {
            try? await didLoadPositions(publication.positionsByReadingOrder().get())
            resetPDFView(at: initialLocation)
        }
    }

    private var positionsByReadingOrder: [[Locator]]?

    private func didLoadPositions(_ positions: [[Locator]]?) {
        positionsByReadingOrder = positions ?? []
    }

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Hack to layout properly the first page when opening the PDF.
        if let pdfView = pdfView {
            pdfView.scaleFactor = pdfView.minScaleFactor
            if let page = pdfView.currentPage {
                pdfView.go(to: page.bounds(for: pdfView.displayBox), on: page)
            }
        }
    }

    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        if let pdfView = pdfView {
            // Makes sure that the PDF is always properly scaled when rotating
            // the screen, if the user didn't set a custom zoom.
            let isAtScaleFactor = pdfView.isAtScaleFactor(for: settings.fit)

            coordinator.animate(alongsideTransition: { _ in
                self.updateScaleFactors(zoomToFit: isAtScaleFactor)

                // Reset the PDF view to update the spread if needed.
                if self.settings.spread == .auto {
                    self.resetPDFView(at: self.currentLocation)
                }
            })
        }
    }

    @available(iOS 13.0, *)
    override open func buildMenu(with builder: UIMenuBuilder) {
        editingActions.buildMenu(with: builder)
        super.buildMenu(with: builder)
    }

    private var resetTask: Task<Void, Never>? {
        willSet {
            resetTask?.cancel()
        }
    }

    private func resetPDFView(at locator: Locator?) {
        guard isViewLoaded else {
            return
        }

        resetTask = Task {
            await _resetPDFView(at: locator)
        }
    }

    private func _resetPDFView(at locator: Locator?) async {
        if let pdfView = pdfView {
            pdfView.removeFromSuperview()
            NotificationCenter.default.removeObserver(self)
        }

        currentResourceIndex = nil
        viewport = nil
        resolvedDecorationsCache.removeAll()
        let pdfView = PDFDocumentView(
            frame: view.bounds,
            editingActions: editingActions,
            documentViewDelegate: self
        )
        self.pdfView = pdfView
        pdfView.delegate = self

        if #available(iOS 16.0, *) {
            // Must be attached before setting `pdfView.document`.
            pdfView.pageOverlayViewProvider = decorationOverlayProvider
        }
        pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(pdfView)

        // The loading indicator may have been added before viewDidLoad fired (e.g. go(to:)
        // called immediately after init). Re-stack it above the newly inserted PDFView.
        if let indicator = loadingIndicator {
            view.bringSubviewToFront(indicator)
        }

        tapGestureController = PDFTapGestureController(
            pdfView: pdfView,
            touchTypes: [.direct, .indirect],
            target: self,
            action: #selector(didTap)
        )
        clickGestureController = PDFTapGestureController(
            pdfView: pdfView,
            touchTypes: [.indirectPointer],
            target: self,
            action: #selector(didClick)
        )
        swipeLeftGestureRecognizer = recognizeSwipe(in: pdfView, direction: .left)
        swipeRightGestureRecognizer = recognizeSwipe(in: pdfView, direction: .right)

        apply(settings: settings, to: pdfView)
        delegate?.navigator(self, setupPDFView: pdfView)

        NotificationCenter.default.addObserver(self, selector: #selector(pageDidChange), name: .PDFViewPageChanged, object: pdfView)
        NotificationCenter.default.addObserver(self, selector: #selector(visiblePagesDidChange), name: .PDFViewVisiblePagesChanged, object: pdfView)
        NotificationCenter.default.addObserver(self, selector: #selector(selectionDidChange), name: .PDFViewSelectionChanged, object: pdfView)
        NotificationCenter.default.addObserver(self, selector: #selector(scaleFactorDidChange), name: .PDFViewScaleChanged, object: pdfView)

        if let locator = locator {
            await go(to: locator, isJump: false)
        } else if let link = publication.readingOrder.first {
            await go(to: link.url(), pageNumber: 0, isJump: false)
        } else {
            log(.error, "No initial location and empty reading order")
        }
    }

    private func apply(settings: PDFSettings, to pdfView: PDFView) {
        let isRTL = (settings.readingProgression == .rtl)

        pdfView.displaysAsBook = settings.offsetFirstPage

        let spread: Bool = {
            switch settings.spread {
            case .auto:
                return view.bounds.width > view.bounds.height
            case .never:
                return false
            case .always:
                return true
            }
        }()

        if settings.scroll {
            pdfView.displayDirection = settings.scrollAxis.displayDirection
            if spread, pdfView.displayDirection == .vertical {
                pdfView.displayMode = .twoUpContinuous
            } else {
                pdfView.displayMode = .singlePageContinuous
            }

        } else { // paginated
            if spread {
                pdfView.displayMode = .twoUp
            } else {
                pdfView.usePageViewController(true)
            }

            pdfView.displayDirection = .horizontal
        }

        var margins: UIEdgeInsets = .zero
        let pageSpacing = settings.pageSpacing
        if pdfView.displayDirection == .horizontal {
            if isRTL {
                margins.left = pageSpacing
            } else {
                margins.right = pageSpacing
            }
        } else {
            margins.bottom = pageSpacing
        }
        pdfView.pageBreakMargins = margins

        pdfView.displaysRTL = isRTL
        pdfView.displaysPageBreaks = true
        pdfView.autoScales = false

        if let scrollView = pdfView.firstScrollView {
            let showScrollbar = settings.visibleScrollbar
            scrollView.showsVerticalScrollIndicator = showScrollbar
            scrollView.showsHorizontalScrollIndicator = showScrollbar
        }

        if pdfViewDefaultBackgroundColor == nil {
            pdfViewDefaultBackgroundColor = pdfView.backgroundColor
        }
        pdfView.backgroundColor = settings.backgroundColor?.uiColor
            ?? pdfViewDefaultBackgroundColor

        let enableSwipes = !settings.scroll && spread
        swipeLeftGestureRecognizer?.isEnabled = enableSwipes
        swipeRightGestureRecognizer?.isEnabled = enableSwipes
    }

    @objc private func didTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        guard !activateDecoration(at: location) else {
            return
        }
        let pointer = Pointer.touch(TouchPointer(id: .object(ObjectIdentifier(gesture))))
        let modifiers = KeyModifiers(flags: gesture.modifierFlags)
        Task {
            _ = await inputObservers.didReceive(PointerEvent(pointer: pointer, phase: .down, location: location, modifiers: modifiers))
            _ = await inputObservers.didReceive(PointerEvent(pointer: pointer, phase: .up, location: location, modifiers: modifiers))
        }

        delegate?.navigator(self, didTapAt: location)
    }

    @objc private func didClick(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        guard !activateDecoration(at: location) else {
            return
        }
        let pointer = Pointer.mouse(MousePointer(id: .object(ObjectIdentifier(gesture)), buttons: .main))
        let modifiers = KeyModifiers(flags: gesture.modifierFlags)
        Task {
            _ = await inputObservers.didReceive(PointerEvent(pointer: pointer, phase: .down, location: location, modifiers: modifiers))
            _ = await inputObservers.didReceive(PointerEvent(pointer: pointer, phase: .up, location: location, modifiers: modifiers))
        }

        delegate?.navigator(self, didTapAt: location)
    }

    private func recognizeSwipe(in view: UIView, direction: UISwipeGestureRecognizer.Direction) -> UISwipeGestureRecognizer {
        let recognizer = UISwipeGestureRecognizer(target: self, action: #selector(didSwipe))
        recognizer.direction = direction
        recognizer.numberOfTouchesRequired = 1
        view.addGestureRecognizer(recognizer)
        return recognizer
    }

    @objc private func didSwipe(_ gesture: UISwipeGestureRecognizer) {
        switch gesture.direction {
        case .left:
            Task { await goRight(options: .animated) }
        case .right:
            Task { await goLeft(options: .animated) }
        default:
            break
        }
    }

    @objc private func pageDidChange() {
        if let locator = currentPosition {
            delegate?.navigator(self, locationDidChange: locator)
        }
    }

    @objc private func visiblePagesDidChange() {
        // In paginated mode, we want to refresh the scale factors to properly
        // fit the newly visible pages. This is especially important for
        // paginated spreads.
        if !settings.scroll {
            updateScaleFactors(zoomToFit: true)
        }

        viewport = computeLocatorAndViewport().viewport
    }

    @discardableResult
    private func go(to locator: Locator, isJump: Bool) async -> Bool {
        let locator = publication.normalizeLocator(locator)

        let readingOrderIndex: Int? =
            if isPDFFile { 0 }
            else { publication.readingOrder.firstIndexWithHREF(locator.href) }

        guard let readingOrderIndex else {
            return false
        }

        return await go(
            to: publication.readingOrder[readingOrderIndex],
            pageNumber: pageNumber(
                for: locator,
                readingOrderIndex: readingOrderIndex
            ),
            isJump: isJump
        )
    }

    /// Historically, the reading order of a standalone PDF file contained a
    /// single link with the HREF `"/<asset filename>"`. This was fragile if
    /// the asset named changed, or was different on other devices.
    ///
    /// To avoid this, we now use a single link with the HREF
    /// `"publication.pdf"`. And to avoid breaking legacy locators, we match
    /// any HREF if the reading order contains a single link with the HREF
    /// `"publication.pdf"`.
    private lazy var isPDFFile: Bool =
        publication.readingOrder.count == 1 && publication.readingOrder[0].href == "publication.pdf"

    @discardableResult
    private func go<HREF: URLConvertible>(to href: HREF, pageNumber: Int?, isJump: Bool) async -> Bool {
        guard
            let pdfView = pdfView,
            let index = publication.readingOrder.firstIndexWithHREF(href)
        else {
            return false
        }

        if currentResourceIndex != index {
            showLoadingIndicator()
            defer { hideLoadingIndicator() }

            guard let document = await openDocument(at: href) else {
                log(.error, "Can't open PDF document at \(href)")
                return false
            }

            currentResourceIndex = index
            resolvedDecorationsCache.removeAll()
            pdfView.document = document
            updateScaleFactors(zoomToFit: true)
        }

        guard let document = pdfView.document else {
            return false
        }
        if let pageNumber = pageNumber {
            let safePageNumber = min(max(0, pageNumber - 1), document.pageCount - 1)
            guard let page = document.page(at: safePageNumber) else {
                return false
            }
            pdfView.go(to: page)
        }
        if isJump, let delegate = delegate, let location = currentPosition {
            delegate.navigator(self, didJumpTo: location)
        }

        return true
    }

    private func openDocument<HREF: URLConvertible & Sendable>(at href: HREF) async -> PDFKit.PDFDocument? {
        let service = publication.pdfDocumentService

        if let cached = await service?.cachedDocument(at: href) as? PDFKitDocumentProviding {
            return cached.pdfKitDocument
        }

        let factory = PDFKitPDFDocumentFactory()
        guard
            let resource = publication.get(href),
            let document = try? await factory.open(resource: resource, at: href, password: nil),
            let pdfKitDocument = (document as? PDFKitDocumentProviding)?.pdfKitDocument
        else {
            return nil
        }

        await service?.setCachedDocument(document, at: href)

        return pdfKitDocument
    }

    /// Updates the scale factors to match the currently visible pages.
    ///
    /// - Parameter zoomToFit: When true, the document will be zoomed to fit the
    ///   visible pages.
    private func updateScaleFactors(zoomToFit: Bool) {
        guard let pdfView = pdfView else {
            return
        }

        let scaleFactorToFit = pdfView.scaleFactor(for: settings.fit)

        if settings.scroll {
            // Allow zooming out to 25% in scroll mode.
            pdfView.minScaleFactor = 0.25
        } else {
            pdfView.minScaleFactor = scaleFactorToFit
        }

        pdfView.maxScaleFactor = 4.0

        if zoomToFit {
            pdfView.scaleFactor = scaleFactorToFit
        }
    }

    private func pageNumber(for locator: Locator, readingOrderIndex: Int) -> Int? {
        PDFPageNumberResolver.resolve(
            from: locator,
            readingOrderIndex: readingOrderIndex,
            positionsByReadingOrder: positionsByReadingOrder,
            documentPageCount: pdfView?.document?.pageCount
        )
    }

    private func locator(to pageNumber: Int) -> Locator? {
        guard
            let currentResourceIndex = currentResourceIndex,
            let readingOrderLink = publication.readingOrder.getOrNil(currentResourceIndex)
        else {
            return nil
        }

        let href = readingOrderLink.url().removingFragment()
        return Locator(
            href: href,
            mediaType: readingOrderLink.mediaType ?? .pdf,
            locations: .init(
                fragments: ["page=\(pageNumber)"]
            )
        )
    }

    private func locator(to page: PDFPage) -> Locator? {
        guard let document = pdfView?.document else {
            return nil
        }

        let index = document.index(for: page)
        guard index != NSNotFound else {
            return nil
        }

        return locator(to: index + 1)
    }

    private func link(to page: PDFPage) -> Link? {
        guard let locator = locator(to: page) else {
            return nil
        }

        let href = locator.href.replacingFragment(locator.locations.fragments.first)
        return Link(href: href.string, mediaType: locator.mediaType)
    }

    /// Returns the position locator of the current page.
    private var currentPosition: Locator? {
        guard
            let pdfView = pdfView,
            let currentResourceIndex = currentResourceIndex,
            let pageNumber = pdfView.currentPage?.pageRef?.pageNumber,
            let positionsByReadingOrder = positionsByReadingOrder
        else {
            return nil
        }
        return PDFViewportCalculator.computeLocator(
            currentPageNumber: pageNumber,
            currentResourceIndex: currentResourceIndex,
            readingOrder: publication.readingOrder,
            positionsByReadingOrder: positionsByReadingOrder
        )
    }

    // MARK: - DecorableNavigator

    private var decorations: [DecorationGroup: [DiffableDecoration]] = [:]

    /// Groups in the order they were first applied, which determines the
    /// z-order of the rendered decorations.
    private var decorationGroupOrder: [DecorationGroup] = []

    /// Decoration group callbacks, indexed by the group name.
    private var decorationCallbacks: [DecorationGroup: [DecorableNavigator.OnActivatedCallback]] = [:]

    /// Resolved geometry for the pages of the current resource, keyed by
    /// 0-based page index.
    ///
    /// Cleared whenever the decorations change, the document is swapped for
    /// another resource or the PDF view is reset, so entries never leak
    /// across resources.
    private var resolvedDecorationsCache: [Int: [PDFDecorationRenderItem]] = [:]

    private var _decorationOverlayProvider: AnyObject?
    @available(iOS 16.0, *)
    private var decorationOverlayProvider: PDFDecorationOverlayProvider {
        if let provider = _decorationOverlayProvider as? PDFDecorationOverlayProvider {
            return provider
        }
        let provider = PDFDecorationOverlayProvider()
        provider.dataSource = self
        _decorationOverlayProvider = provider
        return provider
    }

    public func supports(decorationStyle style: Decoration.Style.Id) -> Bool {
        guard #available(iOS 16.0, *) else {
            return false
        }
        return config.decorationTemplates.keys.contains(style)
    }

    public func apply(decorations: [Decoration], in group: DecorationGroup) {
        guard #available(iOS 16.0, *) else {
            log(.warning, "PDF decorations require iOS 16+, apply(decorations:in:) is ignored. Check supports(decorationStyle:) before applying decorations.")
            return
        }

        if !decorationGroupOrder.contains(group) {
            decorationGroupOrder.append(group)
        }

        let source = self.decorations[group] ?? []
        let target = decorations.map {
            var decoration = $0
            decoration.locator = publication.normalizeLocator(decoration.locator)
            return DiffableDecoration(decoration: decoration)
        }
        self.decorations[group] = target

        let changes = target.changesByHREF(from: source)
        guard !changes.isEmpty else {
            return
        }

        guard
            let pdfView = pdfView,
            let document = pdfView.document
        else {
            resolvedDecorationsCache.removeAll()
            return
        }

        var affectsCurrentResource = false
        for (href, hrefChanges) in changes {
            guard isCurrentResource(href: href) else {
                continue
            }
            affectsCurrentResource = true

            for change in hrefChanges {
                switch change {
                case let .add(decoration):
                    invalidateResolvedDecorations(for: decoration.locator, document: document)
                case let .remove(id):
                    if let old = source.first(where: { $0.decoration.id == id }) {
                        invalidateResolvedDecorations(for: old.decoration.locator, document: document)
                    } else {
                        resolvedDecorationsCache.removeAll()
                    }
                case let .update(decoration):
                    invalidateResolvedDecorations(for: decoration.locator, document: document)
                    // The update may have moved the decoration to another page.
                    if let old = source.first(where: { $0.decoration.id == decoration.id }) {
                        invalidateResolvedDecorations(for: old.decoration.locator, document: document)
                    }
                }
            }
        }

        if affectsCurrentResource {
            decorationOverlayProvider.refresh(in: pdfView)
        }
    }

    public func observeDecorationInteractions(inGroup group: DecorationGroup, onActivated: @escaping OnActivatedCallback) {
        var callbacks = decorationCallbacks[group] ?? []
        callbacks.append(onActivated)
        decorationCallbacks[group] = callbacks
    }

    /// Returns whether the given HREF matches the currently loaded resource,
    /// honoring the legacy `publication.pdf` HREF matching.
    private func isCurrentResource<T: URLConvertible>(href: T) -> Bool {
        if isPDFFile {
            return true
        }
        guard
            let resourceIndex = currentResourceIndex,
            let resourceURL = publication.readingOrder.getOrNil(resourceIndex)?.url()
        else {
            return false
        }
        return resourceURL.isEquivalentTo(href)
    }

    /// Resolves the 0-based page index of `locator` in the current resource's
    /// document, the single conversion point from 1-based page numbers.
    private func pageIndex(for locator: Locator, in document: PDFKit.PDFDocument) -> Int? {
        guard let resourceIndex = currentResourceIndex else {
            return nil
        }
        return PDFPageNumberResolver.resolve(
            from: locator,
            readingOrderIndex: resourceIndex,
            positionsByReadingOrder: positionsByReadingOrder,
            documentPageCount: document.pageCount
        ).map { $0 - 1 }
    }

    private func invalidateResolvedDecorations(for locator: Locator, document: PDFKit.PDFDocument) {
        if let pageIndex = pageIndex(for: locator, in: document) {
            resolvedDecorationsCache.removeValue(forKey: pageIndex)
        } else {
            resolvedDecorationsCache.removeAll()
        }
    }

    /// Resolves the decorations to render on the given page, in ascending
    /// z-order: groups in the order they were first applied, then array order
    /// within a group.
    @available(iOS 16.0, *)
    private func resolvedDecorations(forPageIndex pageIndex: Int, in document: PDFKit.PDFDocument) -> [PDFDecorationRenderItem] {
        if let cached = resolvedDecorationsCache[pageIndex] {
            return cached
        }
        guard let page = document.page(at: pageIndex) else {
            return []
        }
        let pageBounds = page.bounds(for: .cropBox)

        var items: [PDFDecorationRenderItem] = []
        for group in decorationGroupOrder {
            for diffable in decorations[group] ?? [] {
                let decoration = diffable.decoration
                guard
                    isCurrentResource(href: decoration.locator.href),
                    self.pageIndex(for: decoration.locator, in: document) == pageIndex
                else {
                    continue
                }
                guard let template = config.decorationTemplates[decoration.style.id] else {
                    log(.warning, "Decoration style \(decoration.style.id.rawValue) is not supported by the PDF navigator")
                    continue
                }
                guard let lineRects = PDFDecorationResolver.resolveRects(for: decoration.locator, on: page) else {
                    log(.warning, "Can't resolve the geometry of the decoration \(decoration.id) at page index \(pageIndex)")
                    continue
                }
                items.append(PDFDecorationRenderItem(
                    decoration: decoration,
                    group: group,
                    rects: template.layoutRects(for: lineRects, pageBounds: pageBounds, expand: decoration.style.expand),
                    template: template
                ))
            }
        }

        resolvedDecorationsCache[pageIndex] = items
        return items
    }

    /// Attempts to activate a decoration at the tapped `point`, given in the
    /// navigator view's coordinates. When it succeeds, the tap is consumed.
    ///
    /// Among the hit decorations belonging to observed groups, the topmost in
    /// z-order wins.
    private func activateDecoration(at point: CGPoint) -> Bool {
        guard
            #available(iOS 16.0, *),
            let pdfView = pdfView,
            let document = pdfView.document
        else {
            return false
        }
        let pointInPDFView = view.convert(point, to: pdfView)
        guard let page = pdfView.page(for: pointInPDFView, nearest: false) else {
            return false
        }
        let pageIndex = document.index(for: page)
        guard pageIndex != NSNotFound else {
            return false
        }
        let pagePoint = pdfView.convert(pointInPDFView, to: page)

        let items = resolvedDecorations(forPageIndex: pageIndex, in: document)
        for item in items.reversed() {
            guard
                let callbacks = decorationCallbacks[item.group].takeIf({ !$0.isEmpty }),
                item.rects.contains(where: { $0.contains(pagePoint) }),
                // The event's rect is the bounding rectangle for the
                // decoration on this page, in the navigator view's coordinates.
                let bounds = item.rects.union()
            else {
                continue
            }
            let rect = view.convert(pdfView.convert(bounds, from: page), from: pdfView)
            for callback in callbacks {
                callback(OnDecorationActivatedEvent(decoration: item.decoration, group: item.group, rect: rect, point: point))
            }
            return true
        }
        return false
    }

    @objc private func scaleFactorDidChange() {
        if #available(iOS 16.0, *), let pdfView = pdfView {
            decorationOverlayProvider.didChangeScaleFactor(of: pdfView)
        }
    }

    // MARK: - Configurable

    public private(set) var settings: PDFSettings

    public func submitPreferences(_ preferences: PDFPreferences) {
        settings = PDFSettings(
            preferences: preferences,
            defaults: config.defaults,
            metadata: publication.metadata
        )
        resetPDFView(at: currentLocation)

        delegate?.navigator(self, presentationDidChange: presentation)
    }

    public func editor(of preferences: PDFPreferences) -> PDFPreferencesEditor {
        PDFPreferencesEditor(
            initialPreferences: preferences,
            metadata: publication.metadata,
            defaults: config.defaults
        )
    }

    // MARK: - ViewportObservingNavigator

    public private(set) var viewport: NavigatorViewport? {
        didSet {
            guard oldValue != viewport else { return }
            delegate?.navigator(self, viewportDidChange: viewport)
        }
    }

    private func computeLocatorAndViewport() -> (locator: Locator?, viewport: NavigatorViewport?) {
        guard
            let pdfView = pdfView,
            let currentResourceIndex = currentResourceIndex,
            let positionsByReadingOrder = positionsByReadingOrder,
            let document = pdfView.document,
            let currentPageNumber = pdfView.currentPage?.pageRef?.pageNumber
        else {
            return (nil, nil)
        }

        let visiblePageNumbers = extractVisiblePageNumbers(from: pdfView) ?? (currentPageNumber ... currentPageNumber)

        return PDFViewportCalculator.compute(
            currentPageNumber: currentPageNumber,
            visiblePageNumbers: visiblePageNumbers,
            pageCount: document.pageCount,
            currentResourceIndex: currentResourceIndex,
            readingOrder: publication.readingOrder,
            positionsByReadingOrder: positionsByReadingOrder
        )
    }

    private func extractVisiblePageNumbers(from pdfView: PDFDocumentView) -> ClosedRange<Int>? {
        let sorted = visiblePages(in: pdfView)
            .compactMap { $0.pageRef?.pageNumber }
            .sorted()
        guard
            let first = sorted.first,
            let last = sorted.last
        else {
            return nil
        }

        return first ... last
    }

    /// `PDFView.visiblePages` does not correctly account for the current
    /// zoom scale in scroll mode, returning pages that are outside the
    /// visible viewport. We filter each candidate page through PDFKit's own
    /// `convert(_:from:)`, which maps page bounds into view coordinates
    /// accounting for both scroll position and zoom, and discard any pages
    /// that don't actually intersect the view's visible bounds.
    private func visiblePages(in pdfView: PDFDocumentView) -> [PDFPage] {
        var pages = pdfView.visiblePages

        if settings.scroll {
            let viewBounds = pdfView.bounds
            pages = pages
                .filter { page in
                    let pageRectInView = pdfView.convert(page.bounds(for: pdfView.displayBox), from: page)
                    return pageRectInView.intersects(viewBounds)
                }
        }

        return pages
    }

    // MARK: - SelectableNavigator

    public var currentSelection: Selection? {
        editingActions.selection
    }

    public func clearSelection() {
        pdfView?.clearSelection()
    }

    // MARK: - User Selection

    @objc func selectionDidChange(_ note: Notification) {
        guard
            ensureSelectionIsAllowed(),
            let pdfView = pdfView,
            let selection = pdfView.currentSelection,
            let text = selection.string,
            let page = selection.pages.first,
            let baseLocator = positionLocator(forPage: page) ?? locator(to: page) ?? currentLocation
        else {
            editingActions.selection = nil
            return
        }

        // One standard-syntax `highlight=` fragment per line, so a decoration
        // created from this selection renders per-line boxes directly, with
        // no text search.
        let lineFragments = selection.selectionsByLine()
            .filter { $0.pages.contains(page) }
            .map { PDFRectFragment.highlightFragment(for: $0.bounds(for: page)) }

        let (before, after) = selectionContext(for: selection, on: page)

        editingActions.selection = Selection(
            locator: baseLocator.copy(
                locations: { $0.fragments.append(contentsOf: lineFragments) },
                text: { $0 = Locator.Text(after: after, before: before, highlight: text) }
            ),
            frame: pdfView.convert(selection.bounds(for: page), from: page)
                // Makes it slightly bigger to have more room when displaying a popover.
                .insetBy(dx: -8, dy: -8)
        )
    }

    /// Returns the position locator matching the given page, which carries the
    /// page fragment, position and progressions.
    private func positionLocator(forPage page: PDFPage) -> Locator? {
        guard
            let document = pdfView?.document,
            let resourceIndex = currentResourceIndex
        else {
            return nil
        }
        let index = document.index(for: page)
        guard index != NSNotFound else {
            return nil
        }
        return positionsByReadingOrder?.getOrNil(resourceIndex)?.getOrNil(index)
    }

    /// Extracts the text surrounding the selection on the page, kept in the
    /// locator for display and as a cross-format fallback.
    private func selectionContext(for selection: PDFSelection, on page: PDFPage) -> (before: String?, after: String?) {
        let contextLength = 200
        guard let pageText = page.string else {
            return (nil, nil)
        }
        let text = pageText as NSString
        let rangeCount = selection.numberOfTextRanges(on: page)
        guard rangeCount > 0 else {
            return (nil, nil)
        }
        let firstRange = selection.range(at: 0, on: page)
        let lastRange = selection.range(at: rangeCount - 1, on: page)
        guard
            firstRange.location != NSNotFound,
            firstRange.location <= text.length,
            NSMaxRange(lastRange) <= text.length
        else {
            return (nil, nil)
        }

        let beforeStart = max(0, firstRange.location - contextLength)
        let before = text.substring(with: NSRange(location: beforeStart, length: firstRange.location - beforeStart))
        let afterStart = NSMaxRange(lastRange)
        let afterEnd = min(text.length, afterStart + contextLength)
        let after = text.substring(with: NSRange(location: afterStart, length: afterEnd - afterStart))

        return (before.isEmpty ? nil : before, after.isEmpty ? nil : after)
    }

    /// From iOS 13 to 15, the Share menu action is impossible to remove without
    /// resorting to complex method swizzling in the subviews of ``PDFView``.
    /// (https://stackoverflow.com/a/61361294)
    ///
    /// To prevent users from copying the text, we simply disable all text
    /// selection in this case.
    private func ensureSelectionIsAllowed() -> Bool {
        guard !editingActions.canCopy else {
            return true
        }

        if #available(iOS 13, *) {
            if #available(iOS 16, *) {
                // Do nothing, as the issue is solved since iOS 16.
            } else {
                if let pdfView = pdfView, pdfView.currentSelection != nil {
                    pdfView.clearSelection()
                }
                return false
            }
        }
        return true
    }

    // MARK: - Navigator

    public var presentation: VisualNavigatorPresentation {
        VisualNavigatorPresentation(
            readingProgression: settings.readingProgression,
            scroll: settings.scroll,
            axis: settings.scrollAxis
        )
    }

    public var readingProgression: ReadiumShared.ReadingProgression {
        ReadiumShared.ReadingProgression(presentation.readingProgression)
    }

    public var currentLocation: Locator? {
        currentPosition?.copy(text: { [weak self] in
            // Adds some context for bookmarking
            if let page = self?.pdfView?.currentPage {
                $0 = .init(highlight: String(page.string?.prefix(280) ?? ""))
            }
        })
    }

    public func go(to locator: Locator, options: NavigatorGoOptions) async -> Bool {
        await go(to: locator, isJump: true)
    }

    public func go(to link: Link, options: NavigatorGoOptions) async -> Bool {
        guard let locator = publication.locator(for: link) else {
            return false
        }

        return await go(to: locator, options: options)
    }

    public func goForward(options: NavigatorGoOptions) async -> Bool {
        if let pdfView = pdfView, pdfView.canGoToNextPage {
            pdfView.goToNextPage(nil)
            return true
        }

        let nextIndex = (currentResourceIndex ?? -1) + 1
        guard
            publication.readingOrder.indices.contains(nextIndex),
            let nextPosition = positionsByReadingOrder?.getOrNil(nextIndex)?.first
        else {
            return false
        }

        return await go(to: nextPosition, options: options)
    }

    public func goBackward(options: NavigatorGoOptions) async -> Bool {
        if let pdfView = pdfView, pdfView.canGoToPreviousPage {
            pdfView.goToPreviousPage(nil)
            return true
        }

        let previousIndex = (currentResourceIndex ?? 0) - 1
        guard
            publication.readingOrder.indices.contains(previousIndex),
            let previousPosition = positionsByReadingOrder?.getOrNil(previousIndex)?.first
        else {
            return false
        }
        return await go(to: previousPosition, options: options)
    }

    // MARK: - Loading Indicator

    private weak var loadingIndicator: UIActivityIndicatorView?

    private func showLoadingIndicator() {
        loadingIndicator?.removeFromSuperview()
        loadingIndicator = view.addCenteredActivityIndicator()
    }

    private func hideLoadingIndicator() {
        loadingIndicator?.removeFromSuperview()
        loadingIndicator = nil
    }
}

extension PDFNavigatorViewController: @preconcurrency PDFViewDelegate {
    public func pdfViewWillClick(onLink sender: PDFView, with url: URL) {
        let url = url.addingSchemeWhenMissing("http")
        delegate?.navigator(self, presentExternalURL: url)
    }

    public func pdfViewParentViewController() -> UIViewController {
        self
    }
}

extension PDFNavigatorViewController: PDFDocumentViewDelegate {
    func pdfDocumentViewContentInset(_ pdfDocumentView: PDFDocumentView) -> UIEdgeInsets? {
        delegate?.navigatorContentInset(self)
    }

    func pdfDocumentView(_ pdfDocumentView: PDFDocumentView, shouldGoTo destination: PDFDestination) -> Bool {
        guard
            let page = destination.page,
            let link = link(to: page)
        else {
            return true
        }

        return delegate?.navigator(self, shouldNavigateToLink: link) ?? true
    }

    func pdfDocumentView(_ pdfDocumentView: PDFDocumentView, didGoTo destination: PDFDestination) {
        guard
            let page = destination.page,
            let locator = locator(to: page)
        else {
            return
        }

        delegate?.navigator(self, didJumpTo: locator)
    }
}

@available(iOS 16.0, *)
extension PDFNavigatorViewController: PDFDecorationOverlayDataSource {
    func decorationOverlayProvider(
        _ provider: PDFDecorationOverlayProvider,
        decorationsForPageAt pageIndex: Int,
        in document: PDFKit.PDFDocument
    ) -> [PDFDecorationRenderItem] {
        resolvedDecorations(forPageIndex: pageIndex, in: document)
    }
}

extension PDFNavigatorViewController: EditingActionsControllerDelegate {
    func editingActionsDidPreventCopy(_ editingActions: EditingActionsController) {
        delegate?.navigator(self, presentError: .copyForbidden)
    }

    func editingActions(_ editingActions: EditingActionsController, shouldShowMenuForSelection selection: Selection) -> Bool {
        delegate?.navigator(self, shouldShowMenuForSelection: selection) ?? true
    }

    func editingActions(_ editingActions: EditingActionsController, canPerformAction action: EditingAction, for selection: Selection) -> Bool {
        delegate?.navigator(self, canPerformAction: action, for: selection) ?? true
    }
}

extension PDFNavigatorViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

private extension Axis {
    var displayDirection: PDFDisplayDirection {
        switch self {
        case .vertical: return .vertical
        case .horizontal: return .horizontal
        }
    }
}
