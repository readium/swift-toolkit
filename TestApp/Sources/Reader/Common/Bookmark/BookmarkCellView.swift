//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct BookmarkCellView: View {
    let bookmark: Bookmark
    var body: some View {
        Text(bookmark.locator.title ?? "")
            .frame(maxWidth: .infinity)
            .padding()
    }
}
