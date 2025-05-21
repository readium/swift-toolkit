//
//  Copyright 2025 Readium Foundation. All rights reserved.
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
    private let size: Size
    private let action: () -> Void

    init(systemName: String, size: Size = .medium, action: @escaping () -> Void) {
        self.systemName = systemName
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
            }
        )
        .frame(width: size.rawValue, height: size.rawValue)
    }
}
