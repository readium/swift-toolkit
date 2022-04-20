//
//  LCPError+wrap.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 14.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

extension LCPError {
    
    static func wrap(_ optionalError: Error?) -> LCPError {
        guard let error = optionalError else {
            return .unknown(nil)
        }
        
        if let error = error as? LCPError {
            return error
        } else if let error = error as? StatusError {
            return .licenseStatus(error)
        } else if let error = error as? RenewError {
            return .licenseRenew(error)
        } else if let error = error as? ReturnError {
            return .licenseReturn(error)
        } else if let error = error as? ParsingError {
            return .parsing(error)
        }
        
        if let error = error as? HTTPError {
            return .network(error)
        }
        
        let nsError = error as NSError
        switch nsError.domain {
        case "R2LCPClient.LCPClientError":
            return .licenseIntegrity(LCPClientError(rawValue: nsError.code) ?? .unknown)
        case NSURLErrorDomain:
            return .network(nsError)
        default:
            return .unknown(error)
        }
    }
    
    static func wrap<T>(_ completion: @escaping (Result<T, LCPError>) -> Void) -> (Result<T, Error>) -> Void {
        return { result in
            completion(result.mapError(LCPError.wrap))
        }
    }
    
    static func wrap(_ completion: @escaping (LCPError?) -> Void) -> (Error?) -> Void {
        return { error in
            if let error = error {
                completion(LCPError.wrap(error))
            } else {
                completion(nil)
            }
        }
    }
    
}
