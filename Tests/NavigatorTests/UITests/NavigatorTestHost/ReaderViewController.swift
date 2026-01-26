//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumNavigator
import SwiftUI
import UIKit

class ReaderViewController: UIViewController {
    private let navigator: VisualNavigator & UIViewController

    init(navigator: VisualNavigator & UIViewController) {
        self.navigator = navigator
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init?(coder: NSCoder) not implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Add navigator as child view controller
        addChild(navigator)
        navigator.view.frame = view.bounds
        navigator.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(navigator.view)
        navigator.didMove(toParent: self)
    }
}

struct ReaderViewControllerWrapper: UIViewControllerRepresentable {
    let navigator: VisualNavigator & UIViewController

    init(navigator: VisualNavigator & UIViewController) {
        self.navigator = navigator
    }

    func makeUIViewController(context: Context) -> ReaderViewController {
        ReaderViewController(navigator: navigator)
    }

    func updateUIViewController(_ uiViewController: ReaderViewController, context: Context) {}
}
