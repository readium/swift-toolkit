//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumOPDS
import SwiftUI

final class CatalogDetailViewModel : ObservableObject {
    
    @Published var catalog: Catalog
    @Published var parseData: ParseData?
    
    init(catalog: Catalog) {
        self.catalog = catalog
    }
    
    @MainActor func parseFeed() async {
        if let url = URL(string: catalog.url) {
            self.parseData = try? await OPDSParser.parseURL(url: url)
        }
    }
}
