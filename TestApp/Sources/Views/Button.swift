//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

enum ButtonKind {
    case add
    case cancel
    case save
    case download
}

@ViewBuilder
func Button(_ kind: ButtonKind, action: @escaping () -> Void) -> some View {
    switch kind {
    case .add:
        Button(action: action) {
            Label("Add", systemImage: "plus")
        }
    case .cancel:
        Button("Cancel", action: action)
    case .save:
        Button("Save", action: action)
    case .download:
        Button(action: action) {
            Label("Download", systemImage: "icloud.and.arrow.down")
        }
    }
}
