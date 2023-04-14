//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

public extension Deferred where Success == Void {
    /// Resolves a `Deferred` by returning an optional `Failure`, ignoring any success or cancelled
    /// result.
    func resolveWithError(on queue: DispatchQueue = .main, _ completion: @escaping ((Failure?) -> Void)) {
        resolve(on: queue) { result in
            switch result {
            case .success, .cancelled:
                completion(nil)
            case let .failure(error):
                completion(error)
            }
        }
    }
}
