//
//  URL.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 03/08/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

extension URL {
    
    /// Adds the given `newScheme` to the URL, but only if the URL doesn't already have one.
    public func addingSchemeIfMissing(_ newScheme: String) -> URL {
        guard scheme == nil else {
            return self
        }
        
        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        components?.scheme = newScheme
        return components?.url ?? self
    }

}
