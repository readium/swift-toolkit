//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

struct OPDSFacetsView: View {
    @Environment(\.dismiss) private var dismiss

    let feed: Feed
    let onLinkTap: (ReadiumShared.Link) -> Void

    var body: some View {
        NavigationView {
            facetsList
                .toolbar { cancelButton }
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("Filters")
        }
    }

    private var facetsList: some View {
        List(feed.facets, id: \.metadata.title) { facet in
            Section(facet.metadata.title) {
                ForEach(facet.links, id: \.href) { link in
                    OPDSFacetLInkView(link: link)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onLinkTap(link)
                            dismiss()
                        }
                }
            }
        }
    }

    private var cancelButton: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") { dismiss() }
        }
    }
}

#Preview {
    OPDSFacetsView(feed: .preview) { link in
        print("Tap on link \(link.href)")
    }
}
