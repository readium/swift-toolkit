//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import GRDB
import Combine
import Foundation

final class CatalogsViewModel: ObservableObject {
    
    @Published var catalogs: [Catalog]?
    private var catalogRepository: CatalogRepository
    
    init(catalogRepository: CatalogRepository) {
        self.catalogRepository = catalogRepository
        catalogRepository.all()
            .assign(to: &$catalogs)
    }
    
    func addCatalog(catalog: Catalog) async throws {
        var savedCatalog = catalog
        try? await catalogRepository.save(&savedCatalog)
    }
    
    func deleteCatalogs(ids: [Catalog.Id]) async throws {
        try? await catalogRepository.delete(ids: ids)
    }
}
