//
//  OPDSAcquisition.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu, Alexandre Camilleri on 12.03.19.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// OPDS Acquisition Object
/// https://drafts.opds.io/schema/acquisition-object.schema.json
public struct OPDSAcquisition: Equatable {
    
    public var type: String
    public var children: [OPDSAcquisition] = []
    
    public var mediaType: MediaType { MediaType.of(mediaType: type) ?? .binary }
    
    public init(type: String, children: [OPDSAcquisition] = []) {
        self.type = type
        self.children = children
    }
    
    public init?(json: Any?, warnings: WarningLogger? = nil) throws {
        guard let jsonObject = json as? [String: Any],
            let type = jsonObject["type"] as? String else
        {
            warnings?.log("`type` is required", model: Self.self, source: json)
            throw JSONError.parsing(Self.self)
        }
        
        self.type = type
        self.children = [OPDSAcquisition](json: jsonObject["child"], warnings: warnings)
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "type": type,
            "child": encodeIfNotEmpty(children.json)
        ])
    }

}

extension Array where Element == OPDSAcquisition {
    
    /// Parses multiple JSON acquisitions into an array of OPDSAcquisitions.
    /// eg. let acquisitions = [OPDSAcquisition](json: [...])
    public init(json: Any?, warnings: WarningLogger? = nil) {
        self.init()
        guard let json = json as? [[String: Any]] else {
            return
        }
        
        let acquisitions = json.compactMap { try? OPDSAcquisition(json: $0, warnings: warnings) }
        append(contentsOf: acquisitions)
    }
    
    public var json: [[String: Any]] {
        return map { $0.json }
    }
    
}
