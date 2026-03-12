//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

public extension View {
    /// Presents an alert when the given `error` binding is set.
    func alert(error: Binding<Error?>) -> some View {
        modifier(ErrorAlertModifier(error: error))
    }
}

private struct ErrorAlertModifier: ViewModifier {
    @Binding var error: Error?

    func body(content: Self.Content) -> some View {
        content
            .alert(
                "Error",
                isPresented: Binding(
                    get: { error != nil },
                    set: { isPresented, _ in
                        if !isPresented {
                            error = nil
                        }
                    }
                ),
                presenting: error,
                actions: { _ in
                    Button("Close", role: .cancel) {}
                },
                message: { error in
                    Text(error.localizedDescription)
                }
            )
    }
}
