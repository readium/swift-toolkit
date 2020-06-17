//
//  Fetcher.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 08/06/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

extension Fetcher {

    /// Returns the data of a file at given `href`.
    func readData(at href: String) throws -> Data {
        return try get(href).read().get()
    }

}
