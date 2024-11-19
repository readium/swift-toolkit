# Integrating the Navigator with SwiftUI

The Navigator is built with UIKit and provides `UIViewController` implementations. Nevertheless, you can integrate them into a SwiftUI view hierarchy using Apple's [`UIViewRepresentable`](https://developer.apple.com/documentation/swiftui/uiviewrepresentable).

## SwiftUI wrapper for a Navigator's `UIViewController`

Here is a basic example of a `UIViewControllerRepresentable` implementation that hosts a Navigator.

```swift
/// SwiftUI wrapper for the `ReaderViewController`.
struct ReaderViewControllerWrapper: UIViewControllerRepresentable {
    let viewController: ReaderViewController

    func makeUIViewController(context: Context) -> ReaderViewController {
        viewController
    }

    func updateUIViewController(_ uiViewController: ReaderViewController, context: Context) {}
}

/// Host view controller for a Readium Navigator.
class ReaderViewController: UIViewController {

    /// View model provided by your application.
    private let viewModel: ReaderViewModel
    
    /// Readium Navigator instance.
    private let navigator: Navigator & UIViewController

    init(viewModel: ReaderViewModel, navigator: Navigator & UIViewController) {
        self.viewModel = viewModel
        self.navigator = navigator

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init?(coder: NSCoder) not implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addChild(navigator)
        navigator.view.frame = view.bounds
        navigator.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(navigator.view)
        navigator.didMove(toParent: self)
    }

    /// Handler for a custom editing action.
    @objc func makeHighlight(_ sender: Any) {
        viewModel.makeHighlight()
    }
}
```

Note that we could use a `Navigator` instance directly, without a parent `ReaderViewController`. However, a host view controller is necessary if you want to use custom text selection menu items and capture events in the UIKit responder chain. For instance, when configuring your EPUB Navigator with:

```swift
var config = EPUBNavigatorViewController.Configuration()
config.editingActions.append(
    EditingAction(
        title: "Highlight",
        action: #selector(makeHighlight)
    )
)

let navigator = try EPUBNavigatorViewController(
    publication: publication,
    initialLocation: locator,
    config: config,
    ...
)
```

## Embedding the `ReaderViewControllerWrapper` in a SwiftUI view

```swift
struct ReaderView: View {
    
    /// View model provided by your application.
    @ObservedObject var viewModel: ReaderViewModel

    let viewControllerWrapper: ReaderViewControllerWrapper

    var body: some View {
        viewControllerWrapper
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.all)
            .navigationTitle(viewModel.book.title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(viewModel.isFullscreen)
            .statusBarHidden(viewModel.isFullscreen)
    }
}
```

## Assembling the Navigator and SwiftUI objects

Now, let's construct an EPUB navigator and assemble the SwiftUI view hierarchy to bring all the pieces together.

```swift
var config = EPUBNavigatorViewController.Configuration()
config.editingActions.append(
    EditingAction(
        title: "Highlight",
        action: #selector(highlightSelection)
    )
)

let navigator = try EPUBNavigatorViewController(
    publication: publication,
    initialLocation: locator,
    config: config,
    ...
)

// View model provided by your application.
let viewModel = ReaderViewModel()

let view = ReaderView(
    viewModel: viewModel,
    viewControllerWrapper: ReaderViewControllerWrapper(
        viewController: ReaderViewController(
            viewModel: viewModel,
            navigator: navigator
        )
    )
)
```

## Handling touch and keyboard events

You still need to implement the `VisualNavigatorDelegate` protocol to handle gestures in the navigator. Avoid using SwiftUI touch modifiers, as they will prevent the user from interacting with the book.
