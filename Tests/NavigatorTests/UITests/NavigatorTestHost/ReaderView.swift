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
                }
        }
    }
}

@MainActor final class ReaderViewModel: ObservableObject, Identifiable {
    nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }

    let navigator: VisualNavigator & UIViewController

    @Published var isReady: Bool = false

    init(navigator: VisualNavigator & UIViewController) {
        self.navigator = navigator

        if let epubNavigator = navigator as? EPUBNavigatorViewController {
            epubNavigator.delegate = self
        } else if let pdfNavigator = navigator as? PDFNavigatorViewController {
            pdfNavigator.delegate = self
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
