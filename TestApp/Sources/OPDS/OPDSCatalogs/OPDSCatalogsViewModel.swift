//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

@Observable
final class OPDSCatalogsViewModel {
    var catalogs: [OPDSCatalog] = [] {
        didSet {
            UserDefaults.standard.set(
                catalogs.map(\.toDictionary),
                forKey: userDefaultsID
            )
        }
    }

    var editingCatalog: OPDSCatalog?

    var openCatalog: ((URL, IndexPath) -> Void)?

    private let userDefaultsID = "opdsCatalogArray"
    private var isFirstAppear = false

    func viewDidAppear() {
        guard !isFirstAppear else { return }
        isFirstAppear = true
        preloadTestFeeds()
    }

    func onCatalogTap(id: OPDSCatalog.ID) {
        guard
            let openCatalog,
            let index = catalogs.firstIndex(where: { $0.id == id })
        else {
            assertionFailure("openCatalog closure have to be set")
            return
        }
        openCatalog(catalogs[index].url, IndexPath(row: index, section: 0))
    }

    func onEditCatalogTap(id: OPDSCatalog.ID) {
        guard
            let catalog = catalogs.first(where: { $0.id == id })
        else { return }
        editingCatalog = catalog
    }

    func onDeleteCatalogTap(id: OPDSCatalog.ID) {
        guard
            let index = catalogs.firstIndex(where: { $0.id == id })
        else { return }
        catalogs.remove(at: index)
    }

    func onSaveEditedCatalogTap(_ catalog: OPDSCatalog) {
        if
            let index = catalogs.firstIndex(where: { $0.id == catalog.id })
        {
            catalogs[index] = catalog
        } else {
            catalogs.append(catalog)
        }
        editingCatalog = nil
    }

    func onAddCatalogTap() {
        let newCatalog = OPDSCatalog(
            id: UUID().uuidString,
            title: "",
            url: URL(string: "http://")!
        )
        editingCatalog = newCatalog
    }

    private func preloadTestFeeds() {
        let catalogsArray = UserDefaults.standard.array(forKey: userDefaultsID) as? [[String: String]]
        catalogs = catalogsArray?
            .compactMap(OPDSCatalog.init) ?? []

        let oldVersion = UserDefaults.standard.integer(forKey: .versionKey)

        if
            catalogs.isEmpty || oldVersion < .currentVersion
        {
            setDefaultCatalogs()
        }
    }

    private func setDefaultCatalogs() {
        UserDefaults.standard.set(.currentVersion, forKey: .versionKey)
        catalogs = .testData
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
    ]
}

private extension Array where Element == OPDSCatalog {
    static let testData: [OPDSCatalog] = [
        OPDSCatalog(
            id: UUID().uuidString,
            title: "OPDS 2.0 Test Catalog",
            url: URL(string: "https://test.opds.io/2.0/home.json")!
        ),
        OPDSCatalog(
            id: UUID().uuidString,
            title: "Open Textbooks Catalog",
            url: URL(string: "http://open.minitex.org/textbooks")!
        ),
    ]
}
