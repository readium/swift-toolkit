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

struct CatalogsTab: View {
    var body: some View {
        NavigationView {
            Text("Catalogs tab")
                .navigationTitle("Catalogs")
                .toolbar(content: toolbarContent)
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
        var catalogData: [[String: String]]?
        let userDefaultsID = "opdsCatalogArray"
        let version = 2
        let VERSION_KEY = "OPDS_CATALOG_VERSION"
        let OPDS2Catalog = ["title": "OPDS 2.0 Test Catalog", "url": "https://test.opds.io/2.0/home.json"]
        let OTBCatalog = ["title": "Open Textbooks Catalog", "url": "http://open.minitex.org/textbooks"]
        let SEBCatalog = ["title": "Standard eBooks Catalog", "url": "https://standardebooks.org/opds/all"]
        
        catalogData = UserDefaults.standard.array(forKey: userDefaultsID) as? [[String: String]]
        let oldversion = UserDefaults.standard.integer(forKey: VERSION_KEY)
        if (catalogData == nil || oldversion < version) {
            UserDefaults.standard.set(version, forKey: VERSION_KEY)
            catalogData = [
                OPDS2Catalog, OTBCatalog, SEBCatalog
            ]
            UserDefaults.standard.set(catalogData, forKey: userDefaultsID)
        }
        
    }
}

struct CatalogsTab_Previews: PreviewProvider {
    static var previews: some View {
        CatalogsTab()
    }
}
