//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI
import R2Shared
import ReadiumOPDS

struct CatalogDetail: View {
    
    @State var catalog: Catalog
    @State private var parseData: ParseData?
    
    let catalogDetail: (Catalog) -> CatalogDetail
    let publicationDetail: (Publication) -> PublicationDetail
    
    var body: some View {
        
        ScrollView {
            VStack(alignment: .leading) {
                if let feed = parseData?.feed {
                    if !feed.navigation.isEmpty {
                        Text("Navigation").font(.title2)
                        ForEach(feed.navigation, id: \.self) { link in
                            let navigationLink = Catalog(title: link.title ?? "Catalog", url: link.href)
                            NavigationLink(destination: catalogDetail(navigationLink)) {
                                ListRowItem(title: link.title!)
                            }
                        }
                    }
                    
                    // TODO This probably needs its own file
                    if !feed.publications.isEmpty {
                        let columns: [GridItem] = Array(repeating: .init(.flexible(), alignment: .top), count: 2)
                        Text("Publications").font(.title2)
                        LazyVGrid(columns: columns) {
                            ForEach(feed.publications) { publication in
                                let authors = publication.metadata.authors
                                    .map { $0.name }
                                    .joined(separator: ", ")
                                NavigationLink(destination: publicationDetail(publication)) {
                                    BookCover(
                                        title: publication.metadata.title,
                                        authors: authors,
                                        url: publication.images.first
                                            .map { URL(string: $0.href)! }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // TODO This probably needs its own file
                    if !feed.groups.isEmpty {
                        Text("Groups").font(.title2)
                        let rows = [GridItem(.flexible(), alignment: .top)]
                        ForEach(feed.groups) { group in
                            Text(group.metadata.title).font(.title3)
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHGrid(rows: rows, spacing: 30) {
                                    ForEach(group.publications) { publication in
                                        let authors = publication.metadata.authors
                                            .map { $0.name }
                                            .joined(separator: ", ")
                                        NavigationLink(destination: publicationDetail(publication)) {
                                            // FIXME Ideally the title and author should not be truncated
                                            BookCover(
                                                title: publication.metadata.title,
                                                authors: authors,
                                                url: publication.images.first
                                                    .map { URL(string: $0.href)! }
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(catalog.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await parseFeed()
            }
        }
    }
}

extension CatalogDetail {
    
    func parseFeed() async {
        if let url = URL(string: catalog.url) {
            self.parseData = try? await OPDSParser.parseURL(url: url)
        }
    }
}

// FIXME this causes a Swift compiler error segmentation fault 11

//struct CatalogDetail_Previews: PreviewProvider {
//    static var previews: some View {
//        let catalog = Catalog(title: "Test", url: "https://www.test.com")
//        let catalogDetail: (Catalog) -> CatalogDetail = { CatalogDetail(CatalogDetailViewModel(catalog: catalog)) }
//        CatalogDetail(viewModel: CatalogDetailViewModel(catalog: catalog), catalogDetail: catalogDetail)
//    }
//}

struct CatalogDetail_Previews: PreviewProvider {
    static var previews: some View {
        let catalog = Catalog(title: "Test", url: "https://www.test.com")
        CatalogDetail(catalog: catalog, catalogDetail: { _ in fatalError() },
                      publicationDetail: { _ in fatalError() }
        )
    }
}
