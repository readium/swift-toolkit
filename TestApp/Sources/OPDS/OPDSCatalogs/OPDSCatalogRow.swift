//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct OPDSCatalogRow: View {
    let title: String

    var body: some View {
        HStack {
            Image(systemName: "books.vertical.fill")
                .foregroundColor(.accentColor)
            Text(title)
        }
    }
}

#Preview {
    OPDSCatalogRow(
        title: "OPDS 2.0 Test Catalog"
    )
    .padding()
}
