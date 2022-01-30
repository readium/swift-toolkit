//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI
import Combine

struct HighlightContextMenu: View {
    let colors: [HighlightColor]
    let systemFontSize: CGFloat
    
    private let colorSubject = PassthroughSubject<HighlightColor, Never>()
    var selectedColorPublisher: AnyPublisher<HighlightColor, Never> {
        return colorSubject.eraseToAnyPublisher()
    }
    
    private let deleteSubject = PassthroughSubject<Void, Never>()
    var selectedDeletePublisher: AnyPublisher<Void, Never> {
        return deleteSubject.eraseToAnyPublisher()
    }
    
    var body: some View {
        HStack {
            ForEach(0..<colors.count) { index in
                Button {
                    colorSubject.send(colors[index])
                } label: {
                    Text(emoji(for: colors[index]))
                        .font(.system(size: systemFontSize))
                }
                Divider()
            }
                
            Button {
                deleteSubject.send()
            } label: {
                Image(systemName: "xmark.bin")
                    .font(.system(size: systemFontSize))
            }
        }
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
