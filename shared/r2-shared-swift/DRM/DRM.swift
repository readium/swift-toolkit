//
//  DRM.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 18.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// An object giving info about the DRM encrypting a publication.
/// This object come back from the streamer, and can be filled by a DRM module, then sent back to the streamer (with the decypher func filled) in order to allow the fetcher to be able to decypher content later on.
public struct DRM {
    public let brand: Brand
    public let scheme: Scheme
    
    /// The license will be filled when passed back to the DRM module.
    public var license: DRMLicense?

    public enum Brand: String {
        case lcp
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

public protocol DRMLicense {

    /// Encryption profile, if available.
    var encryptionProfile: String? { get }

    /// Depichers the given encrypted data to be displayed in the reader.
    func decipher(_ data: Data) throws -> Data?

    /// Interface to manage the user rights for this license.
    /// If nil, then every rights are allowed in the reader.
    var rights: DRMRights? { get }
    
    /// Interface to manage the loan, if this publication is borrowed.
    var loan: DRMLoan? { get }
    
}

public extension DRMLicense {
    
    public var encryptionProfile: String? {
        return nil
    }
    
    public var rights: DRMRights? {
        return nil
    }
    
    public var loan: DRMLoan? {
        return nil
    }
    
}
