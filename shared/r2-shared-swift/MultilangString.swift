//
//  MultilangString.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 3/30/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

extension MultilangString {}

/// `MultilangString` is designed to containe : a`singleString` (the
/// mainTitle) and possiby a `multiString` (the mainTitle + the altTitles).
/// It's mainly here for the JSON serialisation, depending if we need a simple
/// String or an array depending of the situation.
public class MultilangString {
    /// Contains the main denomination.
    public var singleString: String?
    /// Contains the alternatives denominations and keyed by language codes, if any.
    public var multiString =  [String: String]()

    public init() {}
}
