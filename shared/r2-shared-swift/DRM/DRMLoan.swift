//
//  DRMLoan.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 18.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// Interface to manage a loaned publication.
public protocol DRMLoan {

    /// The maximum potential date to renew to.
    /// If nil, then the renew date might not be customizable.
    var maxRenewDate: Date? { get }
    
    /// Renews the loan up to a certain date (if possible).
    var canRenewLicense: Bool { get }
    func renewLicense(to end: Date?, completion: @escaping (Error?) -> Void)

    /// Returns the loan to its provider.
    var canReturnLicense: Bool { get }
    func returnLicense(completion: @escaping (Error?) -> Void)
    
}


/// Errors occurring while renewing a loan.
public enum DRMRenewError: LocalizedError {
    // Your publication could not be renewed properly.
    case renewFailed(message: String?)
    // Incorrect renewal period, your publication could not be renewed.
    case invalidRenewalPeriod(maxRenewDate: Date?)
    // An unexpected error has occurred on the licensing server.
    case unexpectedServerError(Error?)
    
    public var errorDescription: String? {
        switch self {
        case .renewFailed(message: let message):
            return message ?? "Your publication could not be renewed properly."
        case .invalidRenewalPeriod(maxRenewDate: _):
            return "Incorrect renewal period, your publication could not be renewed."
        case .unexpectedServerError:
            return "An unexpected error has occurred on the server."
        }
    }
    
}


/// Errors occurring while returning a loan.
public enum DRMReturnError: LocalizedError {
    // Your publication could not be returned properly.
    case returnFailed(message: String?)
    // Your publication has already been returned before or is expired.
    case alreadyReturnedOrExpired
    // An unexpected error has occurred on the licensing server.
    case unexpectedServerError(Error?)
    
    public var errorDescription: String? {
        switch self {
        case .returnFailed(message: let message):
            return message ?? "Your publication could not be returned properly."
        case .alreadyReturnedOrExpired:
            return "Your publication has already been returned before or is expired."
        case .unexpectedServerError:
            return "An unexpected error has occurred on the server."
        }
    }
    
}
