//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import ReadiumNavigator
import ReadiumShared
import SwiftUI
import UIKit

/// Base class for the reader view controller of a `VisualNavigator`.
class VisualReaderViewController<N: UIViewController & Navigator>: ReaderViewController<N>, VisualNavigatorDelegate {
    private lazy var positionLabel = UILabel()

    private let ttsViewModel: TTSViewModel?
    private let ttsControlsViewController: UIHostingController<TTSControls>?
    private var positionCount: Int?

    init(
        navigator: N,
        publication: Publication,
        bookId: Book.Id,
        books: BookRepository,
        bookmarks: BookmarkRepository,
        highlights: HighlightRepository?
    ) {
        self.highlights = highlights

        ttsViewModel = TTSViewModel(navigator: navigator, publication: publication)
        ttsControlsViewController = ttsViewModel.map { UIHostingController(rootView: TTSControls(viewModel: $0)) }

        super.init(
            navigator: navigator,
            publication: publication,
            bookId: bookId,
            books: books,
            bookmarks: bookmarks
        )

        setupUserInteraction()
        addHighlightDecorationsObserverOnce()
        updateHighlightDecorations()

        Task {
            self.positionCount = try? await publication.positions().get().count

            await updatePageListDecorations()
        }
    }

    /// Setups the user interaction (e.g. taps) with the navigator.
    private func setupUserInteraction() {
        guard let navigator = navigator as? VisualNavigator else {
            return
        }

        // Show a red dot at the location where the user tapped.
//        navigator.addObserver(.tap { [weak self] event in
//            guard let self else { return false }
//
//            let tapView = UIView(frame: .init(x: 0, y: 0, width: 50, height: 50))
//            view.addSubview(tapView)
//            tapView.backgroundColor = .red
//            tapView.center = event.location
//            tapView.layer.cornerRadius = 25
//            tapView.layer.masksToBounds = true
//            UIView.animate(withDuration: 0.8, animations: {
//                tapView.alpha = 0
//            }) { _ in
//                tapView.removeFromSuperview()
//            }
//
//            return false
//        })

        /// This adapter will automatically turn pages when the user taps the
        /// screen edges or press arrow keys.
        ///
        /// Bind it to the navigator before adding your own observers to prevent
        /// triggering your actions when turning pages.
        DirectionalNavigationAdapter(
            pointerPolicy: .init(types: [.mouse, .touch])
        ).bind(to: navigator)

        // Clear the current search highlight on tap.
        navigator.addObserver(.activate { [weak self] _ in
            guard
                let searchViewModel = self?.searchViewModel,
                searchViewModel.selectedLocator != nil
            else {
                return false
            }

            searchViewModel.selectedLocator = nil
            return true
        })

        // Toggle the navigation bar on tap, if nothing else took precedence.
        navigator.addObserver(.activate { [weak self] _ in
            self?.toggleNavigationBar()
            return true
        })
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white

        updateNavigationBar(animated: false)

        addChild(navigator)
        navigator.view.frame = view.bounds
        navigator.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(navigator.view)
        navigator.didMove(toParent: self)

        positionLabel.translatesAutoresizingMaskIntoConstraints = false
        positionLabel.font = .systemFont(ofSize: 12)
        positionLabel.textColor = .darkGray
        // Prevents VoiceOver from selecting the position label while reading
        // the page.
        positionLabel.isAccessibilityElement = false

        view.addSubview(positionLabel)
        NSLayoutConstraint.activate([
            positionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            positionLabel.bottomAnchor.constraint(equalTo: navigator.view.bottomAnchor, constant: -20),
        ])

        if let state = ttsViewModel?.$state, let controls = ttsControlsViewController {
            controls.view.backgroundColor = .clear
            controls.view.isHidden = true

            addChild(controls)
            controls.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(controls.view)
            NSLayoutConstraint.activate([
                controls.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                controls.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            ])
            controls.didMove(toParent: self)

            state
                .receive(on: DispatchQueue.main)
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

    override func makeNavigationBarButtons() -> [UIBarButtonItem] {
        var buttons: [UIBarButtonItem] = super.makeNavigationBarButtons()

        // Text to speech
        if let ttsViewModel = ttsViewModel {
            buttons.append(UIBarButtonItem(image: UIImage(systemName: "speaker.wave.2.fill"), style: .plain, target: ttsViewModel, action: #selector(TTSViewModel.start)))
        }

        return buttons
    }

    func toggleNavigationBar() {
        navigationBarHidden = !navigationBarHidden
    }

    func updateNavigationBar(animated: Bool = true) {
        navigationController?.setNavigationBarHidden(navigationBarHidden, animated: animated)
        setNeedsStatusBarAppearanceUpdate()
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        .slide
    }

    override var prefersStatusBarHidden: Bool {
        navigationBarHidden
    }

    // MARK: - VisualNavigatorDelegate

    override func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
        super.navigator(navigator, locationDidChange: locator)

        positionLabel.text = {
            if let positionCount = positionCount, let position = locator.locations.position {
                return "\(position) / \(positionCount)"
            } else if let progression = locator.locations.totalProgression {
                return "\(progression)%"
            } else {
                return nil
            }
        }()
    }

    // MARK: - Highlights

    private let highlights: HighlightRepository?
    private var highlightContextMenu: UIHostingController<HighlightContextMenu>?
    private let highlightDecorationGroup = "highlights"
    private var currentHighlightCancellable: AnyCancellable?

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
                    let decorations = highlights.map { Decoration(id: $0.id!.string, locator: $0.locator, style: .highlight(tint: $0.color.uiColor, isActive: false)) }
                    decorator.apply(decorations: decorations, in: self.highlightDecorationGroup)
                }
            }
            .store(in: &subscriptions)
    }

    private func activateDecoration(_ event: OnDecorationActivatedEvent) {
        guard let highlights = highlights else { return }

        let id = event.decoration.highlightID
        currentHighlightCancellable = highlights.highlight(for: id).sink { _ in
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
            self?.updateHighlight(event.decoration.highlightID, withColor: color)
            self?.highlightContextMenu?.dismiss(animated: true, completion: nil)
        }
        .store(in: &subscriptions)

        menuView.selectedDeletePublisher.sink { [weak self] _ in
            self?.currentHighlightCancellable?.cancel()
            self?.deleteHighlight(event.decoration.highlightID)
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
}

extension Decoration {
    var highlightID: Highlight.Id {
        Highlight.Id(string: id)!
    }
}

// MARK: - Page list decorations

// This is an example on how to use custom decoration style to display the
// page labels in a `publication.pageList` in the navigator as a side margin
// label.
//
// See http://kb.daisy.org/publishing/docs/navigation/pagelist.html

extension VisualReaderViewController {
    /// Will take the `publication.pageList` and create a `Decoration` for each
    /// label.
    private func updatePageListDecorations() async {
        guard let navigator = navigator as? DecorableNavigator else {
            return
        }

        var decorations: [Decoration] = []
        for (index, link) in publication.pageList.enumerated() {
            guard
                let title = link.title,
                let locator = await publication.locate(link)
            else {
                continue
            }

            decorations.append(Decoration(
                id: "page-list-\(index)",
                locator: locator,
                style: Decoration.Style(
                    id: .pageList,
                    config: PageListConfig(label: title)
                )
            ))
        }
        navigator.apply(decorations: decorations, in: "page-list")
    }
}

extension Decoration.Style.Id {
    /// Decoration Style for a page number label.
    ///
    /// This is an example of a custom Decoration Style ID declaration.
    static let pageList: Decoration.Style.Id = "page_list"
}

struct PageListConfig: Hashable {
    /// Page number label, taken from `publication.pageList[].title`.
    var label: String
}

extension HTMLDecorationTemplate {
    /// Concrete implementation of the `pageList` decoration style for
    /// HTML-based navigators, such as the `EPUBNavigatorViewController`.
    ///
    /// It must be added to `EPUBNavigatorViewController.Configuration.decorationTemplates`
    /// when creating the navigator.
    static var pageList: HTMLDecorationTemplate {
        let className = "testapp-page-number"

        return HTMLDecorationTemplate(
            layout: .bounds,
            width: .page,
            element: { decoration in
                let config = decoration.style.config as? PageListConfig

                // Using `var(--RS__backgroundColor)` is a trick to use the
                // same background color as the Readium theme. If we don't set
                // it directly inline in the HTML, it might be forced
                // transparent by Readium CSS.
                return """
                    <div>
                        <span class="\(className)" style="background-color: var(--RS__backgroundColor) !important">
                            \(config?.label ?? "")
                        </span>
                    </div>
                """
            },
            stylesheet: """
                .\(className) {
                    float: left;
                    margin-left: 4px;
                    padding: 0px 2px 0px 2px;
                    border: 1px solid;
                    border-radius: 10%;
                    box-shadow: rgba(50, 50, 93, 0.25) 0px 2px 5px -1px, rgba(0, 0, 0, 0.3) 0px 1px 3px -1px;
                    opacity: 0.8;
                }
            """
        )
    }
}
