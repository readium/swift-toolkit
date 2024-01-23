//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

extension Result {
    func getOrNil() -> Success? {
        try? get()
    }

    func get(or def: Success) -> Success {
        (try? get()) ?? def
    }

    func `catch`(_ recover: (Failure) -> Self) -> Self {
        if case let .failure(error) = self {
            return recover(error)
        }
        return self
    }

    func eraseToAnyError() -> Result<Success, Error> {
        mapError { $0 as Error }
    }
}

extension Result where Failure == Error {
    func tryMap<T>(_ transform: (Success) throws -> T) -> Result<T, Error> {
        flatMap {
            do {
                return try .success(transform($0))
            } catch {
                return .failure(error)
            }
        }
    }
}
