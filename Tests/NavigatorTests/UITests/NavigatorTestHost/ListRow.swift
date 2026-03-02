//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct ListRow<Content: View>: View {
    private let action: (@MainActor () async -> Void)?
    private let content: () -> Content

    @State private var isActionRunning = false

    init(
        action: (() async -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.action = action
        self.content = content
    }

    var body: some View {
        HStack {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.interaction, .rect)
        .onTapGesture(perform: activate)
        .disabled(isActionRunning)
    }

    private func activate() {
        guard let action, !isActionRunning else {
            return
        }
        isActionRunning = true
        Task { @MainActor in
            await action()
            isActionRunning = false
        }
    }
}
