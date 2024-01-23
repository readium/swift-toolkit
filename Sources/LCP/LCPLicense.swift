//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// Opened license, used to decipher a protected publication and manage its license.
public protocol LCPLicense: UserRights {
    typealias URLPresenter = (URL, _ dismissed: @escaping () -> Void) -> Void

    var license: LicenseDocument { get }
    var status: StatusDocument? { get }

    /// Deciphers the given encrypted data to be displayed in the reader.
    func decipher(_ data: Data) throws -> Data?

    /// Number of remaining characters allowed to be copied by the user.
    /// If nil, there's no limit.
    var charactersToCopyLeft: Int? { get }

    /// Number of pages allowed to be printed by the user.
    /// If nil, there's no limit.
    var pagesToPrintLeft: Int? { get }

    /// Can the user renew the loaned publication?
    var canRenewLoan: Bool { get }

    /// The maximum potential date to renew to.
    /// If nil, then the renew date might not be customizable.
    var maxRenewDate: Date? { get }

    /// Renews the loan by starting a renew LSD interaction.
    ///
    /// - Parameter prefersWebPage: Indicates whether the loan should be renewed through a web page if available,
    ///   instead of programmatically.
    func renewLoan(with delegate: LCPRenewDelegate, prefersWebPage: Bool, completion: @escaping (CancellableResult<Void, LCPError>) -> Void)

    /// Can the user return the loaned publication?
    var canReturnPublication: Bool { get }

    /// Returns the publication to its provider.
    func returnPublication(completion: @escaping (LCPError?) -> Void)
}

public extension LCPLicense {
    func renewLoan(with delegate: LCPRenewDelegate, completion: @escaping (CancellableResult<Void, LCPError>) -> Void) {
        renewLoan(with: delegate, prefersWebPage: false, completion: completion)
    }
}
