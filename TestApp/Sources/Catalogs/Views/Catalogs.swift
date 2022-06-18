//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI
import ReadiumOPDS

struct Catalogs: View {
    
    let catalogRepository: CatalogRepository
    let catalogDetail: (Catalog) -> CatalogDetail
    
    @State private var showingSheet = false
    @State private var showingAlert = false
    @State private var catalogs: [Catalog] = []
    
    var body: some View {
        NavigationView {
            VStack {
                List() {
                    ForEach(catalogs, id: \.id) { catalog in
                        NavigationLink(destination: catalogDetail(catalog)) {
                            ListRowItem(title: catalog.title)
                        }
                    }
                    .onDelete { offsets in
                        let catalogIds = offsets.map { catalogs[$0].id! }
                        Task {
                            try await deleteCatalogs(ids: catalogIds)
                        }
                    }
                }
                .onReceive(catalogRepository.all()) {
                    catalogs = $0 ?? []
                }
                .listStyle(DefaultListStyle())
                
            }
            .navigationTitle("Catalogs")
            .toolbar(content: toolbarContent)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showingSheet) {
            AddFeedSheet(showingSheet: $showingSheet) { title, url in
                Task {
                    do {
                        _ = try await OPDSParser.parseURL(url: URL(string: url)!)
                        try await addCatalog(catalog: Catalog(title: title, url: url))
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
            Button(.add) {
                showingSheet = true
            }
        }
    }
}

extension Catalogs {
    
    func addCatalog(catalog: Catalog) async throws {
        var savedCatalog = catalog
        try? await catalogRepository.save(&savedCatalog)
    }
    
    func deleteCatalogs(ids: [Catalog.Id]) async throws {
        try? await catalogRepository.delete(ids: ids)
    }
}
