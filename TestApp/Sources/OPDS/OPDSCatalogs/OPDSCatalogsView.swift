//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct OPDSCatalogsView: View {
    @StateObject private var viewModel: OPDSCatalogsViewModel
    
    init(viewModel: OPDSCatalogsViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        List(viewModel.catalogs) { catalog in
            OPDSCatalogRow(title: catalog.title)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.onCatalogTap(id: catalog.id)
                }
                .swipeActions(allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.onDeleteCatalogTap(id: catalog.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    
                    Button {
                        viewModel.onEditCatalogTap(id: catalog.id)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }
        }
        .listStyle(.plain)
        .onAppear {
            viewModel.viewDidAppear()
        }
        .sheet(item: $viewModel.editingCatalog) { catalog in
            EditOPDSCatalogView(catalog: catalog)
        }
    }
}

#Preview {
    OPDSCatalogsView(viewModel: OPDSCatalogsViewModel())
}
