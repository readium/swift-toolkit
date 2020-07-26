//
//  Deferred.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 26/07/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

extension Deferred where Success == Void {
    
    /// Resolves a `Deferred` by returning an optional `Failure`, ignoring any success or cancelled
    /// result.
    public func resolveWithError(on queue: DispatchQueue = .main, _ completion: @escaping ((Failure?) -> Void)) {
        resolve(on: queue, { result in
            switch result {
            case .success, .cancelled:
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        })
    }
    
}
