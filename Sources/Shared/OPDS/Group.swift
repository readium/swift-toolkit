//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

/// A substructure of a feed.
public class Group {
    public var metadata: OpdsMetadata
    public var links = [Link]()
    public var publications = [Publication]()
    public var navigation = [Link]()

    public init(title: String) {
        metadata = OpdsMetadata(title: title)
    }
}
