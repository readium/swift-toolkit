//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct Catalogs: View {
    
    @ObservedObject var viewModel: CatalogsViewModel
    let catalogDetail: (Catalog) -> CatalogDetail
    
    @State private var showingSheet = false
    
    var body: some View {
        NavigationView {
            VStack {
                if let catalogs = viewModel.catalogs {
                    List() {
                        ForEach(catalogs, id: \.id) { catalog in
                            NavigationLink(destination: catalogDetail(catalog)) {
                                ListRowItem(title: catalog.title)
                            }
                        }
                    }
                    .listStyle(DefaultListStyle())
                }
            }
            .navigationTitle("Catalogs")
            .toolbar(content: toolbarContent)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showingSheet) {
            AddFeedSheet(showingSheet: $showingSheet) { title, url in
                // TODO validate the URL and import the feed
            }
        }
    }
    
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            AddButton {
                showingSheet = true
            }
        }
    }
}
