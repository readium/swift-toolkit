//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

struct OPDSGroupRow: View {
    let group: ReadiumShared.Group

    typealias NavigablePublication = OPDSFeedView.NavigablePublication
    let publications: [NavigablePublication]

    let isLoading: Bool
    let onLastItemAppeared: () -> Void

    private let rowHeight: CGFloat = 230

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(publications) { navPublication in
                    NavigationLink(value: navPublication) {
                        OPDSPublicationItemView(publication: navPublication.publication)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if navPublication == publications.last {
                            onLastItemAppeared()
                        }
                    }
                }

                if isLoading {
                    ZStack {
                        ProgressView()
                    }
                    .frame(width: 140, height: rowHeight)
                }
            }
            .padding(.horizontal)
        }
        .frame(height: rowHeight)
    }
}
