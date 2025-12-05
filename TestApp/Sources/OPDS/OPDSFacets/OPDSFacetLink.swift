//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

struct OPDSFacetLink: View {
    let link: ReadiumShared.Link

    var body: some View {
        HStack {
            if let title = link.title {
                Text(title)
                    .foregroundStyle(Color.primary)
            }

            Spacer()

            if let count = link.properties.numberOfItems {
                Text("\(count)")
                    .foregroundStyle(Color.secondary)
                    .font(.subheadline)
            }

            Image(systemName: "chevron.right")
        }
        .font(.body)
    }
}

#Preview {
    OPDSFacetLink(
        link: Feed.preview.facets[0].links[0]
    )
    .padding()
}
