//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI
import ReadiumShared

struct OPDSFacetView: View {
    let feed: Feed
    
    var body: some View {
        NavigationView {
            Text(feed.metadata.title)
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("Filters")
        }
    }
}

#Preview {
    OPDSFacetView(feed: .preview)
}
