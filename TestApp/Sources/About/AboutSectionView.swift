//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct AboutSectionView<Content: View>: View {
    enum Icon: String {
        case app = "app.badge"
        case circle = "c.circle"
        case hands = "hands.sparkles"
    }

    private let title: String
    private let icon: Icon
    private var content: () -> Content

    init(
        title: String,
        icon: Icon,
        content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content
    }

    var body: some View {
        GroupBox {
            content()
                .padding(.top, 4)
        } label: {
            Label {
                Text(title)
                    .bold()
            } icon: {
                Image(systemName: icon.rawValue)
            }
            .font(.title2)
        }
    }
}

#Preview {
    AboutSectionView(title: "Version", icon: .app) {
        VStack {
            HStack {
                Text("App Version:")
                    .foregroundColor(.gray)
                Spacer()
                Text("alpha-3.0")
                    .foregroundColor(.primary)
            }

            HStack(spacing: 10) {
                Text("Build Version:")
                    .foregroundColor(.gray)
                Spacer()
                Text("alpha-3.0")
                    .foregroundColor(.primary)
            }
        }
    }
    .padding()
}
