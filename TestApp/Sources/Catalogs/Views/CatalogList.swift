//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI
import ReadiumOPDS

struct CatalogList: View {
    
    let catalogRepository: CatalogRepository
    let catalogFeed: (Catalog) -> CatalogFeed
    
    @State private var showingSheet = false
    @State private var showingAlert = false
    @State private var catalogs: [Catalog] = []
    
    var body: some View {
        VStack {
            List() {
                ForEach(catalogs, id: \.id) { catalog in
                    NavigationLink(destination: catalogFeed(catalog)) {
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

extension CatalogList {
    
    func addCatalog(catalog: Catalog) async throws {
        var savedCatalog = catalog
        try? await catalogRepository.save(&savedCatalog)
    }
    
    func deleteCatalogs(ids: [Catalog.Id]) async throws {
        try? await catalogRepository.delete(ids: ids)
    }
}
