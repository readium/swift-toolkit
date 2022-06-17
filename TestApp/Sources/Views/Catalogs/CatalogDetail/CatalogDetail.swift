//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI
import R2Shared

struct CatalogDetail: View {
    
    @ObservedObject var viewModel: CatalogDetailViewModel
    let catalogDetail: (Catalog) -> CatalogDetail
    let publicationDetail: (Publication) -> PublicationDetail
    
    var body: some View {
        
        VStack {
            if let parseData = viewModel.parseData {
                List() {
                    if (!(parseData.feed?.navigation.isEmpty)!) {
                        Section(header: Text("Navigation")) {
                            ForEach(parseData.feed!.navigation, id: \.self) { link in
                                let navigationLink = Catalog(title: link.title ?? "Catalog", url: link.href)
                                NavigationLink(destination: catalogDetail(navigationLink)) {
                                    ListRowItem(title: link.title!)
                                }
                            }
                        }
                    }
                    
                    // TODO This probably needs its own file
                    if (!(parseData.feed?.publications.isEmpty)!) {
                        Section(header: Text("Publications")) {
                            
                        }
                    }
                    
                    // TODO This probably needs its own file
                    if (!(parseData.feed?.groups.isEmpty)!) {
                        Section(header: Text("Groups")) {
                            
                        }
                    }
                }
                .listStyle(GroupedListStyle())
            }
        }
        .navigationTitle(viewModel.catalog.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await viewModel.parseFeed()
            }
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
        CatalogDetail(viewModel: CatalogDetailViewModel(catalog: catalog), catalogDetail: { _ in fatalError() },
                      publicationDetail: { _ in fatalError() }
        )
    }
}
