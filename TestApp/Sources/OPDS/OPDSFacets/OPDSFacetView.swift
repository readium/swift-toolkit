//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI
import ReadiumShared

struct OPDSFacetView: View {
    @Environment(\.dismiss) private var dismiss
    
    let feed: Feed
    
    var body: some View {
        NavigationView {
            Text(feed.metadata.title)
                .toolbar {
                    ToolbarItem(
                        placement: .topBarLeading
                    ) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("Filters")
        }
    }
}

#Preview {
    OPDSFacetView(feed: .preview)
}
