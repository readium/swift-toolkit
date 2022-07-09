//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI
import R2Shared

struct CatalogGroup: View {
    
    var group: R2Shared.Group
    let publicationDetail: (Publication) -> PublicationDetail
    let catalogDetail: (Catalog) -> CatalogDetail
    
    var body: some View {
        VStack(alignment: .leading) {
            let rows = [GridItem(.flexible(), alignment: .top)]
            HStack {
                Text(group.metadata.title).font(.title3)
                if !group.links.isEmpty {
                    let navigationLink = Catalog(title: group.links.first!.title ?? "Catalog", url: group.links.first!.href)
                    NavigationLink(destination: catalogDetail(navigationLink)) {
                        ListRowItem(title: "See All").frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            if !group.publications.isEmpty {
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
            ForEach(group.navigation, id: \.self) { navigation in
                let navigationLink = Catalog(title: navigation.title ?? "Catalog", url: navigation.href)
                NavigationLink(destination: catalogDetail(navigationLink)) {
                    ListRowItem(title: navigation.title!)
                }
            }
        }
    }
}

//struct CatalogGroup_Previews: PreviewProvider {
//    static var previews: some View {
//        CatalogGroup()
//    }
//}
