//
//  MultilangString.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/30/17.
//  Copyright © 2017 Readium. All rights reserved.
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
