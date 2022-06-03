//
//  CatalogDetailViewModel.swift
//  TestApp
//
//  Created by Steven Zeck on 5/25/22.
//
//  Copyright 2022 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
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
