//
//  EPUBMetadata.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 14.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// EPUB Metadata Extension
/// https://readium.org/webpub-manifest/schema/extensions/epub/metadata.schema.json
protocol EPUBMetadata {
    
    var rendition: EPUBRendition? { get set }
    
}


private let renditionKey = "rendition"

extension Metadata: EPUBMetadata {
    
    public var rendition: EPUBRendition? {
        get {
            do {
                return try EPUBRendition(json: otherMetadata[renditionKey])
            } catch {
                log(.warning, error)
                return nil
            }
        }
        set {
            if let json = newValue?.json, !json.isEmpty {
                otherMetadata[renditionKey] = json
            } else {
                otherMetadata.removeValue(forKey: renditionKey)
            }
        }
    }
    
}
