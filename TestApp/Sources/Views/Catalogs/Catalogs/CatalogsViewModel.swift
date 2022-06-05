//
//  CatalogsViewModel.swift
//  TestApp
//
//  Created by Steven Zeck on 5/25/22.
//
//  Copyright 2022 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import GRDB
import Combine
import Foundation

final class CatalogsViewModel: ObservableObject {
    
    @Published var catalogs: [Catalog]?
    var catalogRepository: CatalogRepository
    
    init(catalogRepository: CatalogRepository) {
        self.catalogRepository = catalogRepository
//        ValueObservation
//            .tracking(Catalog.order(Catalog.Columns.created).fetchAll)
//            .publisher(in: db.databaseReader, scheduling: .immediate)
//            .assertNoFailure()
//            .assign(to: &catalogs)
        Task {
            await preloadTestFeeds()
        }
    }
    
    func preloadTestFeeds() async {
        let version = 2
        let VERSION_KEY = "OPDS_CATALOG_VERSION"
        var OPDS2Catalog = Catalog(title: "OPDS 2.0 Test Catalog", url: "https://test.opds.io/2.0/home.json")
        var OTBCatalog = Catalog(title: "Open Textbooks Catalog", url: "http://open.minitex.org/textbooks")
        var SEBCatalog = Catalog(title: "Standard eBooks Catalog", url: "https://standardebooks.org/opds/all")
        
        let oldversion = UserDefaults.standard.integer(forKey: VERSION_KEY)
        if (oldversion < version) {
            UserDefaults.standard.set(version, forKey: VERSION_KEY)
            do {
                try await catalogRepository.saveCatalog(&OPDS2Catalog)
                try await catalogRepository.saveCatalog(&OTBCatalog)
                try await catalogRepository.saveCatalog(&SEBCatalog)
            } catch {
                
            }
        }
    }
}
