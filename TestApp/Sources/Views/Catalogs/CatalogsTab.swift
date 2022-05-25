//
//  CatalogsTab.swift
//  TestApp
//
//  Created by Steven Zeck on 5/15/22.
//
//  Copyright 2022 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import SwiftUI
import GRDB
import GRDBQuery

struct CatalogsTab: View {
    
    @Environment(\.dbQueue) private var dbQueue
    
    @Query(CatalogFeedListRequest())
    var catalogs: [Catalog]
    
    var body: some View {
        
        NavigationView {
            List() {
                ForEach(catalogs, id: \.id) { catalog in
                    //                    NavigationLink(destination: CatalogDetail(catalog: catalog)) {
                    CatalogFeedRow(title: catalog.title)
                    //                    }
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Catalogs")
            .toolbar(content: toolbarContent)
        }
        .onAppear {
            preloadTestFeeds()
        }
    }
}

extension CatalogsTab {
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            AddButton {
                
            }
        }
    }
}

extension CatalogsTab {
    func preloadTestFeeds() {
        let version = 2
        let VERSION_KEY = "OPDS_CATALOG_VERSION"
        let OPDS2Catalog = Catalog(id: 1, title: "OPDS 2.0 Test Catalog", url: "https://test.opds.io/2.0/home.json")
        let OTBCatalog = Catalog(id: 2, title: "Open Textbooks Catalog", url: "http://open.minitex.org/textbooks")
        let SEBCatalog = Catalog(id: 3, title: "Standard eBooks Catalog", url: "https://standardebooks.org/opds/all")
        
        let oldversion = UserDefaults.standard.integer(forKey: VERSION_KEY)
        if (catalogs.isEmpty || oldversion < version) {
            UserDefaults.standard.set(version, forKey: VERSION_KEY)
            try! dbQueue.write { db in
                _ = try OPDS2Catalog.inserted(db)
            }
            try! dbQueue.write { db in
                _ = try OTBCatalog.inserted(db)
            }
            try! dbQueue.write { db in
                _ = try SEBCatalog.inserted(db)
            }
        }
    }
}

struct CatalogsTab_Previews: PreviewProvider {
    static var previews: some View {
        CatalogsTab()
    }
}
