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

/// Shared DRM behavior for a particular license/publication.
/// DRMs can be very different beasts, so DRMLicense is not meant to be a generic interface for all DRM behaviors (eg. loan return). The goal of DRMLicense is to provide generic features that are used inside Readium's projects directly. For example, data decryption or copy of text selection in the navigator.
/// If there's a need for other generic DRM features, it can be implemented as a set of adapters in the client app, to cater to the interface's needs and capabilities.
public protocol DRMLicense {

    /// Encryption profile, if available.
    var encryptionProfile: String? { get }

    /// Depichers the given encrypted data to be displayed in the reader.
    func decipher(_ data: Data) throws -> Data?

    /// Returns whether the user can copy extracts from the publication.
    var canCopy: Bool { get }
    
    /// Processes the given text to be copied by the user.
    /// For example, you can save how much characters was copied to limit the overall quantity.
    /// - Parameter consumes: If true, then the user's copy right is consumed accordingly to the `text` input. Sets to false if you want to peek at the processed text without debiting the rights straight away.
    /// - Returns: The (potentially modified) text to put in the user clipboard, or nil if the user is not allowed to copy it.
    func copy(_ text: String, consumes: Bool) -> String?
    
}

public extension DRMLicense {
    
    var encryptionProfile: String? { return nil }

    var canCopy: Bool { return true }
    
    func copy(_ text: String, consumes: Bool) -> String? {
        return canCopy ? text : nil
    }
    
}
