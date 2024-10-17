//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct AboutSectionView<Content: View>: View {
    private let title: String
    private let iconName: String
    private var content: () -> Content
    
    init(
        title: String,
        iconName: String,
        content: @escaping () -> Content
    ) {
        self.title = title
        self.iconName = iconName
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
                Image(systemName: iconName)
            }
            .font(.title2)
        }
    }
}

#Preview {
    AboutSectionView(
        title: "Version",
        iconName: "app.badge") {
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
