//
//  Result.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 13/07/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

extension Result {
    
    func getOrNil() -> Success? {
        return try? get()
    }

    func get(or def: Success) -> Success {
        (try? get()) ?? def
    }

    func `catch`(_ recover: (Failure) -> Self) -> Self {
        if case .failure(let error) = self {
            return recover(error)
        }
        return self
    }

    func eraseToAnyError() -> Result<Success, Error> {
        mapError { $0 as Error }
    }
}

extension Result where Failure == Error {
    func tryMap<T>(_ transform:(Success) throws -> T)  -> Result<T, Error> {
        flatMap {
            do {
                return .success(try transform($0))
            } catch {
                return .failure(error)
            }
        }
    }
}
