//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import PDFKit
import ReadiumShared
import UIKit

public protocol PDFNavigatorDelegate: VisualNavigatorDelegate, SelectableNavigatorDelegate {
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
    VisualNavigator, SelectableNavigator, Configurable, Loggable
{
    public struct Configuration {
        /// Initial set of setting preferences.
        public var preferences: PDFPreferences

        /// Provides default fallback values and ranges for the user settings.
        public var defaults: PDFDefaults

        /// Editing actions which will be displayed in the default text selection menu.
        ///
        /// The default set of editing actions is `EditingAction.defaultActions`.
        public var editingActions: [EditingAction]

        public init(
            preferences: PDFPreferences = PDFPreferences(),
            defaults: PDFDefaults = PDFDefaults(),
            editingActions: [EditingAction] = EditingAction.defaultActions
        ) {
            self.preferences = preferences
            self.defaults = defaults
            self.editingActions = editingActions
        }
    }

    enum Error: Swift.Error {
        /// The provided publication is restricted. Check that any DRM was
        /// properly unlocked using a Content Protection.
        case publicationRestricted

        case openPDFFailed
    }

    /// Whether the pages is always scaled to fit the screen, unless the user zoomed in.
    @available(*, unavailable, message: "This API is deprecated")
    public var scalesDocumentToFit: Bool { true }

    public weak var delegate: PDFNavigatorDelegate?
    public private(set) var pdfView: PDFDocumentView?
    private var pdfViewDefaultBackgroundColor: UIColor!

    public let publication: Publication
    private let initialLocation: Locator?
    private let config: Configuration
    private let editingActions: EditingActionsController
    /// Reading order index of the current resource.
    private var currentResourceIndex: Int?

    /// Holds the currently opened PDF Document.
    private let documentHolder = PDFDocumentHolder()

    // Holds a reference to make sure they are not garbage-collected.
    private var tapGestureController: PDFTapGestureController?
    private var clickGestureController: PDFTapGestureController?
    private var swipeLeftGestureRecognizer: UISwipeGestureRecognizer?
    private var swipeRightGestureRecognizer: UISwipeGestureRecognizer?

    private let server: HTTPServer?
    private let publicationEndpoint: HTTPServerEndpoint?
    private var publicationBaseURL: HTTPURL!

    public init(
        publication: Publication,
        initialLocation: Locator?,
        config: Configuration = .init(),
        delegate: PDFNavigatorDelegate? = nil,
        httpServer: HTTPServer
    ) throws {
        guard !publication.isRestricted else {
            throw Error.publicationRestricted
        }

        let uuidEndpoint: HTTPServerEndpoint = UUID().uuidString
        let publicationEndpoint: HTTPServerEndpoint?
        if publication.baseURL != nil {
            publicationEndpoint = nil
        } else {
            publicationEndpoint = uuidEndpoint
        }

        self.publication = publication
        self.initialLocation = initialLocation
        server = httpServer
        self.publicationEndpoint = publicationEndpoint
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

        if let url = publication.baseURL {
            publicationBaseURL = url
        } else {
            publicationBaseURL = try httpServer.serve(
                at: uuidEndpoint,
                publication: publication,
                onFailure: { [weak self] request, error in
                    DispatchQueue.main.async {
                        guard let self = self, let href = request.href else {
                            return
                        }
                        self.delegate?.navigator(self, didFailToLoadResourceAt: href, withError: error)
                    }
                }
            )
        }

        editingActions.delegate = self

        // Wraps the PDF factories of publication services to return the currently opened document
        // held in `documentHolder` when relevant. This prevents opening several times the same
        // document, which is useful in particular with `LCPDFPositionService`.
        for service in publication.findServices(PDFPublicationService.self) {
            service.pdfFactory = CompositePDFDocumentFactory(factories: [
                documentHolder, service.pdfFactory,
            ])
        }
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)

        if let endpoint = publicationEndpoint {
            do {
                try server?.remove(at: endpoint)
            } catch {
                log(.warning, "Failed to remove the server endpoint \(endpoint): \(error.localizedDescription)")
            }
        }
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
        let pdfView = PDFDocumentView(
            frame: view.bounds,
            editingActions: editingActions,
            documentViewDelegate: self
        )
        self.pdfView = pdfView
        pdfView.delegate = self
        pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(pdfView)

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
        let pointer = Pointer.touch(TouchPointer(id: ObjectIdentifier(gesture)))
        let modifiers = KeyModifiers(flags: gesture.modifierFlags)
        Task {
            _ = await inputObservers.didReceive(PointerEvent(pointer: pointer, phase: .down, location: location, modifiers: modifiers))
            _ = await inputObservers.didReceive(PointerEvent(pointer: pointer, phase: .up, location: location, modifiers: modifiers))
        }

        delegate?.navigator(self, didTapAt: location)
    }

    @objc private func didClick(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        let pointer = Pointer.mouse(MousePointer(id: ObjectIdentifier(gesture), buttons: .main))
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
        guard let locator = currentPosition else {
            return
        }
        delegate?.navigator(self, locationDidChange: locator)
    }

    @objc private func visiblePagesDidChange() {
        // In paginated mode, we want to refresh the scale factors to properly
        // fit the newly visible pages. This is especially important for
        // paginated spreads.
        if !settings.scroll {
            updateScaleFactors(zoomToFit: true)
        }
    }

    @discardableResult
    private func go(to locator: Locator, isJump: Bool) async -> Bool {
        let locator = publication.normalizeLocator(locator)

        let href: AnyURL? = {
            if isPDFFile {
                return publication.readingOrder.first?.url()
            } else {
                return publication.readingOrder.firstWithHREF(locator.href)?.url()
            }
        }()
        guard let href = href else {
            return false
        }

        return await go(
            to: href,
            pageNumber: pageNumber(for: locator),
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
            let url = publicationBaseURL.resolve(href),
            let index = publication.readingOrder.firstIndexWithHREF(href)
        else {
            return false
        }

        if currentResourceIndex != index {
            guard let document = PDFDocument(url: url.url) else {
                log(.error, "Can't open PDF document at \(url)")
                return false
            }

            currentResourceIndex = index
            documentHolder.set(document, at: href)
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

    private func pageNumber(for locator: Locator) -> Int? {
        for fragment in locator.locations.fragments {
            // https://tools.ietf.org/rfc/rfc3778
            let optionalPageParam = fragment
                .components(separatedBy: CharacterSet(charactersIn: "&#"))
                .map { $0.components(separatedBy: "=") }
                .first { $0.first == "page" && $0.count == 2 }
            if let pageParam = optionalPageParam, let pageNumber = Int(pageParam[1]) {
                return pageNumber
            }
        }

        guard
            let positions = positionsByReadingOrder,
            var position = locator.locations.position
        else {
            return nil
        }

        if
            publication.readingOrder.count > 1,
            let index = publication.readingOrder.firstIndexWithHREF(locator.href),
            let firstPosition = positions[index].first?.locations.position
        {
            position = position - firstPosition + 1
        }

        return position
    }

    /// Returns the position locator of the current page.
    private var currentPosition: Locator? {
        guard
            let pdfView = pdfView,
            let currentResourceIndex = currentResourceIndex,
            let pageNumber = pdfView.currentPage?.pageRef?.pageNumber,
            publication.readingOrder.indices.contains(currentResourceIndex),
            let positionsByReadingOrder = positionsByReadingOrder
        else {
            return nil
        }
        let positions = positionsByReadingOrder[currentResourceIndex]
        guard positions.count > 0, 1 ... positions.count ~= pageNumber else {
            return nil
        }

        return positions[pageNumber - 1]
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

    // MARK: - SelectableNavigator

    public var currentSelection: Selection? { editingActions.selection }

    public func clearSelection() {
        pdfView?.clearSelection()
    }

    // MARK: - User Selection

    @objc func selectionDidChange(_ note: Notification) {
        guard
            ensureSelectionIsAllowed(),
            let pdfView = pdfView,
            let selection = pdfView.currentSelection,
            let locator = currentLocation,
            let text = selection.string,
            let page = selection.pages.first
        else {
            editingActions.selection = nil
            return
        }

        editingActions.selection = Selection(
            locator: locator.copy(text: { $0.highlight = text }),
            frame: pdfView.convert(selection.bounds(for: page), from: page)
                // Makes it slightly bigger to have more room when displaying a popover.
                .insetBy(dx: -8, dy: -8)
        )
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
            /// Adds some context for bookmarking
            if let page = self?.pdfView?.currentPage {
                $0 = .init(highlight: String(page.string?.prefix(280) ?? ""))
            }
        })
    }

    public func go(to locator: Locator, options: NavigatorGoOptions) async -> Bool {
        await go(to: locator, isJump: true)
    }

    public func go(to link: Link, options: NavigatorGoOptions) async -> Bool {
        guard let locator = await publication.locate(link) else {
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
}

extension PDFNavigatorViewController: PDFViewDelegate {
    public func pdfViewWillClick(onLink sender: PDFView, with url: URL) {
        log(.debug, "Click URL: \(url)")

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
