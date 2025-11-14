//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

/// A view for a single navigation link in an OPDS feed.
struct OPDSNavigationRow: View {
    let link: ReadiumShared.Link

    var body: some View {
        rowContent
    }

    @ViewBuilder
    private var rowContent: some View {
        HStack {
            Text(link.title ?? "Untitled")
                .font(.title3)
                .padding(.vertical, 8)
                .lineLimit(1)

            Spacer()

            if let count = link.properties.numberOfItems {
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundColor(Color(uiColor: .tertiaryLabel))
        }
        .contentShape(Rectangle())
    }
}
