//
//  Result.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 04.02.19.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import PromiseKit

enum Result<T> {
    case success(T)
    case failure(LcpError)
}

/// Wraps a result-based completion block with PromisesKit
func wrap<T>(_ body: (@escaping (Result<T>) -> Void) throws -> Void) -> Promise<T> {
    return Promise { fulfill, reject in
        try body { result in
            switch result {
            case .success(let obj):
                fulfill(obj)
            case .failure(let error):
                reject(error)
            }
        }
    }
}
