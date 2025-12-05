//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

struct OPDSCatalog: Identifiable, Equatable {
    let id: String
    var title: String
    var url: URL

    var toDictionary: [String: String] {
        [
            "id": id,
            "title": title,
            "url": url.absoluteString,
        ]
    }
}

extension OPDSCatalog {
    init?(dictionary: [String: String]) {
        guard
            let title = dictionary["title"],
            let urlString = dictionary["url"],
            let url = URL(string: urlString)
        else { return nil }

        id = dictionary["id"] ?? UUID().uuidString
        self.title = title
        self.url = url
    }
}
