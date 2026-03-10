//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

struct PublicationFixture {
    let filename: String
    let description: String

    var accessibilityIdentifier: String {
        "publication://\(filename)"
    }

    static let childrensLiteratureEPUB: PublicationFixture = .init(
        filename: "childrens-literature.epub",
        description: "Basic reflowable EPUB with a page-list."
    )

    static let daisyPDF: PublicationFixture = .init(
        filename: "daisy.pdf",
        description: "Basic PDF document."
    )
}
