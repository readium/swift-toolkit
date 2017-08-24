//
//  MetadataItem.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/16/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

/// Represents a miscellaneous metadata element.
public class MetadataItem {
    public var property: String?
    public var value: String?
    public var children = [MetadataItem]()
}
