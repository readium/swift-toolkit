//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct CatalogDetail: View {
    
    @ObservedObject var viewModel: CatalogDetailViewModel
    
    var body: some View {
        
        VStack {
            if let parseData = viewModel.parseData {
                List(parseData.feed!.navigation, id: \.self) { link in
                    //                        NavigationLink(destination: CatalogDetail()) {
                    ListRowItem(title: link.title!)
                    //                        }
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

struct CatalogDetail_Previews: PreviewProvider {
    static var previews: some View {
        let catalog = Catalog(title: "Test", url: "https://www.test.com")
        CatalogDetail(viewModel: CatalogDetailViewModel(catalog: catalog))
    }
}
