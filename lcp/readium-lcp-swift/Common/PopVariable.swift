//
//  Created by Mickaël Menu on 08.02.19.
//  Copyright © 2019 Readium. All rights reserved.
//

import Foundation

final class PopVariable<T> {
    
    private var value: T?
    
    init(_ value: T? = nil) {
        self.value = value
    }
    
    func set(_ value: T) {
        self.value = value
    }
    
    func pop() -> T? {
        let value = self.value
        self.value = nil
        return value
    }
    
}
