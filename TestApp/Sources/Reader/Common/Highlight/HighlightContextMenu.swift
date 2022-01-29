//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct HighlightContextMenu: View {
    let colors: [HighlightColor]
    let colorSelectedHandler: (HighlightColor) -> Void
    let deleteSelectedHandler: () -> Void
    
    var body: some View {
        HStack {
            ForEach(0..<colors.count) { index in
                Button {
                    colorSelectedHandler(colors[index])
                } label: {
                    Text(emoji(for: colors[index]))
                }
                Divider()
            }
                
            Button {
                deleteSelectedHandler()
            } label: {
                Image(systemName: "xmark.bin")
                    .font(.system(size: 16))
            }
            
        }
//        .background(Color.gray)
    }
    
    private func emoji(for color: HighlightColor) -> String {
        switch color {
        case .red:
            return "🔴"
        case .green:
            return "🟢"
        case .blue:
            return "🔵"
        case .yellow:
            return "🟡"
        }
    }
}
