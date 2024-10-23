//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumOPDS
import ReadiumShared
import SwiftUI

/// Screen of an actual catalog feed, second to x number in the stack since it can keep going to another catalog
struct CatalogFeed: View {
    var catalog: Catalog
    @State private var parseData: ParseData?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                if let feed = parseData?.feed {
                    if !feed.navigation.isEmpty {
                        ForEach(feed.navigation, id: \.self) { link in
                            let navigationLink = Catalog(title: link.title ?? "Catalog", url: link.href)
                            /// We don't need to define the navigationDestination for this again because it will use the one in CatalogList
                            NavigationLink(value: navigationLink) {
                                ListRowItem(title: link.title!)
                            }
                        }
                        Divider().frame(height: 50)
                    }

                    // TODO: This probably needs its own file
                    if !feed.publications.isEmpty {
                        let columns: [GridItem] = [GridItem(.adaptive(minimum: 150 + 8))]
                        LazyVGrid(columns: columns) {
                            ForEach(feed.publications) { publication in
                                let authors = publication.metadata.authors
                                    .map(\.name)
                                    .joined(separator: ", ")
                                NavigationLink(value: OPDSPublication(from: publication)) {
                                    BookCover(
                                        title: publication.metadata.title ?? "",
                                        authors: authors,
                                        url: publication.images.first
                                            .flatMap { URL(string: $0.href) }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Divider().frame(height: 50)
                    }

                    if !feed.groups.isEmpty {
                        ForEach(feed.groups as [ReadiumShared.Group]) { group in
                            CatalogGroup(group: group)
                                .padding([.bottom], 25)
                        }
                    }
                }
            }
        }
        .padding()
        .navigationTitle(catalog.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if parseData == nil {
                await parseFeed()
            }
        }
    }
}

extension CatalogFeed {
    func parseFeed() async {
        if let url = URL(string: catalog.url) {
            OPDSParser.parseURL(url: url) { data, _ in
                self.parseData = data
            }
        }
    }
}

struct CatalogDetail_Previews: PreviewProvider {
    static var previews: some View {
        let catalog = Catalog(title: "Test", url: "https://www.test.com")
        CatalogFeed(catalog: catalog)
    }
}
