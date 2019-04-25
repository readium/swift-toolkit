//
//  Link.swift
//  r2-navigator-swift
//
//  Created by Mickaël Menu on 25.04.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared


extension Link {
    
    /// Returns a Locator representation of this link.
    var locator: Locator {
        let components = href.split(separator: "#", maxSplits: 1).map(String.init)
        var fragment: String? = nil
        if components.count > 1 {
            fragment = String(components[1])
        }
        
        return Locator(
            href: components.first ?? href,
            type: type ?? "",  // FIXME: Shouldn't Locator.type be optional instead?
            title: title,
            locations: Locations(fragment: fragment)
        )
    }
    
}
