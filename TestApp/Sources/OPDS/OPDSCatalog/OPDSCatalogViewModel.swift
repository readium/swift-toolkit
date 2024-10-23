//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

final class OPDSCatalogViewModel: ObservableObject {
    @Published var catalogs: [String] = []
    
    private var catalogData: [[String: String]]? {
        didSet {
            guard let catalogData else { return }
            catalogs = catalogData.compactMap { data in
                data["title"]
            }
        }
    }
    private let userDefaultsID = "opdsCatalogArray"
    private var isFirstAppear = false
    
    func viewDidAppear() {
        guard !isFirstAppear else { return }
        isFirstAppear = true
        preloadTestFeeds()
    }
    
    private func preloadTestFeeds() {
        let version = 2
        let VERSION_KEY = "OPDS_CATALOG_VERSION"
        
        catalogData = UserDefaults.standard.array(forKey: userDefaultsID) as? [[String: String]]
        
        let oldversion = UserDefaults.standard.integer(forKey: VERSION_KEY)
        
        if
            catalogData == nil || oldversion < version
        {
            UserDefaults.standard.set(version, forKey: VERSION_KEY)
            catalogData = .testData
            UserDefaults.standard.set(catalogData, forKey: userDefaultsID)
        }
    }
}

private extension [[String: String]] {
    static let testData: [[String: String]] = [
        ["title": "OPDS 2.0 Test Catalog", "url": "https://test.opds.io/2.0/home.json"],
        ["title": "Open Textbooks Catalog", "url": "http://open.minitex.org/textbooks"],
        ["title": "Standard eBooks Catalog", "url": "https://standardebooks.org/opds/all"]
    ]
}
