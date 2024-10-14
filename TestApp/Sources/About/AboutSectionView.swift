//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct AboutSectionView<Content: View>: View {
    
    private let title: String
    private var content: () -> Content
    
    init(
        title: String,
        content: @escaping () -> Content
    ) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.title2)
                .bold()
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            content()
        }
    }
    
}
