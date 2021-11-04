//
//  Facet.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 10/27/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

/// Enables faceted navigation in OPDS.
public class Facet {
    public var metadata: OpdsMetadata
    public var links = [Link]()

    public init(title: String) {
        self.metadata = OpdsMetadata(title: title)
    }
}
