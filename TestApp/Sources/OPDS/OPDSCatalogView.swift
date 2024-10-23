//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct OPDSCatalogView: View {
    var catalogs = [
        "OPDS 2.0 Test Catalog",
        "Open Textbooks Catalog",
        "Standard eBooks Catalog",
        "Public Domain Books",
        "Project Gutenberg",
        "Free eBooks Library",
        "Sci-Fi eBooks Catalog",
        "Fantasy Novels Collection",
        "Academic Publications Hub",
        "Historical Texts Archive",
        "Modern Literature Catalog",
        "Mystery and Thriller Books",
        "Children's Book Library",
        "Classic Literature",
        "Educational Resources Catalog",
        "Scientific Journals Collection",
        "Romance Novels Hub",
        "Horror Books Catalog",
        "Poetry and Anthology Collection",
        "Philosophy Books Archive",
        "Self-Help Books Hub",
        "Technology and IT Books",
        "Travel Guides and Journals"
    ]
    
    var body: some View {
        List(
            catalogs, id: \.self
        ) { catalog in
            OPDSCatalogRow(title: catalog)
        }
    }
}

#Preview {
    OPDSCatalogView()
}
