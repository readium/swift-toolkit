//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

struct OPDSFacetView: View {
    let facets: [Facet]

    /// This closure is called when a facet link is tapped.
    /// The parent view (OPDSFeedView) will handle the navigation.
    let onLinkTapped: (ReadiumShared.Link) -> Void

    /// The dismiss action provided by the environment.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(facets, id: \.metadata.title) { facet in
                    Section(header: Text(facet.metadata.title)) {
                        ForEach(facet.links, id: \.href) { link in
                            Button {
                                // When tapped, dismiss this sheet
                                // and tell the parent to navigate.
                                dismiss()
                                onLinkTapped(link)
                            } label: {
                                OPDSNavigationRow(link: link)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            .listStyle(.grouped)
            .navigationTitle(NSLocalizedString("filter_button", comment: "Filter the OPDS feed"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("ok_button", comment: "Alert button")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
