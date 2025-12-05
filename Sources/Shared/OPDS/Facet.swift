//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

/// Enables faceted navigation in OPDS.
public class Facet {
    public var metadata: OpdsMetadata
    public var links = [Link]()

    public init(title: String) {
        metadata = OpdsMetadata(title: title)
    }
}
