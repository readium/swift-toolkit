//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public protocol LCPAuthenticating {
    /// Retrieves the passphrase to decrypt the given license.
    ///
    /// If `allowUserInteraction` is true, the reading app can prompt the user to enter the
    /// passphrase. Otherwise, use a background retrieval method (e.g. web service) or return null.
    ///
    /// The returned passphrase can be clear or already hashed.
    ///
    /// - Parameters:
    ///   - license: Information to show to the user about the license being opened.
    ///   - reason: Reason why the passphrase is requested. It should be used to prompt the user.
    ///   - allowUserInteraction: Indicates whether the user can be prompted for their passphrase.
    ///     If your implementation requires it and `allowUserInteraction` is false, terminate
    ///     quickly by sending `nil` to the completion block.
    ///   - sender: Free object that can be used by reading apps to give some UX context when
    ///     presenting dialogs. For example, the host `UIViewController`.
    ///   - completion: Used to return the retrieved passphrase. If the user cancelled, send nil.
    ///     The passphrase may be already hashed.
    @MainActor
    func retrievePassphrase(
        for license: LCPAuthenticatedLicense,
        reason: LCPAuthenticationReason,
        allowUserInteraction: Bool,
        sender: Any?
    ) async -> String?
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
        document.encryption.userKey.textHint
    }

    /// Location where a Reading System can redirect a User looking for additional information about the User Passphrase.
    public var hintLink: Link? {
        document.link(for: .hint)
    }

    /// Support resources for the user (either a website, an email or a telephone number).
    public var supportLinks: [Link] {
        document.links(for: .support)
    }

    /// URI of the license provider.
    public var provider: String {
        document.provider
    }

    /// Informations about the user owning the license.
    public var user: User? {
        document.user
    }

    /// License Document being opened.
    public let document: LicenseDocument

    init(document: LicenseDocument) {
        self.document = document
    }
}
