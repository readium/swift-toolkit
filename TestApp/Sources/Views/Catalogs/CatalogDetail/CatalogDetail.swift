//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct CatalogDetail: View {
    
    @ObservedObject var viewModel: CatalogDetailViewModel
    let catalogDetail: (Catalog) -> CatalogDetail
    
    var body: some View {
        
        VStack {
            if let parseData = viewModel.parseData {
                List(parseData.feed!.navigation, id: \.self) { link in
                    let navigationLink = Catalog(title: link.title ?? "Catalog", url: link.href)
                    NavigationLink(destination: catalogDetail(navigationLink)) {
                        ListRowItem(title: link.title!)
                    }
                }
                .listStyle(DefaultListStyle())
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
        CatalogDetail(viewModel: CatalogDetailViewModel(catalog: catalog), catalogDetail: { _ in fatalError() })
    }
}
