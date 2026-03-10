//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct OPDSCatalogsView: View {
    @State private var viewModel: OPDSCatalogsViewModel

    private var delegate: OPDSModuleDelegate?

    init(viewModel: OPDSCatalogsViewModel, delegate: OPDSModuleDelegate?) {
        self.viewModel = viewModel
        self.delegate = delegate
    }

    var body: some View {
        List(viewModel.catalogs) { catalog in
            NavigationLink(value: catalog) {
                OPDSCatalogRow(title: catalog.title)
            }
            .contentShape(Rectangle())
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.onAddCatalogTap()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $viewModel.editingCatalog) { catalog in
            EditOPDSCatalogView(catalog: catalog) { editingCatalog in
                viewModel.onSaveEditedCatalogTap(editingCatalog)
            }
        }
    }
}

#Preview {
    NavigationStack {
        OPDSCatalogsView(viewModel: OPDSCatalogsViewModel(), delegate: nil)
    }
}
