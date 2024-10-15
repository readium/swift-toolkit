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
        VStack(spacing: 16) {
            HStack {
                Label {
                    Text(title)
                        .bold()
                } icon: {
                    Image(systemName: iconName)
                }
                .font(.title2)
                .foregroundColor(Color(red: 0.0, green: 0.18, blue: 0.39))
                
                Spacer()
            }
            content()
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}
