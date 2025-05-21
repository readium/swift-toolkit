//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// OPDS metadata properties.
public class OpdsMetadata {
    public var title: String
    public var numberOfItem: Int?
    public var itemsPerPage: Int?
    public var currentPage: Int?
    public var modified: Date?
    public var position: Int?
    public var rdfType: String?

    init(title: String) {
        self.title = title
    }
}
