//
//  Group.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 10/27/17.
//  Copyright © 2017 Readium. All rights reserved.
//

/// A substructure of a feed.
public class Group {
    public var metadata: OpdsMetadata
    public var links = [Link]()
    public var publications = [Publication]()
    public var navigation = [Link]()

    public init(title: String) {
        self.metadata = OpdsMetadata(title: title)
    }
}
