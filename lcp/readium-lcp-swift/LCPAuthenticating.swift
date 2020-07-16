//
//  LCPAuthenticating.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 08.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

public protocol LCPAuthenticating {
    
    /// Indicates whether the user might be prompted to ask their credentials, when calling
    /// `requestPassphrase()`.
    var requiresUserInteraction: Bool { get }
    
    /// Requests a passphrase to decrypt the given license.
    ///
    /// The reading app can prompt the user to enter the passphrase, or retrieve it by any other
    /// means (eg. web service).
    ///
    /// - Parameters:
    ///   - license: Information to show to the user about the license being opened.
    ///   - reason: Reason why the passphrase is requested. It should be used to prompt the user.
    ///   - sender: Free object that can be used by reading apps to give some UX context when
    ///     presenting dialogs. For example, the host `UIViewController`.
    ///   - completion: Used to return the retrieved passphrase. If the user cancelled, send nil.
    ///     The passphrase may be already hashed.
    func requestPassphrase(for license: LCPAuthenticatedLicense, reason: LCPAuthenticationReason, sender: Any?, completion: @escaping (String?) -> Void)
    
}

public enum LCPAuthenticationReason {
    /// No matching passphrase was found.
    case passphraseNotFound
    /// The provided passphrase was invalid.
    case invalidPassphrase
}

public struct LCPAuthenticatedLicense {

    /// A hint to be displayed to the User to help them remember the User Passphrase.
    public var hint: String {
        return document.encryption.userKey.textHint
    }
    
    /// Location where a Reading System can redirect a User looking for additional information about the User Passphrase.
    public var hintLink: Link? {
        return document.link(for: .hint)
    }
    
    /// Support resources for the user (either a website, an email or a telephone number).
    public var supportLinks: [Link] {
        return document.links(for: .support)
    }
    
    /// URI of the license provider.
    public var provider: String {
        return document.provider
    }
    
    /// Informations about the user owning the license.
    public var user: User? {
        return document.user
    }

    /// License Document being opened.
    public let document: LicenseDocument

    init(document: LicenseDocument) {
        self.document = document
    }

}
