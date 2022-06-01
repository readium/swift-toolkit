//
//  CatalogDetail.swift
//  TestApp
//
//  Created by Steven Zeck on 5/25/22.
//
//  Copyright 2022 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import GRDBQuery
import SwiftUI

struct CatalogDetail: View {
    
    @EnvironmentStateObject private var viewModel: CatalogDetailViewModel
    
    init(catalog: Catalog) {
        _viewModel = EnvironmentStateObject {_ in
            CatalogDetailViewModel(
                catalog: catalog)
        }
    }
    
    var body: some View {
        
        NavigationView {
//            VStack {
                if let parseData = viewModel.parseData {
                    List(parseData.feed!.navigation, id: \.self) { link in
//                        NavigationLink(destination: CatalogDetail()) {
                            ListRowItem(title: link.title!)
//                        }
                    }
                    .listStyle(SidebarListStyle())
                }
//            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.parseFeed()
        }
    }
}

extension CatalogDetail {
    var title: String {
        return viewModel.catalog.title
    }
}

struct CatalogDetail_Previews: PreviewProvider {
    static var previews: some View {
        let catalog = Catalog(title: "Test", url: "https://www.test.com")
        CatalogDetail(catalog: catalog)
    }
}
