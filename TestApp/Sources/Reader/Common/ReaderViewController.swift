//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import R2Navigator
import R2Shared
import SafariServices
import SwiftSoup
import SwiftUI
import UIKit
import WebKit

/// This class is meant to be subclassed by each publication format view controller. It contains the shared behavior, eg. navigation bar toggling.
class ReaderViewController<N: UIViewController & Navigator>: UIViewController, UIPopoverPresentationControllerDelegate, Loggable {
    weak var moduleDelegate: ReaderFormatModuleDelegate?

    let navigator: N
    let publication: Publication
    let bookId: Book.Id
    private let books: BookRepository
    private let bookmarks: BookmarkRepository
    private let highlights: HighlightRepository?

    private(set) var stackView: UIStackView!
    private lazy var positionLabel = UILabel()
    private var subscriptions = Set<AnyCancellable>()

    private var searchViewModel: SearchViewModel?
    private var searchViewController: UIHostingController<SearchView>?

    private let ttsViewModel: TTSViewModel?
    private let ttsControlsViewController: UIHostingController<TTSControls>?

    /// This regex matches any string with at least 2 consecutive letters (not limited to ASCII).
    /// It's used when evaluating whether to display the body of a noteref referrer as the note's title.
    /// I.e. a `*` or `1` would not be used as a title, but `on` or `好書` would.
    private lazy var noterefTitleRegex: NSRegularExpression =
        try! NSRegularExpression(pattern: "[\\p{Ll}\\p{Lu}\\p{Lt}\\p{Lo}]{2}")

    private var highlightContextMenu: UIHostingController<HighlightContextMenu>?
    private let highlightDecorationGroup = "highlights"
    private var currentHighlightCancellable: AnyCancellable?

    init(navigator: N, publication: Publication, bookId: Book.Id, books: BookRepository, bookmarks: BookmarkRepository, highlights: HighlightRepository? = nil) {
        self.navigator = navigator
        self.publication = publication
        self.bookId = bookId
        self.books = books
        self.bookmarks = bookmarks
        self.highlights = highlights

        ttsViewModel = TTSViewModel(navigator: navigator, publication: publication)
        ttsControlsViewController = ttsViewModel.map { UIHostingController(rootView: TTSControls(viewModel: $0)) }

        super.init(nibName: nil, bundle: nil)

        addHighlightDecorationsObserverOnce()
        updateHighlightDecorations()

        NotificationCenter.default.addObserver(self, selector: #selector(voiceOverStatusDidChange), name: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white

        navigationItem.rightBarButtonItems = makeNavigationBarButtons()
        fixTranparentNavigationBar()
        updateNavigationBar(animated: false)

        stackView = UIStackView(frame: view.bounds)
        stackView.distribution = .fill
        stackView.axis = .vertical
        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        let topConstraint = stackView.topAnchor.constraint(equalTo: view.topAnchor)
        // `accessibilityTopMargin` takes precedence when VoiceOver is enabled.
        topConstraint.priority = .defaultHigh
        NSLayoutConstraint.activate([
            topConstraint,
            stackView.rightAnchor.constraint(equalTo: view.rightAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.leftAnchor.constraint(equalTo: view.leftAnchor),
        ])

        addChild(navigator)
        stackView.addArrangedSubview(navigator.view)
        navigator.didMove(toParent: self)

        stackView.addArrangedSubview(accessibilityToolbar)

        positionLabel.translatesAutoresizingMaskIntoConstraints = false
        positionLabel.font = .systemFont(ofSize: 12)
        positionLabel.textColor = .darkGray
        view.addSubview(positionLabel)
        NSLayoutConstraint.activate([
            positionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            positionLabel.bottomAnchor.constraint(equalTo: navigator.view.bottomAnchor, constant: -20),
        ])

        if let state = ttsViewModel?.$state, let controls = ttsControlsViewController {
            controls.view.backgroundColor = .clear

            addChild(controls)
            controls.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(controls.view)
            NSLayoutConstraint.activate([
                controls.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                controls.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            ])
            controls.didMove(toParent: self)

            state
                .sink { state in
                    controls.view.isHidden = !state.showControls
                }
                .store(in: &subscriptions)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        ttsViewModel?.stop()
    }

    // MARK: - Navigation bar

    private var navigationBarHidden: Bool = true {
        didSet {
            updateNavigationBar()
        }
    }

    func makeNavigationBarButtons() -> [UIBarButtonItem] {
        var buttons: [UIBarButtonItem] = []
        // Table of Contents
        buttons.append(UIBarButtonItem(image: #imageLiteral(resourceName: "menuIcon"), style: .plain, target: self, action: #selector(presentOutline)))

        // User preferences
        buttons.append(UIBarButtonItem(image: UIImage(systemName: "gearshape"), style: .plain, target: self, action: #selector(presentUserPreferences)))

        // DRM management
        if publication.isProtected {
            buttons.append(UIBarButtonItem(image: #imageLiteral(resourceName: "drm"), style: .plain, target: self, action: #selector(presentDRMManagement)))
        }
        // Bookmarks
        buttons.append(UIBarButtonItem(image: #imageLiteral(resourceName: "bookmark"), style: .plain, target: self, action: #selector(bookmarkCurrentPosition)))
        // Search
        if publication._isSearchable {
            buttons.append(UIBarButtonItem(image: UIImage(systemName: "magnifyingglass"), style: .plain, target: self, action: #selector(showSearchUI)))
        }
        // Text to speech
        if let ttsViewModel = ttsViewModel {
            buttons.append(UIBarButtonItem(image: UIImage(systemName: "speaker.wave.2.fill"), style: .plain, target: ttsViewModel, action: #selector(TTSViewModel.start)))
        }

        return buttons
    }

    func toggleNavigationBar() {
        navigationBarHidden = !navigationBarHidden
    }

    /// Since iOS 15, UIKit bars are transparent by default. As the navigators
    /// display content under the navigation bar, this is undesirable in most
    /// cases.
    ///
    /// For more information, take a look at:
    /// https://pspdfkit.com/guides/ios/troubleshooting/user-interface/transparent-bar-backgrounds
    func fixTranparentNavigationBar() {
        if #available(iOS 15.0, *), let navBar = navigationController?.navigationBar {
            let defaultAppearance = UINavigationBarAppearance()
            navBar.standardAppearance = defaultAppearance
            navBar.compactAppearance = defaultAppearance
            navBar.scrollEdgeAppearance = defaultAppearance
        }
    }

    func updateNavigationBar(animated: Bool = true) {
        let hidden = navigationBarHidden && !UIAccessibility.isVoiceOverRunning
        navigationController?.setNavigationBarHidden(hidden, animated: animated)
        setNeedsStatusBarAppearanceUpdate()
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        .slide
    }

    override var prefersStatusBarHidden: Bool {
        navigationBarHidden && !UIAccessibility.isVoiceOverRunning
    }

    // MARK: - Locations

    // FIXME: This should be implemented in a shared Navigator interface, using Locators.

    var currentBookmark: Bookmark? {
        fatalError("Not implemented")
    }

    // MARK: - Outlines

    @objc func presentOutline() {
        guard let locatorPublisher = moduleDelegate?.presentOutline(of: publication, bookId: bookId, from: self) else {
            return
        }

        locatorPublisher
            .sink(receiveValue: { [weak self] locator in
                self?.navigator.go(to: locator, animated: false) {
                    self?.dismiss(animated: true)
                }
            })
            .store(in: &subscriptions)
    }

    // MARK: - User Preferences

    @objc func presentUserPreferences() {}

    // MARK: - Bookmarks

    @objc func bookmarkCurrentPosition() {
        guard let bookmark = currentBookmark else {
            return
        }

        Task {
            do {
                try await bookmarks.add(bookmark)
                toast(NSLocalizedString("reader_bookmark_success_message", comment: "Success message when adding a bookmark"), on: self.view, duration: 1)
            } catch {
                print(error)
                toast(NSLocalizedString("reader_bookmark_failure_message", comment: "Error message when adding a new bookmark failed"), on: self.view, duration: 2)
            }
        }
    }

    // MARK: - Search

    @objc func showSearchUI() {
        if searchViewModel == nil {
            searchViewModel = SearchViewModel(publication: publication)
            searchViewModel?.$selectedLocator.sink(receiveValue: { [weak self] locator in
                self?.searchViewController?.dismiss(animated: true, completion: nil)
                if let self = self, let locator = locator {
                    self.navigator.go(to: locator, animated: true) {
                        if let decorator = self.navigator as? DecorableNavigator {
                            let decoration = Decoration(id: "selectedSearchResult", locator: locator, style: Decoration.Style.highlight(tint: .yellow, isActive: false))
                            decorator.apply(decorations: [decoration], in: "search")
                        }
                    }
                }
            }).store(in: &subscriptions)
        }

        let searchView = SearchView(viewModel: searchViewModel!)
        let vc = UIHostingController(rootView: searchView)
        vc.modalPresentationStyle = .pageSheet
        present(vc, animated: true, completion: nil)
        searchViewController = vc
    }

    // MARK: - Highlights

    private func addHighlightDecorationsObserverOnce() {
        if highlights == nil { return }

        if let decorator = navigator as? DecorableNavigator {
            decorator.observeDecorationInteractions(inGroup: highlightDecorationGroup) { [weak self] event in
                self?.activateDecoration(event)
            }
        }
    }

    private func updateHighlightDecorations() {
        guard let highlights = highlights else { return }

        highlights.all(for: bookId)
            .assertNoFailure()
            .sink { [weak self] highlights in
                if let self = self, let decorator = self.navigator as? DecorableNavigator {
                    let decorations = highlights.map { Decoration(id: $0.id, locator: $0.locator, style: .highlight(tint: $0.color.uiColor, isActive: false)) }
                    decorator.apply(decorations: decorations, in: self.highlightDecorationGroup)
                }
            }
            .store(in: &subscriptions)
    }

    private func activateDecoration(_ event: OnDecorationActivatedEvent) {
        guard let highlights = highlights else { return }

        currentHighlightCancellable = highlights.highlight(for: event.decoration.id).sink { _ in
        } receiveValue: { [weak self] highlight in
            guard let self = self else { return }
            self.activateDecoration(for: highlight, on: event)
        }
    }

    private func activateDecoration(for highlight: Highlight, on event: OnDecorationActivatedEvent) {
        if highlightContextMenu != nil {
            highlightContextMenu?.removeFromParent()
        }

        let menuView = HighlightContextMenu(colors: [.red, .green, .blue, .yellow],
                                            systemFontSize: 20)

        menuView.selectedColorPublisher.sink { [weak self] color in
            self?.currentHighlightCancellable?.cancel()
            self?.updateHighlight(event.decoration.id, withColor: color)
            self?.highlightContextMenu?.dismiss(animated: true, completion: nil)
        }
        .store(in: &subscriptions)

        menuView.selectedDeletePublisher.sink { [weak self] _ in
            self?.currentHighlightCancellable?.cancel()
            self?.deleteHighlight(event.decoration.id)
            self?.highlightContextMenu?.dismiss(animated: true, completion: nil)
        }
        .store(in: &subscriptions)

        highlightContextMenu = UIHostingController(rootView: menuView)

        highlightContextMenu!.preferredContentSize = menuView.preferredSize
        highlightContextMenu!.modalPresentationStyle = .popover

        if let popoverController = highlightContextMenu!.popoverPresentationController {
            popoverController.permittedArrowDirections = .down
            popoverController.sourceRect = event.rect ?? .zero
            popoverController.sourceView = view
            popoverController.backgroundColor = .cyan
            popoverController.delegate = self
            present(highlightContextMenu!, animated: true, completion: nil)
        }
    }

    // MARK: - DRM

    @objc func presentDRMManagement() {
        guard publication.isProtected else {
            return
        }
        moduleDelegate?.presentDRM(for: publication, from: self)
    }

    // MARK: - Accessibility

    /// Constraint used to shift the content under the navigation bar, since it is always visible when VoiceOver is running.
    private lazy var accessibilityTopMargin: NSLayoutConstraint = self.stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)

    private lazy var accessibilityToolbar: UIToolbar = {
        func makeItem(_ item: UIBarButtonItem.SystemItem, label: String? = nil, action: UIKit.Selector? = nil) -> UIBarButtonItem {
            let button = UIBarButtonItem(barButtonSystemItem: item, target: (action != nil) ? self : nil, action: action)
            button.accessibilityLabel = label
            return button
        }

        let toolbar = UIToolbar(frame: .zero)
        toolbar.items = [
            makeItem(.flexibleSpace),
            makeItem(.rewind, label: NSLocalizedString("reader_backward_a11y_label", comment: "Accessibility label to go backward in the publication"), action: #selector(goBackward)),
            makeItem(.flexibleSpace),
            makeItem(.fastForward, label: NSLocalizedString("reader_forward_a11y_label", comment: "Accessibility label to go forward in the publication"), action: #selector(goForward)),
            makeItem(.flexibleSpace),
        ]
        toolbar.isHidden = !UIAccessibility.isVoiceOverRunning
        return toolbar
    }()

    private var isVoiceOverRunning = UIAccessibility.isVoiceOverRunning

    @objc private func voiceOverStatusDidChange() {
        let isRunning = UIAccessibility.isVoiceOverRunning
        // Avoids excessive settings refresh when the status didn't change.
        guard isVoiceOverRunning != isRunning else {
            return
        }
        isVoiceOverRunning = isRunning
        accessibilityTopMargin.isActive = isRunning
        accessibilityToolbar.isHidden = !isRunning
        updateNavigationBar()
    }

    @objc private func goBackward() {
        navigator.goBackward()
    }

    @objc private func goForward() {
        navigator.goForward()
    }

    // MARK: - UIPopoverPresentationControllerDelegate

    // Prevent the popOver to be presented fullscreen on iPhones.
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        .none
    }
}

extension ReaderViewController: NavigatorDelegate {
    func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
        Task {
            do {
                try await books.saveProgress(for: bookId, locator: locator)
            } catch {
                moduleDelegate?.presentError(error, from: self)
            }
        }

        positionLabel.text = {
            if let position = locator.locations.position {
                return "\(position) / \(publication.positions.count)"
            } else if let progression = locator.locations.totalProgression {
                return "\(progression)%"
            } else {
                return nil
            }
        }()
    }

    func navigator(_ navigator: Navigator, presentExternalURL url: URL) {
        // SFSafariViewController crashes when given an URL without an HTTP scheme.
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            return
        }
        present(SFSafariViewController(url: url), animated: true)
    }

    func navigator(_ navigator: Navigator, presentError error: NavigatorError) {
        moduleDelegate?.presentError(error, from: self)
    }

    func navigator(_ navigator: Navigator, shouldNavigateToNoteAt link: R2Shared.Link, content: String, referrer: String?) -> Bool {
        var title = referrer
        if let t = title {
            title = try? clean(t, .none())
        }
        if !suitableTitle(title) {
            title = nil
        }

        let content = (try? clean(content, .none())) ?? ""
        let page =
            """
            <html>
                <head>
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                </head>
                <body>
                    \(content)
                </body>
            </html>
            """

        let wk = WKWebView()
        wk.loadHTMLString(page, baseURL: nil)

        let vc = UIViewController()
        vc.view = wk
        vc.navigationItem.title = title
        vc.navigationItem.leftBarButtonItem = BarButtonItem(barButtonSystemItem: .done, actionHandler: { _ in
            vc.dismiss(animated: true, completion: nil)
        })

        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true, completion: nil)

        return false
    }

    /// Checks to ensure the title is non-nil and contains at least 2 letters.
    func suitableTitle(_ title: String?) -> Bool {
        guard let title = title else { return false }
        let range = NSRange(location: 0, length: title.utf16.count)
        let match = noterefTitleRegex.firstMatch(in: title, range: range)
        return match != nil
    }
}

extension ReaderViewController: VisualNavigatorDelegate {
    func navigator(_ navigator: VisualNavigator, didTapAt point: CGPoint) {
        guard !DirectionalNavigationAdapter(navigator: navigator).didTap(at: point) else {
            return
        }
        // clear a current search highlight
        if let decorator = self.navigator as? DecorableNavigator {
            decorator.apply(decorations: [], in: "search")
        }

        toggleNavigationBar()
    }

    func navigator(_ navigator: VisualNavigator, didPressKey event: KeyEvent) {
        DirectionalNavigationAdapter(navigator: navigator).didPressKey(event: event)
    }
}

// MARK: - Highlights management

extension ReaderViewController {
    func saveHighlight(_ highlight: Highlight) {
        guard let highlights = highlights else { return }

        Task {
            do {
                try await highlights.add(highlight)
                toast(NSLocalizedString("reader_highlight_success_message", comment: "Success message when adding a bookmark"), on: view, duration: 1)
            } catch {
                print(error)
                toast(NSLocalizedString("reader_highlight_failure_message", comment: "Error message when adding a new bookmark failed"), on: view, duration: 2)
            }
        }
    }

    func updateHighlight(_ highlightID: Highlight.Id, withColor color: HighlightColor) {
        guard let highlights = highlights else { return }

        Task {
            try! await highlights.update(highlightID, color: color)
        }
    }

    func deleteHighlight(_ highlightID: Highlight.Id) {
        guard let highlights = highlights else { return }

        Task {
            try! await highlights.remove(highlightID)
        }
    }
}
