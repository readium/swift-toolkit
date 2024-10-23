//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

final class OPDSCatalogsViewModel: ObservableObject {
    @Published var catalogs: [OPDSCatalog] = [] {
        didSet {
            print("===> \(catalogs.count)")
        }
    }
    
    var openCatalog: ((URL, IndexPath) -> Void)?
    
    private let userDefaultsID = "opdsCatalogArray"
    private var isFirstAppear = false
    
    func viewDidAppear() {
        guard !isFirstAppear else { return }
        isFirstAppear = true
        preloadTestFeeds()
    }
    
    func onCatalogTap(_ catalog: OPDSCatalog) {
        guard
            let openCatalog,
            let index = catalogs.firstIndex(of: catalog)
        else {
            assertionFailure("openCatalog closure have to be set")
            return
        }
        openCatalog(catalog.url, IndexPath(row: index, section: 0))
    }
    
    func onEditCatalogTap(_ catalog: OPDSCatalog) {
        print("===> onEditCatalogTap \(catalog.title)")
    }
    
    func onDeleteCatalogTap(_ catalog: OPDSCatalog) {
        print("===> onDeleteCatalogTap \(catalog.title)")
    }
    
    private func preloadTestFeeds() {
        let catalogsArray = UserDefaults.standard.array(forKey: userDefaultsID) as? [[String: String]]
        self.catalogs = catalogsArray?
            .compactMap(OPDSCatalog.init) ?? []
        
        let oldVersion = UserDefaults.standard.integer(forKey: .versionKey)
        
        if
            self.catalogs.isEmpty || oldVersion < .currentVersion
        {
            setDefaultCatalogs()
        }
    }
    
    private func setDefaultCatalogs() {
        UserDefaults.standard.set(.currentVersion, forKey: .versionKey)
        self.catalogs = .testData
        UserDefaults.standard.set(
            catalogs.map(\.toDictionary),
            forKey: userDefaultsID
        )
    }
}

private extension String {
    static let versionKey = "VERSION_KEY"
}

private extension Int {
    static let currentVersion = 2
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
