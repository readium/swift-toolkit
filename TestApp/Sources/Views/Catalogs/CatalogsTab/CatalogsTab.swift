//
//  CatalogsTab.swift
//  TestApp
//
//  Created by Steven Zeck on 5/15/22.
//
//  Copyright 2022 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import GRDBQuery
import SwiftUI

struct CatalogsTab: View {
    
    @EnvironmentStateObject private var viewModel: CatalogsTabViewModel
    
    init() {
        _viewModel = EnvironmentStateObject {
            CatalogsTabViewModel(
                db: $0.db)
        }
    }
    
    var body: some View {
        
        NavigationView {
            if let catalogs = viewModel.catalogs {
                List() {
                    ForEach(catalogs, id: \.id) { catalog in
                        NavigationLink(destination: CatalogDetail(catalog: catalog)) {
                            ListRowItem(title: catalog.title)
                        }
                    }
                }
                
                .listStyle(SidebarListStyle())
                .navigationTitle(title)
                .toolbar(content: toolbarContent)
            }
        }
    }
}

extension CatalogsTab {
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            AddButton {
                
            }
        }
    }
    
    var title: String {
        return "Catalogs"
    }
}

struct CatalogsTab_Previews: PreviewProvider {
    static var previews: some View {
        CatalogsTab()
    }
}
