//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct OPDSCatalogView: View {
    @StateObject private var viewModel = OPDSCatalogViewModel()
    
    var body: some View {
        List(
            viewModel.catalogs, id: \.self
        ) { catalog in
            OPDSCatalogRow(title: catalog)
        }
        .onAppear {
            viewModel.viewDidAppear()
        }
    }
}

#Preview {
    OPDSCatalogView()
}
