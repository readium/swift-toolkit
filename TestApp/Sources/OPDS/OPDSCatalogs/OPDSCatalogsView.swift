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
                    viewModel.onCatalogTap(catalog)
                }
                .swipeActions(allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.onDeleteCatalogTap(catalog)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    
                    Button {
                        viewModel.onEditCatalogTap(catalog)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }
        }
        .listStyle(.plain)
        .onAppear {
            viewModel.viewDidAppear()
        }
    }
}

#Preview {
    OPDSCatalogsView(viewModel: OPDSCatalogsViewModel())
}
