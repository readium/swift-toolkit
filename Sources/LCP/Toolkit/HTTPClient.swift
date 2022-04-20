//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

extension HTTPClient {
    func fetch(_ url: HTTPRequestConvertible) -> Deferred<HTTPResponse, HTTPError> {
        deferred { completion in
            _ = fetch(url) { result in
                completion(CancellableResult(result))
            }
        }
    }
}
