//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

open class DefaultLocatorService: LocatorService {
    
    let readingOrder: [Link]
    
    public init(readingOrder: [Link]) {
        self.readingOrder = readingOrder
    }
    
    open func locate(_ locator: Locator) -> Locator? {
        guard readingOrder.firstIndex(withHREF: locator.href) != nil else {
            return nil
        }
        
        return locator
    }
    
    open func locate(progression: Double) -> Locator? { nil }
    
}
