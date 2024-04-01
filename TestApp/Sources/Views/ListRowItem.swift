//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct ListRowItem: View {
    var action: () -> Void = {}
    var title: String

    var body: some View {
        Text(title)
            .font(.title3)
            .padding(.vertical, 8)
    }
}

struct CatalogFeedRow_Previews: PreviewProvider {
    static var previews: some View {
        ListRowItem(title: "Test")
    }
}
