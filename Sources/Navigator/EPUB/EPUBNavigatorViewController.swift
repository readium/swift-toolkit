//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumInternal
import ReadiumShared
import SafariServices
import SwiftSoup
import UIKit
import WebKit

public protocol EPUBNavigatorDelegate: VisualNavigatorDelegate, SelectableNavigatorDelegate {
    // MARK: - WebView Customization

    func navigator(_ navigator: EPUBNavigatorViewController, setupUserScripts userContentController: WKUserContentController)
}

public extension EPUBNavigatorDelegate {
    func navigator(_ navigator: EPUBNavigatorViewController, setupUserScripts userContentController: WKUserContentController) {}

    @available(*, unavailable, message: "Implement navigator(_:didTapAt:) instead.")
    func middleTapHandler() {}
    @available(*, unavailable, message: "Implement navigator(_:locationDidChange:) instead, to save the last read location")
    func willExitPublication(documentIndex: Int, progression: Double?) {}
    @available(*, unavailable, message: "Implement navigator(_:locationDidChange:) instead")
    func didChangedDocumentPage(currentDocumentIndex: Int) {}
    @available(*, unavailable)
    func didNavigateViaInternalLinkTap(to documentIndex: Int) {}
    @available(*, unavailable, message: "Implement navigator(_:presentError:) instead")
    func presentError(_ error: NavigatorError) {}
}

public typealias EPUBContentInsets = (top: CGFloat, bottom: CGFloat)

open class EPUBNavigatorViewController: UIViewController,
    VisualNavigator, SelectableNavigator, DecorableNavigator,
    Configurable, Loggable
{
    public enum EPUBError: Error {
        /// The provided publication is restricted. Check that any DRM was
        /// properly unlocked using a Content Protection.
        case publicationRestricted

        /// Returned when calling evaluateJavaScript() before a resource is
        /// loaded.
        case spreadNotLoaded

        /// Failed to serve the publication or assets with the provided HTTP
        /// server.
        case serverFailure(Error)
    }

    public struct Configuration {
        /// Initial set of setting preferences.
        public var preferences: EPUBPreferences

        /// Provides default fallback values and ranges for the user settings.
        public var defaults: EPUBDefaults

        /// Editing actions which will be displayed in the default text selection menu.
        ///
        /// The default set of editing actions is `EditingAction.defaultActions`.
        ///
        /// You can provide custom actions with `EditingAction(title: "Highlight", action: #selector(highlight:))`.
        /// Then, implement the selector in one of your classes in the responder chain. Typically, in the
        /// `UIViewController` wrapping the `EPUBNavigatorViewController`.
        public var editingActions: [EditingAction]

        /// Content insets used to add some vertical margins around reflowable EPUB publications.
        /// The insets can be configured for each size class to allow smaller margins on compact
        /// screens.
        public var contentInset: [UIUserInterfaceSizeClass: EPUBContentInsets]

        /// Number of positions (as in `Publication.positionList`) to preload before the current page.
        public var preloadPreviousPositionCount: Int

        /// Number of positions (as in `Publication.positionList`) to preload after the current page.
        public var preloadNextPositionCount: Int

        /// Supported HTML decoration templates.
        public var decorationTemplates: [Decoration.Style.Id: HTMLDecorationTemplate]

        /// Additional font families which will be available in the preferences.
        public var fontFamilyDeclarations: [AnyHTMLFontFamilyDeclaration]

        /// Readium CSS reading system settings.
        ///
        /// See https://readium.org/readium-css/docs/CSS19-api.html#reading-system-styles
        public var readiumCSSRSProperties: CSSRSProperties

        /// Logs the state changes when true.
        public var debugState: Bool

        public init(
            preferences: EPUBPreferences = .empty,
            defaults: EPUBDefaults = EPUBDefaults(),
            editingActions: [EditingAction] = EditingAction.defaultActions,
            contentInset: [UIUserInterfaceSizeClass: EPUBContentInsets] = [
                .compact: (top: 20, bottom: 20),
                .regular: (top: 44, bottom: 44),
            ],
            preloadPreviousPositionCount: Int = 2,
            preloadNextPositionCount: Int = 6,
            decorationTemplates: [Decoration.Style.Id: HTMLDecorationTemplate] = HTMLDecorationTemplate.defaultTemplates(),
            fontFamilyDeclarations: [AnyHTMLFontFamilyDeclaration] = [],
            readiumCSSRSProperties: CSSRSProperties = CSSRSProperties(),
            debugState: Bool = false
        ) {
            self.preferences = preferences
            self.defaults = defaults
            self.editingActions = editingActions
            self.contentInset = contentInset
            self.preloadPreviousPositionCount = preloadPreviousPositionCount
            self.preloadNextPositionCount = preloadNextPositionCount
            self.decorationTemplates = decorationTemplates
            self.fontFamilyDeclarations = fontFamilyDeclarations
            self.readiumCSSRSProperties = readiumCSSRSProperties
            self.debugState = debugState
        }
    }

    public weak var delegate: EPUBNavigatorDelegate? {
        didSet { updateCurrentLocation() }
    }

    @available(*, unavailable, message: "See the 2.5.0 migration guide to migrate to the Preferences API")
    public var userSettings: Any { fatalError() }

    /// Navigation state.
    private enum State: Equatable {
        /// Initializing the navigator.
        case initializing
        /// Loading the spreads at the `pendingLocator`, for example after
        /// changing the user settings, rotating the screen or loading the
        /// publication.
        case loading(pendingLocator: Locator?)
        /// Waiting for further navigation instructions.
        case idle
        /// Jumping to `pendingLocator`.
        case jumping(pendingLocator: Locator)
        /// Turning the page in the given `direction`.
        case moving(direction: EPUBSpreadView.Direction)

        var pendingLocator: Locator? {
            switch self {
            case let .loading(pendingLocator: locator):
                return locator
            case let .jumping(pendingLocator: locator):
                return locator
            default:
                return nil
            }
        }

        mutating func transition(_ event: Event) -> Bool {
            switch (self, event) {
            // Loading the spreads is always possible, because it can be triggered by rotating the
            // screen. In which case it cancels any on-going state.
            case let (_, .load(locator)):
                self = .loading(pendingLocator: locator)

            // All events are ignored when loading spreads, except for `loaded` and `load`.
            case (.loading, .loaded):
                self = .idle
            case (.loading, _):
                return false

            case let (.idle, .jump(locator)):
                self = .jumping(pendingLocator: locator)
            case let (.idle, .move(direction)):
                self = .moving(direction: direction)

            case (.jumping, .jumped):
                self = .idle
            // Moving or jumping to another locator is not allowed during a pending jump.
            case (.jumping, .jump),
                 (.jumping, .move):
                return false

            case (.moving, .moved):
                self = .idle
            // Moving or jumping to another locator is not allowed during a pending move.
            case (.moving, .jump),
                 (.moving, .move):
                return false

            default:
                log(.error, "Invalid event \(event) for state \(self)")
                return false
            }

            return true
        }
    }

    /// Navigation event.
    private enum Event: Equatable {
        /// Load the spreads at the given locator, for example after changing
        /// the user settings, rotating the screen or loading the publication.
        case load(Locator?)
        /// The spreads were loaded.
        case loaded
        /// Jump to the given locator.
        case jump(Locator)
        /// Finished jumping to a locator.
        case jumped
        /// Turn the page in the given direction.
        case move(EPUBSpreadView.Direction)
        /// Finished turning the page.
        case moved
    }

    /// Current navigation state.
    private var state: State = .initializing {
        didSet {
            if config.debugState {
                log(.debug, "* \(state)")
            }

            // Disable user interaction while transitioning, to avoid UX issues.
            switch state {
            case .initializing, .loading, .jumping, .moving:
                paginationView.isUserInteractionEnabled = false
            case .idle:
                paginationView.isUserInteractionEnabled = true
            }
        }
    }

    private let readingOrder: [Link]
    public private(set) var currentLocation: Locator?
    private let loadPositionsByReadingOrder: () async -> ReadResult<[[Locator]]>
    private var positionsByReadingOrder: [[Locator]] = []
    private let tasks = CancellableTasks()

    private let viewModel: EPUBNavigatorViewModel
    public var publication: Publication { viewModel.publication }

    var config: Configuration { viewModel.config }

    /// Creates a new instance of `EPUBNavigatorViewController`.
    ///
    /// - Parameters:
    ///   - publication: EPUB publication to render.
    ///   - initialLocation: Starting location in the publication, defaults to
    ///   the beginning.
    ///   - readingOrder: Custom order of resources to display. Used for example
    ///   to display a non-linear resource on its own.
    ///   - config: Additional navigator configuration.
    ///   - httpServer: HTTP server used to serve the publication resources to
    ///   the web views.
    public convenience init(
        publication: Publication,
        initialLocation: Locator?,
        readingOrder: [Link]? = nil,
        config: Configuration = .init(),
        httpServer: HTTPServer
    ) throws {
        precondition(readingOrder.map { !$0.isEmpty } ?? true)

        guard !publication.isRestricted else {
            throw EPUBError.publicationRestricted
        }

        let viewModel = try EPUBNavigatorViewModel(
            publication: publication,
            config: config,
            httpServer: httpServer
        )

        self.init(
            viewModel: viewModel,
            initialLocation: initialLocation,
            readingOrder: readingOrder ?? publication.readingOrder,
            positionsByReadingOrder:
            // Positions and total progression only make sense in the context
            // of the publication's actual reading order. Therefore when
            // provided with a different reading order, we should assume the
            // positions list is empty, and also not compute the
            // totalProgression when calculating the current locator.
            (readingOrder != nil) ? { .success([]) } : publication.positionsByReadingOrder
        )
    }

    @available(*, unavailable, message: "See the 2.5.0 migration guide to migrate the HTTP server and settings API")
    public convenience init(
        publication: Publication,
        initialLocation: Locator? = nil,
        resourcesServer: ResourcesServer,
        config: Configuration = .init()
    ) {
        fatalError()
    }

    private init(
        viewModel: EPUBNavigatorViewModel,
        initialLocation: Locator?,
        readingOrder: [Link],
        positionsByReadingOrder: @escaping () async -> ReadResult<[[Locator]]>
    ) {
        self.viewModel = viewModel
        currentLocation = initialLocation
        self.readingOrder = readingOrder
        loadPositionsByReadingOrder = positionsByReadingOrder

        super.init(nibName: nil, bundle: nil)

        viewModel.delegate = self
        viewModel.editingActions.delegate = self
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func viewDidLoad() {
        super.viewDidLoad()

        // Will call `accessibilityScroll()` when VoiceOver reaches the end of
        // the current resource. We can use this to go to the next resource.
        view.accessibilityTraits.insert(.causesPageTurn)

        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapBackground)))

        tasks.add {
            await initialize()
        }
    }

    private func initialize() async {
        do {
            positionsByReadingOrder = try await loadPositionsByReadingOrder().get()
        } catch {
            log(.error, DebugError("Failed to load positions.", cause: error))
        }

        paginationView = makePaginationView(
            hasPositions: !positionsByReadingOrder.isEmpty
        )

        paginationView.frame = view.bounds
        paginationView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        view.addSubview(paginationView)

        applySettings()

        await reloadSpreads(at: currentLocation, force: false)

        onInitializedCallbacks.complete()
    }

    private let onInitializedCallbacks = CompletionList()

    private func initialized() async {
        await withCheckedContinuation { continuation in
            whenInitialized {
                continuation.resume()
            }
        }
    }

    private func whenInitialized(_ callback: @escaping () -> Void) {
        let callback = onInitializedCallbacks.add(callback)
        if state != .initializing {
            callback()
        }
    }

    @available(iOS 13.0, *)
    override open func buildMenu(with builder: UIMenuBuilder) {
        viewModel.editingActions.buildMenu(with: builder)
        super.buildMenu(with: builder)
    }

    /// Intercepts tap gesture when the web views are not loaded.
    @objc private func didTapBackground(_ gesture: UITapGestureRecognizer) {
        didTap(at: gesture.location(in: view))
    }

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.viewSizeWillChange(view.bounds.size)
    }

    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        viewModel.viewSizeWillChange(size)

        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            Task {
                await self?.reloadSpreads(force: false)
            }
        }
    }

    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        becomeFirstResponder()
    }

    override open var canBecomeFirstResponder: Bool { true }

    override open func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var didHandleEvent = false
        if isFirstResponder {
            for press in presses {
                if let event = KeyEvent(uiPress: press) {
                    didPressKey(event)
                    didHandleEvent = true
                }
            }
        }

        if !didHandleEvent {
            super.pressesBegan(presses, with: event)
        }
    }

    override open func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var didHandleEvent = false
        if isFirstResponder {
            for press in presses {
                if let event = KeyEvent(uiPress: press) {
                    delegate?.navigator(self, didReleaseKey: event)
                    didHandleEvent = true
                }
            }
        }

        if !didHandleEvent {
            super.pressesEnded(presses, with: event)
        }
    }

    @discardableResult
    private func on(_ event: Event) -> Bool {
        assert(Thread.isMainThread, "Raising navigation events must be done from the main thread")

        if config.debugState {
            log(.debug, "-> on \(event)")
        }

        return state.transition(event)
    }

    /// Mapping between reading order hrefs and the table of contents title.
    private lazy var tableOfContentsTitleByHref: [AnyURL: String] = {
        func fulfill(linkList: [Link]) -> [AnyURL: String] {
            var result = [AnyURL: String]()

            for link in linkList {
                if let title = link.title {
                    result[link.url()] = title
                }
                let subResult = fulfill(linkList: link.children)
                result.merge(subResult) { current, _ -> String in
                    current
                }
            }
            return result
        }

        return fulfill(linkList: publication.tableOfContents)
    }()

    /// Goes to the next or previous page in the given scroll direction.
    private func go(to direction: EPUBSpreadView.Direction, options: NavigatorGoOptions) async -> Bool {
        guard on(.move(direction)) else {
            return false
        }

        if
            let spreadView = paginationView.currentView as? EPUBSpreadView,
            await spreadView.go(to: direction, options: options)
        {
            on(.moved)
            return true
        }

        let isRTL = (viewModel.readingProgression == .rtl)
        let delta = isRTL ? -1 : 1
        let moved: Bool = await {
            switch direction {
            case .left:
                let location: PageLocation = isRTL ? .start : .end
                return await paginationView.goToIndex(currentSpreadIndex - delta, location: location, options: options)
            case .right:
                let location: PageLocation = isRTL ? .end : .start
                return await paginationView.goToIndex(currentSpreadIndex + delta, location: location, options: options)
            }
        }()

        on(.moved)
        return moved
    }

    @available(*, unavailable, message: "See the 2.5.0 migration guide to migrate to the Preferences API")
    public func updateUserSettingStyle() {}

    // MARK: - Pagination and spreads

    private var paginationView: PaginationView!

    private func makePaginationView(hasPositions: Bool) -> PaginationView {
        let view = PaginationView(
            frame: .zero,
            preloadPreviousPositionCount: hasPositions ? config.preloadPreviousPositionCount : 0,
            preloadNextPositionCount: hasPositions ? config.preloadNextPositionCount : 0
        )
        view.delegate = self
        view.backgroundColor = .clear
        return view
    }

    private var spreads: [EPUBSpread] = []

    /// Index of the currently visible spread.
    private var currentSpreadIndex: Int {
        paginationView.currentIndex
    }

    // Reading order index of the left-most resource in the visible spread.
    private var currentResourceIndex: Int? {
        guard spreads.indices.contains(currentSpreadIndex) else {
            return nil
        }

        return readingOrder.firstIndexWithHREF(spreads[currentSpreadIndex].left.url())
    }

    private var reloadSpreadsContinuations = [CheckedContinuation<Void, Never>]()
    private var needsReloadSpreads = false

    @MainActor
    private func reloadSpreads(at locator: Locator? = nil, force: Bool) async {
        guard isViewLoaded else {
            return
        }
        guard !needsReloadSpreads else {
            await withCheckedContinuation { continuation in
                reloadSpreadsContinuations.append(continuation)
            }
            return
        }

        needsReloadSpreads = true

        await _reloadSpreads(at: locator, force: force)
        for continuation in reloadSpreadsContinuations {
            continuation.resume()
        }
        reloadSpreadsContinuations.removeAll()

        needsReloadSpreads = false
    }

    private func _reloadSpreads(at locator: Locator? = nil, force: Bool) async {
        let locator = locator ?? currentLocation

        guard
            // Already loaded with the expected amount of spreads?
            force || spreads.first?.spread != viewModel.spreadEnabled,
            on(.load(locator))
        else {
            return
        }

        spreads = EPUBSpread.makeSpreads(
            for: publication,
            readingOrder: readingOrder,
            readingProgression: viewModel.readingProgression,
            spread: viewModel.spreadEnabled
        )

        let initialIndex: Int = {
            if let href = locator?.href, let foundIndex = self.spreads.firstIndexWithHREF(href) {
                return foundIndex
            } else {
                return 0
            }
        }()

        await paginationView.reloadAtIndex(
            initialIndex,
            location: PageLocation(locator),
            pageCount: spreads.count,
            readingProgression: viewModel.readingProgression
        )
        on(.loaded)
    }

    private func loadedSpreadViewForHREF<T: URLConvertible>(_ href: T) -> EPUBSpreadView? {
        paginationView.loadedViews
            .compactMap { _, view in view as? EPUBSpreadView }
            .first { $0.spread.links.firstWithHREF(href) != nil }
    }

    // MARK: - Navigator

    public var presentation: VisualNavigatorPresentation {
        VisualNavigatorPresentation(
            readingProgression: settings.readingProgression,
            scroll: settings.scroll,
            axis: (settings.scroll && !settings.verticalText)
                ? .vertical
                : .horizontal
        )
    }

    private func computeCurrentLocation() async -> Locator? {
        if case .initializing = state {
            assertionFailure("Cannot update current location when initializing the navigator")
            return nil
        }

        // Returns any pending locator to prevent returning invalid locations
        // while loading it.
        if let pendingLocator = state.pendingLocator {
            return pendingLocator
        }

        guard let spreadView = paginationView.currentView as? EPUBSpreadView else {
            return nil
        }

        let link = spreadView.focusedResource ?? spreadView.spread.leading
        let href = link.url()
        let progression = min(max(spreadView.progression(in: href), 0.0), 1.0)

        if
            // The positions are not always available, for example a Readium
            // WebPub doesn't have any unless a Publication Positions Web
            // Service is provided
            let index = readingOrder.firstIndexWithHREF(href),
            let positionList = positionsByReadingOrder.getOrNil(index),
            positionList.count > 0
        {
            // Gets the current locator from the positionList, and fill its missing data.
            let positionIndex = Int(ceil(progression * Double(positionList.count - 1)))
            return positionList[positionIndex].copy(
                title: tableOfContentsTitleByHref[equivalent: href],
                locations: { $0.progression = progression }
            )
        } else {
            return await publication.locate(link)?.copy(
                locations: { $0.progression = progression }
            )
        }
    }

    public func firstVisibleElementLocator() async -> Locator? {
        guard let spreadView = paginationView.currentView as? EPUBSpreadView else {
            return nil
        }
        return await spreadView.findFirstVisibleElementLocator()
    }

    /// Last current location notified to the delegate.
    /// Used to avoid sending twice the same location.
    private var notifiedCurrentLocation: Locator?

    private lazy var updateCurrentLocation = execute(
        // If we're not in an `idle` state, we postpone the notification.
        when: { [weak self] in self?.state == .idle },
        pollingInterval: 0.1
    ) { [weak self] in
        guard let self = self else {
            return
        }

        currentLocation = await computeCurrentLocation()

        if
            let delegate = delegate,
            let location = currentLocation,
            location != notifiedCurrentLocation
        {
            notifiedCurrentLocation = location
            delegate.navigator(self, locationDidChange: location)
        }
    }

    public func go(to locator: Locator, options: NavigatorGoOptions) async -> Bool {
        let locator = publication.normalizeLocator(locator)

        guard
            let spreadIndex = spreads.firstIndexWithHREF(locator.href),
            on(.jump(locator))
        else {
            return false
        }

        let success = await paginationView.goToIndex(spreadIndex, location: .locator(locator), options: options)
        on(.jumped)
        if success {
            delegate?.navigator(self, didJumpTo: locator)
        }
        return success
    }

    public func go(to link: Link, options: NavigatorGoOptions) async -> Bool {
        guard let locator = await publication.locate(link) else {
            return false
        }
        return await go(to: locator, options: options)
    }

    @discardableResult
    public func goForward(options: NavigatorGoOptions) async -> Bool {
        let direction: EPUBSpreadView.Direction = {
            switch viewModel.readingProgression {
            case .ltr:
                return .right
            case .rtl:
                return .left
            }
        }()
        return await go(to: direction, options: options)
    }

    @discardableResult
    public func goBackward(options: NavigatorGoOptions) async -> Bool {
        let direction: EPUBSpreadView.Direction = {
            switch viewModel.readingProgression {
            case .ltr:
                return .left
            case .rtl:
                return .right
            }
        }()
        return await go(to: direction, options: options)
    }

    // MARK: - SelectableNavigator

    public var currentSelection: Selection? {
        viewModel.editingActions.selection
    }

    public func clearSelection() {
        for (_, pageView) in paginationView.loadedViews {
            (pageView as? EPUBSpreadView)?.webView.clearSelection()
        }
    }

    // MARK: - DecorableNavigator

    private var decorations: [String: [DiffableDecoration]] = [:]

    /// Decoration group callbacks, indexed by the group name.
    private var decorationCallbacks: [String: [DecorableNavigator.OnActivatedCallback]] = [:]

    public func supports(decorationStyle style: Decoration.Style.Id) -> Bool {
        config.decorationTemplates.keys.contains(style)
    }

    public func apply(decorations: [Decoration], in group: String) {
        Task {
            await initialized()

            await withTaskGroup(of: Void.self) { tasks in
                let source = self.decorations[group] ?? []
                let target = decorations.map {
                    var d = $0
                    d.locator = publication.normalizeLocator(d.locator)
                    return DiffableDecoration(decoration: d)
                }
                self.decorations[group] = target

                if decorations.isEmpty {
                    for (_, pageView) in paginationView.loadedViews {
                        tasks.addTask {
                            await (pageView as? EPUBSpreadView)?.evaluateScript(
                                // The updates command are using `requestAnimationFrame()`, so we need it for
                                // `clear()` as well otherwise we might recreate a highlight after it has been
                                // cleared.
                                "requestAnimationFrame(function () { readium.getDecorations('\(group)').clear(); });"
                            )
                        }
                    }
                } else {
                    for (href, changes) in target.changesByHREF(from: source) {
                        guard let script = changes.javascript(forGroup: group, styles: config.decorationTemplates) else {
                            continue
                        }
                        tasks.addTask { [weak self] in
                            await self?.loadedSpreadViewForHREF(href)?.evaluateScript(script, inHREF: href)
                        }
                    }
                }
            }
        }
    }

    public func observeDecorationInteractions(inGroup group: String, onActivated: @escaping OnActivatedCallback) {
        var callbacks = decorationCallbacks[group] ?? []
        callbacks.append(onActivated)
        decorationCallbacks[group] = callbacks

        Task {
            await initialized()

            await withTaskGroup(of: Void.self) { tasks in
                for (_, view) in paginationView.loadedViews {
                    tasks.addTask {
                        await (view as? EPUBSpreadView)?.evaluateScript("readium.getDecorations('\(group)').setActivable();")
                    }
                }
            }
        }
    }

    // MARK: - Configurable

    public var settings: EPUBSettings { viewModel.settings }

    public func submitPreferences(_ preferences: EPUBPreferences) {
        viewModel.submitPreferences(preferences)
        applySettings()

        delegate?.navigator(self, presentationDidChange: presentation)
    }

    public func editor(of preferences: EPUBPreferences) -> EPUBPreferencesEditor {
        viewModel.editor(of: preferences)
    }

    /// Applies user settings that require native configuration instead of
    /// CSS properties.
    private func applySettings() {
        guard isViewLoaded else {
            return
        }

        view.backgroundColor = settings.effectiveBackgroundColor.uiColor
    }

    // MARK: - User interactions

    private func didTap(at point: CGPoint) {
        delegate?.navigator(self, didTapAt: point)
    }

    private func didPressKey(_ event: KeyEvent) {
        delegate?.navigator(self, didPressKey: event)
    }

    // MARK: - EPUB-specific extensions

    /// Evaluates the given JavaScript on the currently visible HTML resource.
    @discardableResult
    public func evaluateJavaScript(_ script: String) async -> Result<Any, Error> {
        guard let spreadView = paginationView.currentView as? EPUBSpreadView else {
            return .failure(EPUBError.spreadNotLoaded)
        }
        return await spreadView.evaluateScript(script)
    }

    @available(*, unavailable, message: "Use the async variant")
    public func evaluateJavaScript(_ script: String, completion: ((Result<Any, Error>) -> Void)? = nil) {
        fatalError()
    }

    // MARK: - UIAccessibilityAction

    override open func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        guard !super.accessibilityScroll(direction) else {
            return true
        }

        let options = NavigatorGoOptions(animated: false)

        Task {
            switch direction {
            case .right:
                await goLeft(options: options)
            case .left:
                await goRight(options: options)
            case .next, .down:
                await goForward(options: options)
            case .previous, .up:
                await goBackward(options: options)
            @unknown default:
                break
            }
        }
        return true
    }
}

extension EPUBNavigatorViewController: EPUBNavigatorViewModelDelegate {
    func epubNavigatorViewModelInvalidatePaginationView(_ viewModel: EPUBNavigatorViewModel) {
        Task {
            await reloadSpreads(force: true)
        }
    }

    func epubNavigatorViewModel(_ viewModel: EPUBNavigatorViewModel, runScript script: String, in scope: EPUBScriptScope) {
        Task {
            switch scope {
            case .currentResource:
                await (paginationView.currentView as? EPUBSpreadView)?.evaluateScript(script)

            case .loadedResources:
                await withTaskGroup(of: Void.self) { tasks in
                    for (_, view) in paginationView.loadedViews {
                        tasks.addTask {
                            await (view as? EPUBSpreadView)?.evaluateScript(script)
                        }
                    }
                }

            case let .resource(href):
                for (_, view) in paginationView.loadedViews {
                    guard
                        let view = view as? EPUBSpreadView,
                        view.spread.links.firstWithHREF(href) != nil
                    else {
                        continue
                    }
                    await view.evaluateScript(script, inHREF: href)
                    return
                }
            }
        }
    }

    func epubNavigatorViewModel(
        _ viewModel: EPUBNavigatorViewModel,
        didFailToLoadResourceAt href: RelativeURL,
        withError error: ReadError
    ) {
        DispatchQueue.main.async {
            self.delegate?.navigator(self, didFailToLoadResourceAt: href, withError: error)
        }
    }
}

extension EPUBNavigatorViewController: EPUBSpreadViewDelegate {
    func spreadViewDidLoad(_ spreadView: EPUBSpreadView) {
        Task {
            let templates = config.decorationTemplates.reduce(into: [:]) { styles, item in
                styles[item.key.rawValue] = item.value.json
            }

            guard let stylesJSON = serializeJSONString(templates) else {
                log(.error, "Can't serialize decoration styles to JSON")
                return
            }
            var script = "readium.registerDecorationTemplates(\(stylesJSON.replacingOccurrences(of: "\\n", with: " ")));\n"

            script += decorationCallbacks
                .compactMap { group, callbacks in
                    guard !callbacks.isEmpty else {
                        return nil
                    }
                    return "readium.getDecorations('\(group)').setActivable();"
                }
                .joined(separator: "\n")

            await spreadView.evaluateScript("(function() {\n\(script)\n})();")

            await withTaskGroup(of: Void.self) { tasks in
                for link in spreadView.spread.links {
                    let href = link.url()
                    for (group, decorations) in self.decorations {
                        let decorations = decorations
                            .filter { $0.decoration.locator.href.isEquivalentTo(href) }
                            .map { DecorationChange.add($0.decoration) }

                        guard let script = decorations.javascript(forGroup: group, styles: self.config.decorationTemplates) else {
                            continue
                        }
                        tasks.addTask {
                            await spreadView.evaluateScript(script, inHREF: href)
                        }
                    }
                }
            }
        }
    }

    func spreadView(_ spreadView: EPUBSpreadView, didTapAt point: CGPoint) {
        // We allow taps in any state, because we should always be able to toggle the navigation bar,
        // even while a locator is pending.

        didTap(at: view.convert(point, from: spreadView))

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

    func spreadView(_ spreadView: EPUBSpreadView, didPressKey event: KeyEvent) {
        didPressKey(event)
    }

    func spreadView(_ spreadView: EPUBSpreadView, didReleaseKey event: KeyEvent) {
        delegate?.navigator(self, didReleaseKey: event)
    }

    func spreadView(_ spreadView: EPUBSpreadView, didTapOnExternalURL url: URL) {
        guard state == .idle else { return }

        delegate?.navigator(self, presentExternalURL: url)
    }

    func spreadView(_ spreadView: EPUBSpreadView, didTapOnInternalLink href: String, clickEvent: ClickEvent?) {
        guard
            let url = AnyURL(string: href),
            var link = publication.linkWithHREF(url)
        else {
            log(.warning, "Cannot find link with HREF: \(href)")
            return
        }
        link.href = href

        // Check to see if this was a noteref link and give delegate the opportunity to display it.
        if
            let clickEvent = clickEvent,
            let interactive = clickEvent.interactiveElement,
            let (note, referrer) = getNoteData(anchor: interactive, href: href),
            let delegate = delegate
        {
            if !delegate.navigator(
                self,
                shouldNavigateToNoteAt: link,
                content: note,
                referrer: referrer
            ) {
                return
            }
        }

        // Ask if we should navigate to the link
        if let delegate = delegate, !delegate.navigator(self, shouldNavigateToLink: link) {
            return
        }

        Task {
            await go(to: link)
        }
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
            guard href.hasSuffix(anchorHref) else { return nil }

            let hashParts = href.split(separator: "#")
            guard hashParts.count == 2 else {
                log(.warning, "Could not find hash in link \(href)")
                return nil
            }
            let id = String(hashParts[1])
            var withoutFragment = String(hashParts[0])
            if withoutFragment.hasPrefix("/") {
                withoutFragment = String(withoutFragment.dropFirst())
            }

            guard
                let url = RelativeURL(string: withoutFragment),
                let absolute = viewModel.publicationBaseURL.resolve(url)
            else {
                log(.warning, "Invalid URL: \(withoutFragment)")
                return nil
            }

            log(.debug, "Fetching note contents from \(absolute.string)")
            let contents = try String(contentsOf: absolute.url)
            let document = try parse(contents)

            guard let aside = try document.select("#\(id)").first() else {
                log(.warning, "Could not find the element '#\(id)' in document \(absolute)")
                return nil
            }

            return try (aside.html(), link.html())

        } catch {
            log(.warning, "Caught error while getting note content: \(error)")
            return nil
        }
    }

    func spreadView(_ spreadView: EPUBSpreadView, didActivateDecoration id: Decoration.Id, inGroup group: String, frame: CGRect?, point: CGPoint?) {
        guard
            let callbacks = decorationCallbacks[group].takeIf({ !$0.isEmpty }),
            let decoration: Decoration = decorations[group]?
            .first(where: { $0.decoration.id == id })
            .map(\.decoration)
        else {
            return
        }

        for callback in callbacks {
            callback(OnDecorationActivatedEvent(decoration: decoration, group: group, rect: frame, point: point))
        }
    }

    func spreadView(_ spreadView: EPUBSpreadView, selectionDidChange text: Locator.Text?, frame: CGRect) {
        guard
            let locator = currentLocation,
            let text = text
        else {
            viewModel.editingActions.selection = nil
            return
        }
        viewModel.editingActions.selection = Selection(
            locator: locator.copy(text: { $0 = text }),
            frame: frame
        )
    }

    func spreadViewPagesDidChange(_ spreadView: EPUBSpreadView) {
        if paginationView.currentView == spreadView {
            updateCurrentLocation()
        }
    }

    func spreadView(_ spreadView: EPUBSpreadView, present viewController: UIViewController) {
        present(viewController, animated: true)
    }

    func spreadViewDidTerminate() {
        Task {
            await reloadSpreads(force: true)
        }
    }
}

extension EPUBNavigatorViewController: EditingActionsControllerDelegate {
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

extension EPUBNavigatorViewController: PaginationViewDelegate {
    func paginationView(_ paginationView: PaginationView, pageViewAtIndex index: Int) -> (UIView & PageView)? {
        let spread = spreads[index]
        let spreadViewType = (spread.layout == .fixed) ? EPUBFixedSpreadView.self : EPUBReflowableSpreadView.self
        let spreadView = spreadViewType.init(
            viewModel: viewModel,
            spread: spread,
            scripts: [],
            animatedLoad: false
        )
        spreadView.delegate = self

        let userContentController = spreadView.webView.configuration.userContentController
        delegate?.navigator(self, setupUserScripts: userContentController)

        return spreadView
    }

    func paginationViewDidUpdateViews(_ paginationView: PaginationView) {
        // notice that you should set the delegate before you load views
        // otherwise, when open the publication, you may miss the first invocation
        updateCurrentLocation()
    }

    func paginationView(_ paginationView: PaginationView, positionCountAtIndex index: Int) -> Int {
        spreads[index].positionCount(in: readingOrder, positionsByReadingOrder: positionsByReadingOrder)
    }
}
