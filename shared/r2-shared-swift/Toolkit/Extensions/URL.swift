//
//  Created by Mickaël Menu on 12/07/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

extension URL {
    
    /// Returns whether the given `url` is `self` or one of its descendants.
    func isParentOf(_ url: URL) -> Bool {
        let standardizedSelf = standardizedFileURL.path
        let other = url.standardizedFileURL.path
        return standardizedSelf == other || other.hasPrefix(standardizedSelf + "/")
    }
    
}
