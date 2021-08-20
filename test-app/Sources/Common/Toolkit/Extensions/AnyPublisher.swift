//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine

extension AnyPublisher {
    
    public static func just(_ value: Output) -> Self {
        Just(value)
            .setFailureType(to: Failure.self)
            .eraseToAnyPublisher()
    }
    
    public static func fail(_ error: Failure) -> Self {
        Fail(error: error).eraseToAnyPublisher()
    }
}
