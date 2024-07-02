//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

struct CatalogGroup: View {
    var group: ReadiumShared.Group

    var body: some View {
        VStack(alignment: .leading) {
            let rows = [GridItem(.flexible(), alignment: .top)]
            HStack {
                Text(group.metadata.title).font(.title3)
                if !group.links.isEmpty {
                    let navigationLink = Catalog(title: group.metadata.title, url: group.links.first!.href)
                    NavigationLink(value: navigationLink) {
                        ListRowItem(title: "See All").frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            if !group.publications.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: rows, spacing: 30) {
                        ForEach(group.publications) { publication in
                            let authors = publication.metadata.authors
                                .map(\.name)
                                .joined(separator: ", ")
                            NavigationLink(value: OPDSPublication(from: publication)) {
                                // FIXME: Ideally the title and author should not be truncated
                                BookCover(
                                    title: publication.metadata.title ?? "",
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
                NavigationLink(value: navigationLink) {
                    ListRowItem(title: navigation.title!)
                }
            }
        }
    }
}

// struct CatalogGroup_Previews: PreviewProvider {
//    static var previews: some View {
//        CatalogGroup()
//    }
// }
