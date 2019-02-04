//
//  Created by Mickaël Menu on 04.02.19.
//  Copyright © 2019 Readium. All rights reserved.
//

import Foundation
import PromiseKit

enum Result<T> {
    case success(T)
    case failure(Error)
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
