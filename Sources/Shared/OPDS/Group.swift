//
//  Group.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 10/27/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
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
