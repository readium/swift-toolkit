//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

struct OPDSFacetList: View {
    @Environment(\.dismiss) private var dismiss

    let feed: Feed
    let onLinkSelected: (ReadiumShared.Link) -> Void

    var body: some View {
        NavigationView {
            facets
                .toolbar { cancelButton }
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("Facets")
        }
    }

    private var facets: some View {
        List(feed.facets, id: \.metadata.title) { facet in
            Section(facet.metadata.title) {
                ForEach(facet.links, id: \.href) { link in
                    OPDSFacetLink(link: link)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onLinkSelected(link)
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
    OPDSFacetList(feed: .preview) { link in
        print("Tap on link \(link.href)")
    }
}
