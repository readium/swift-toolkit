//
//  OPDSPublication.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 14.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// OPDS Web Publication Extension
public protocol OPDSPublication {
    
    var images: [Link] { get }
    
}

extension WebPublication: OPDSPublication {
    
    public var images: [Link] {
        return otherCollections.first(withRole: "images")?.links ?? []
    }

}
