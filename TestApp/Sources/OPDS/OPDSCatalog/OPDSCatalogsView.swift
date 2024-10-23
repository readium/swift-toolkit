//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct OPDSCatalogsView: View {
    @StateObject private var viewModel = OPDSCatalogsViewModel()
    
    var body: some View {
        List(
            viewModel.catalogs
        ) { catalog in
            OPDSCatalogRow(title: catalog.title)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.onCatalogTap(catalog)
                }
        }
        .onAppear {
            viewModel.viewDidAppear()
        }
    }
}

#Preview {
    OPDSCatalogsView()
}
