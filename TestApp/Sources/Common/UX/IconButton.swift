//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import SwiftUI

struct IconButton: View {
    enum Size: CGFloat {
        case small = 24
        case medium = 32
    }

    private let systemName: String
    private let foregroundColor: Color
    private let size: Size
    private let action: () -> Void

    init(systemName: String, foregroundColor: Color = Color(UIColor.label), size: Size = .medium, action: @escaping () -> Void) {
        self.systemName = systemName
        self.foregroundColor = foregroundColor
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(
            action: action,
            label: {
                Image(systemName: systemName)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(foregroundColor)
            }
        )
        .frame(width: size.rawValue, height: size.rawValue)
    }
}
