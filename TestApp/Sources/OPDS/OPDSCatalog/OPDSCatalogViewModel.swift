//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

final class OPDSCatalogViewModel: ObservableObject {
    @Published var catalogs: [OPDSCatalog] = []
    
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
        
        let catalogsArray = UserDefaults.standard.array(forKey: userDefaultsID) as? [[String: String]]
        catalogs = catalogsArray?.compactMap(OPDSCatalog.init) ?? []
        
        let oldversion = UserDefaults.standard.integer(forKey: VERSION_KEY)
        
        if
            catalogs.isEmpty || oldversion < version
        {
            UserDefaults.standard.set(version, forKey: VERSION_KEY)
            catalogs = .testData
            UserDefaults.standard.set(
                catalogs.map(\.toDictionary),
                forKey: userDefaultsID
            )
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

private extension Array where Element == OPDSCatalog {
    static let testData: [OPDSCatalog] = [
        OPDSCatalog(
            title: "OPDS 2.0 Test Catalog",
            url: URL(string: "https://test.opds.io/2.0/home.json")!
        ),
        OPDSCatalog(
            title: "Open Textbooks Catalog",
            url: URL(string: "http://open.minitex.org/textbooks")!
        ),
        OPDSCatalog(
            title: "Standard eBooks Catalog",
            url: URL(string: "https://standardebooks.org/opds/all")!
        )
    ]
}
