# Implementing Highlights

Highlighting let users mark up passages in a publication for later reference - a core feature of any reading app. In Readium, highlights are built on top of the **Decoration API**. If you want to understand that API in depth or build a custom decoration style, see the [Decorations guide](Decorations.md).

**Readium is only responsible for *rendering* highlights over the publication content**. Persisting highlights to a database, and any UI around them (color pickers, annotation editors, highlight lists, etc.) are entirely the responsibility of your app. This guide assumes you already have a `Highlight` model and a repository to store and observe it.

> [!NOTE]
> Only `EPUBNavigatorViewController` implements `DecorableNavigator` today. Always check if a navigator implements `DecorableNavigator` before enabling decoration-dependent features to future-proof your code.

## Setting Up

iOS shows a context menu when the user selects text in the navigator. You hook into this by declaring a custom `EditingAction` with a selector that will be fired when the user taps the menu item.

```swift
let navigator = try EPUBNavigatorViewController(
    publication: publication,
    initialLocation: lastReadLocation,
    config: EPUBNavigatorViewController.Configuration(
        editingActions: EditingAction.defaultActions + [
            EditingAction(title: "Highlight", action: #selector(highlightSelection))
        ]
    )
)
```

## Creating a Highlight from a Text Selection

The `action` selector must be implemented somewhere in the **responder chain** above the navigator — typically in its parent view controller. iOS routes editing actions up the responder chain, so the navigator passes them through without handling them itself.

```swift
@objc func highlightSelection() {
    guard let selection = navigator.currentSelection else {
        return
    }

    let highlight = Highlight(
        bookId: bookId,
        locator: selection.locator,
        text: selection.locator.text.highlight,
        color: .yellow
    )

    Task {
        try await highlightRepository.add(highlight)
        // If you use a reactive pattern (see below), the navigator
        // updates automatically when the database changes.
    }

    // dismisses the text selection handles immediately after saving;
    // without it, the selection would linger on screen alongside the
    // newly rendered highlight decoration.
    navigator.clearSelection()
}
```

`navigator.currentSelection` returns a `Selection` value with:

- `locator` — a `Locator` pointing at the selected range; `locator.text.highlight` contains the selected string.
- `frame` — the bounding rect of the selection in navigator view coordinates, useful for anchoring a popover.

## Displaying Highlights

Rather than calling `apply` manually after each add, delete, or color change, subscribe to your database and re-apply the complete list of decorations whenever it changes. This means there is a single code path for keeping the navigator in sync — no risk of forgetting to update the UI for one of the operations.

The navigator diffs each new list against the previous one internally, so passing the full list every time is both safe and efficient — you never need to track individual changes yourself.

```swift
func observeHighlightDecorations() {
    guard let navigator = navigator as? DecorableNavigator else { return }

    // Register the tap callback once (see "Handling Taps" below)
    navigator.observeDecorationInteractions(inGroup: "highlights") { [weak self] event in
        self?.activateDecoration(event)
    }

    // Re-apply on every database change.
    highlightRepository.highlights(for: bookId)
        .receive(on: DispatchQueue.main)
        .sink { _ in } receiveValue: { [weak self] highlights in
            guard let self else { return }

            let decorations = highlights.map { highlight in
                Decoration(
                    // Use your database primary key as the highlight's `id` — this is what
                    // links the `Decoration` back to your model when the user later taps it.
                    id: highlight.id,
                    locator: highlight.locator,
                    style: .highlight(tint: highlight.color)
                )
            }

            navigator.apply(decorations: decorations, in: "highlights")
        }
        .store(in: &subscriptions)
}
```

`receive(on: DispatchQueue.main)` is required because `apply(decorations:in:)` updates the UI and must run on the main thread, while database publishers typically deliver on a background thread.

Call `observeHighlightDecorations()` once in `viewDidLoad`.

## Handling Taps

Use `observeDecorationInteractions(inGroup:onActivated:)` to react when the user taps a highlight. Your callback receives `OnDecorationActivatedEvent` objects.

**`event.decoration.id`** matches the id you set when building the `Decoration`, so you can use it directly to retrieve the full record from your database.

**`event.rect`** gives you the position of the tapped highlight in the navigator view, which you can use to anchor a popover precisely over it.

```swift
private func activateDecoration(_ event: OnDecorationActivatedEvent) {
    // Matches the id you used when building the Decoration.
    let highlightId = event.decoration.id

    Task { @MainActor in
        guard let highlight = try? await highlightRepository.highlight(forId: highlightId) else {
            return
        }

        presentHighlightMenu(for: highlight, anchoredTo: event.rect)
    }
}

private func presentHighlightMenu(for highlight: Highlight, anchoredTo rect: CGRect?) {
    let alert = UIAlertController(title: "Highlight", message: nil, preferredStyle: .actionSheet)

    // Delete: remove from the database; the reactive stream clears the decoration automatically.
    alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
        guard let self else { return }
        Task { try await self.highlightRepository.remove(highlight.id) }
    })

    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

    if let popover = alert.popoverPresentationController {
        popover.sourceView = view
        popover.sourceRect = rect ?? view.bounds
    }

    present(alert, animated: true)
}
```

Because the navigator is wired to the reactive stream, updating or deleting a highlight in the database is automatically reflected in the navigator — no extra calls needed.

## Navigating to a Highlight

Use `navigator.go(to:)` to jump to a saved highlight's location:

```swift
await navigator.go(to: highlight.locator)
```

## Complete Example

The following self-contained `EPUBReaderViewController` wires up the full highlights workflow. `HighlightRepository` is left as a protocol so the example is storage-agnostic.

```swift
import Combine
import ReadiumNavigator
import ReadiumShared
import UIKit

// MARK: - Data model

struct Highlight {
    /// Database primary key (used as Decoration.id)
    var id: String          
    var bookId: String
    var locator: Locator
    var color: UIColor
}

// MARK: - Storage protocol (implement with GRDB, CoreData, etc.)

protocol HighlightRepository {
    func highlights(for bookId: String) -> AnyPublisher<[Highlight], Never>
    func highlight(forId id: String) async throws -> Highlight?
    func add(_ highlight: Highlight) async throws
    func remove(_ id: String) async throws
}

// MARK: - Reader view controller

class EPUBReaderViewController: UIViewController {

    private let navigator: EPUBNavigatorViewController
    private let highlightRepository: HighlightRepository
    private let bookId: String
    private var subscriptions = Set<AnyCancellable>()

    private let highlightDecorationGroup = "highlights"

    init(
        publication: Publication,
        bookId: String,
        lastLocation: Locator?,
        highlightRepository: HighlightRepository
    ) throws {
        self.bookId = bookId
        self.highlightRepository = highlightRepository

        navigator = try EPUBNavigatorViewController(
            publication: publication,
            initialLocation: lastLocation,
            config: EPUBNavigatorViewController.Configuration(
                editingActions: EditingAction.defaultActions + [
                    EditingAction(title: "Highlight", action: #selector(highlightSelection))
                ]
            )
        )

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Embed the navigator
        addChild(navigator)
        navigator.view.frame = view.bounds
        navigator.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(navigator.view)
        navigator.didMove(toParent: self)

        // Wire up highlights
        observeHighlightDecorations()
    }

    // MARK: - Displaying highlights

    private func observeHighlightDecorations() {
        guard let decorator = navigator as? DecorableNavigator else { return }

        decorator.observeDecorationInteractions(inGroup: highlightDecorationGroup) { [weak self] event in
            self?.activateDecoration(event)
        }

        highlightRepository.highlights(for: bookId)
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] highlights in
                guard let self else { return }
                let decorations = highlights.map { h in
                    Decoration(
                        id: h.id,
                        locator: h.locator,
                        style: .highlight(tint: h.color)
                    )
                }
                decorator.apply(decorations: decorations, in: self.highlightDecorationGroup)
            }
            .store(in: &subscriptions)
    }

    // MARK: - Creating highlights

    @objc func highlightSelection() {
        guard let selection = navigator.currentSelection else { return }

        let highlight = Highlight(
            id: UUID().uuidString,
            bookId: bookId,
            locator: selection.locator,
            color: .yellow
        )

        Task {
            try await highlightRepository.add(highlight)
        }

        navigator.clearSelection()
    }

    // MARK: - Tapping existing highlights

    private func activateDecoration(_ event: OnDecorationActivatedEvent) {
        let highlightId = event.decoration.id

        Task {
            guard let highlight = try? await highlightRepository.highlight(forId: highlightId) else { return }
            await MainActor.run {
                presentHighlightMenu(for: highlight, anchoredTo: event.rect)
            }
        }
    }

    private func presentHighlightMenu(for highlight: Highlight, anchoredTo rect: CGRect?) {
        let alert = UIAlertController(title: "Highlight", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self else { return }
            Task { try await self.highlightRepository.remove(highlight.id) }
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = rect ?? view.bounds
            popover.permittedArrowDirections = .down
        }

        present(alert, animated: true)
    }
}
```
