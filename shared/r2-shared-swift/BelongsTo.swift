//
//  BelongsTo.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 10/27/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

/// Used to establish a relation between a publication and a serie or a collection
public class BelongsTo {
    public init() {}

    public var series = [PublicationCollection]()
    public var collection = [PublicationCollection]()
}
