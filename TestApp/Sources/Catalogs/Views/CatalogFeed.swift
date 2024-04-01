//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import R2Shared
import ReadiumOPDS
import SwiftUI

struct CatalogFeed: View {
    var catalog: Catalog
    @State private var parseData: ParseData?

    let catalogFeed: (Catalog) -> CatalogFeed
    let publicationDetail: (Publication) -> PublicationDetail

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                if let feed = parseData?.feed {
                    if !feed.navigation.isEmpty {
                        ForEach(feed.navigation, id: \.self) { link in
                            let navigationLink = Catalog(title: link.title ?? "Catalog", url: link.href)
                            NavigationLink(destination: catalogFeed(navigationLink)) {
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
                                NavigationLink(destination: publicationDetail(publication)) {
                                    BookCover(
                                        title: publication.metadata.title,
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
                        ForEach(feed.groups as [R2Shared.Group]) { group in
                            CatalogGroup(group: group, publicationDetail: publicationDetail, catalogFeed: catalogFeed)
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

// FIXME: this causes a Swift compiler error segmentation fault 11

// struct CatalogDetail_Previews: PreviewProvider {
//    static var previews: some View {
//        let catalog = Catalog(title: "Test", url: "https://www.test.com")
//        let catalogDetail: (Catalog) -> CatalogDetail = { CatalogDetail(CatalogDetailViewModel(catalog: catalog)) }
//        CatalogDetail(viewModel: CatalogDetailViewModel(catalog: catalog), catalogDetail: catalogDetail)
//    }
// }

struct CatalogDetail_Previews: PreviewProvider {
    static var previews: some View {
        let catalog = Catalog(title: "Test", url: "https://www.test.com")
        CatalogFeed(catalog: catalog, catalogFeed: { _ in fatalError() },
                    publicationDetail: { _ in fatalError() })
    }
}
