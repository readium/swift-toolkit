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
    
    init(catalogRepository: CatalogRepository) {
        catalogRepository.all()
            .assign(to: &$catalogs)
    }
}
