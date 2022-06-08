//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI
import ReadiumOPDS

struct Catalogs: View {
    
    @ObservedObject var viewModel: CatalogsViewModel
    let catalogDetail: (Catalog) -> CatalogDetail
    
    @State private var showingSheet = false
    @State private var showingAlert = false
    
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
                Task {
                    do {
                        try await OPDSParser.parseURL(url: URL(string: url)!)
                        try await viewModel.addCatalog(catalog: Catalog(title: title, url: url))
                    } catch {
                        showingAlert = true
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingAlert, actions: {
            Button("OK", role: .cancel, action: {})
        }, message: {
            Text("Feed is not valid, please try again.")
        })
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
