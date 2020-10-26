//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// An object giving info about the DRM encrypting a publication.
/// This object come back from the streamer, and can be filled by a DRM module, then sent back to the streamer (with the decypher func filled) in order to allow the fetcher to be able to decypher content later on.
@available(*, unavailable, message: "The new `Streamer` is handling DRM through a `ContentProtectionService`")
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
@available(*, unavailable, message: "The new `Streamer` is handling DRM through a `ContentProtectionService`")
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

@available(*, unavailable)
public extension DRMLicense {
    
    var encryptionProfile: String? { return nil }

    var canCopy: Bool { return true }
    
    func copy(_ text: String, consumes: Bool) -> String? {
        return canCopy ? text : nil
    }
    
}

@available(*, unavailable, renamed: "DRM")
public typealias Drm = DRM

@available(*, unavailable, renamed: "DRMLicense")
public typealias DrmLicense = DRMLicense


@available(*, unavailable)
extension DRM {

    @available(*, deprecated, message: "Use `license?.encryptionProfile` instead")
    public var profile: String? {
        return license?.encryptionProfile
    }
    
}


@available(*, unavailable)
extension DRMLicense {
    
    @available(*, deprecated, message: "Use `LCPLicense.renewLoan` instead")
    public func renew(endDate: Date?, completion: @escaping (Error?) -> Void) {
        completion(nil)
    }

    @available(*, deprecated, message: "Use `LCPLicense.returnPublication` instead")
    public func `return`(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }
    
    @available(*, deprecated, message: "Checking for the rights is handled by r2-lcp-swift now")
    public func areRightsValid() throws {}
    
    @available(*, deprecated, message: "Registering the device is handled by r2-lcp-swift now")
    public func register() {}
    
    @available(*, deprecated, message: "Update DrmManagementTableViewController from r2-testapp-swift")
    public func currentStatus() -> String {
        return ""
    }
    
    @available(*, deprecated, message: "Update DrmManagementTableViewController from r2-testapp-swift")
    public func lastUpdate() -> Date {
        return Date()
    }
    
    @available(*, deprecated, message: "Update DrmManagementTableViewController from r2-testapp-swift")
    public func issued() -> Date {
        return Date()
    }
    
    @available(*, deprecated, message: "Update DrmManagementTableViewController from r2-testapp-swift")
    public func provider() -> URL {
        return URL(fileURLWithPath: "/")
    }
    
    @available(*, deprecated, message: "Update DrmManagementTableViewController from r2-testapp-swift")
    public func rightsEnd() -> Date? {
        return nil
    }
    
    @available(*, deprecated, message: "Update DrmManagementTableViewController from r2-testapp-swift")
    public func potentialRightsEnd() -> Date? {
        return nil
    }
    
    @available(*, deprecated, message: "Update DrmManagementTableViewController from r2-testapp-swift")
    public func rightsStart() -> Date? {
        return nil
    }
    
    @available(*, deprecated, message: "Update DrmManagementTableViewController from r2-testapp-swift")
    public func rightsPrints() -> Int? {
        return nil
    }
    
    @available(*, deprecated, message: "Update DrmManagementTableViewController from r2-testapp-swift")
    public func rightsCopies() -> Int? {
        return nil
    }
    
}
