//
//  Drm.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 10/5/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// An object giving info about the DRM encrypting a publication.
/// This object come back from the streamer, and can be filled by a DRM module,
/// then sent back to the streamer (with the decypher func filled) in order to
/// allow the fetcher to be able to decypher content later on.
public struct Drm {
    public let brand: Brand
    public let scheme: Scheme
    /// The below properties will be filled when passed back to the DRM module.
    public var profile: String?
    public var license: DrmLicense?

    public enum Brand: String {
        case lcp = "Lcp"
    }

    public enum Scheme: String {
        case lcp = "http://readium.org/2014/01/lcp"
    }

    public init(brand: Brand) {
        self.brand = brand
        switch brand {
        case .lcp:
            scheme = .lcp
        }
    }
}
