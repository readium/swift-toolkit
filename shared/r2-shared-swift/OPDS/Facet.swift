//
//  Facet.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 10/27/17.
//  Copyright © 2017 Readium. All rights reserved.
//

/// Enables faceted navigation in OPDS.
public class Facet {
    public var metadata: OpdsMetadata
    public var links = [Link]()

    public init(title: String) {
        self.metadata = OpdsMetadata(title: title)
    }
}
