//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumNavigator
import ReadiumShared
import SwiftUI

/// SwiftUI wrapper for the `ReaderViewController`.
struct ReaderView: View {
    @ObservedObject var viewModel: ReaderViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ReaderViewControllerWrapper(navigator: viewModel.navigator)
                // State information checked in UI tests, not meant to be
                // visible.
                .background(
                    List {
                        Toggle(isOn: $viewModel.isReady) {}
                            .accessibilityIdentifier(.isNavigatorReady)
                        Toggle(isOn: $viewModel.stressTestCompleted) {}
                            .accessibilityIdentifier(.stressTestCompleted)
                    }
                )
                .ignoresSafeArea(.all)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            dismiss()
                        }
                        .accessibilityIdentifier(.close)
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button("Run Stress Test") {
                            viewModel.runNavigationStressTest()
                        }
                        .accessibilityIdentifier(.runStressTest)
                    }
                }
        }
    }
}

@MainActor final class ReaderViewModel: ObservableObject, Identifiable {
    nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }

    let navigator: VisualNavigator & UIViewController

    @Published var isReady: Bool = false
    @Published var stressTestCompleted: Bool = false

    init(navigator: VisualNavigator & UIViewController) {
        self.navigator = navigator

        if let epubNavigator = navigator as? EPUBNavigatorViewController {
            epubNavigator.delegate = self
        } else if let pdfNavigator = navigator as? PDFNavigatorViewController {
            pdfNavigator.delegate = self
        }
    }

    func runNavigationStressTest() {
        Task {
            let publication = navigator.publication
            let readingOrder = publication.readingOrder
            guard let positionsByReadingOrder = await publication.positionsByReadingOrder().getOrNil() else { return }

            for _ in 0 ..< 100 {
                let positions = positionsByReadingOrder[Int.random(in: 0 ..< readingOrder.count)]
                let locator = positions[Int.random(in: 0 ..< positions.count)]
                await navigator.go(to: locator, options: NavigatorGoOptions(animated: false))
                let sleepNanos = UInt64.random(in: 0 ... 50) * 1_000_000
                try? await Task.sleep(nanoseconds: sleepNanos)
            }

            stressTestCompleted = true
        }
    }
}

// MARK: - NavigatorDelegate

extension ReaderViewModel: NavigatorDelegate {
    func navigator(_ navigator: Navigator, presentError error: NavigatorError) {}

    func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
        if !isReady {
            isReady = true
        }
    }
}

extension ReaderViewModel: EPUBNavigatorDelegate {}
extension ReaderViewModel: PDFNavigatorDelegate {}
