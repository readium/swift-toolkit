//
//  Metadata+Presentation.swift
//  r2-shared-swift
//
//  Created by Mickaël on 24/02/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

private let presentationKey = "presentation"

/// Presentation extensions for `Metadata`.
extension Metadata {
    
    public var presentation: Presentation {
        get {
            do {
                return try Presentation(json: otherMetadata[presentationKey])
            } catch {
                log(.warning, error)
                return Presentation()
            }
        }
        set {
            let json = newValue.json
            if !json.isEmpty {
                otherMetadata[presentationKey] = json
            } else {
                otherMetadata.removeValue(forKey: presentationKey)
            }
        }
    }
    
}
