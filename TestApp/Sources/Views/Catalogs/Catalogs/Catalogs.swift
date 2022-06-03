//
//  Catalogs.swift
//  TestApp
//
//  Created by Steven Zeck on 5/15/22.
//
//  Copyright 2022 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import SwiftUI

struct Catalogs: View {
    
    @ObservedObject var viewModel: CatalogsViewModel
    let catalogDetail: (Catalog) -> CatalogDetail
    
    @State private var showingSheet = false
    
    var body: some View {
        NavigationView {
            if let catalogs = viewModel.catalogs {
                List() {
                    ForEach(catalogs, id: \.id) { catalog in
                        NavigationLink(destination: catalogDetail(catalog)) {
                            ListRowItem(title: catalog.title)
                        }
                    }
                }
                .listStyle(SidebarListStyle())
                .navigationTitle("Catalogs")
                .toolbar(content: toolbarContent)
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showingSheet) {
            AddFeedSheet(showingSheet: $showingSheet) { title, url in
                // TODO validate the URL and import the feed
            }
        }
    }
    
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            AddButton {
                showingSheet = true
            }
        }
    }
}
