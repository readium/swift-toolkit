//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

struct OPDSFacetLInkView: View {
    let link: ReadiumShared.Link

    var body: some View {
        HStack {
            if let title = link.title {
                Text(title)
                    .foregroundStyle(Color.primary)
                    .font(.body)
            }

            Spacer()

            if let count = link.properties.numberOfItems {
                Text("\(count)")
                    .foregroundStyle(Color.secondary)
                    .font(.subheadline)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
        }
    }
}

#Preview {
    OPDSFacetLInkView(
        link: Feed.preview.facets[0].links[0]
    )
    .padding()
}
