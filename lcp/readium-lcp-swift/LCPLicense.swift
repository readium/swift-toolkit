//
//  Copyright 2020 Readium Foundation. All rights reserved.
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
    
    /// Depichers the given encrypted data to be displayed in the reader.
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
    
    /// Renews the loan up to a certain date (if possible).
    ///
    /// - Parameter presenting: Used when the renew requires to present an HTML page to the user. The caller is responsible for presenting the URL (for example with SFSafariViewController) and then calling the `dismissed` callback once the website is closed by the user.
    func renewLoan(to end: Date?, present: @escaping URLPresenter, completion: @escaping (LCPError?) -> Void)

    /// Can the user return the loaned publication?
    var canReturnPublication: Bool { get }
    
    /// Returns the publication to its provider.
    func returnPublication(completion: @escaping (LCPError?) -> Void)
    
}
