//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import SwiftUI
import UIKit

struct HighlightCellView: View {
    let highlight: Highlight

    var body: some View {
        HStack {
            Rectangle()
                .fill(Color(highlight.color.uiColor))
                .frame(maxWidth: 20, maxHeight: .infinity)

            Text(highlight.locator.text.sanitized().highlight ?? "")
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding()

            Spacer()
        }
    }
}
