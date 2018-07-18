//
//  MetadataItem.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 2/16/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Represents a miscellaneous metadata element.
public class MetadataItem {
    public var property: String?
    public var value: String?
    public var children = [MetadataItem]()

    public init() {}
}
