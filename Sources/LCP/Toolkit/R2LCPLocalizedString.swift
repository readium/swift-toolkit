//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

func R2LCPLocalizedString(_ key: String, _ values: CVarArg...) -> String {
    R2LocalizedString("ReadiumLCP.\(key)", in: Bundle.module, values)
}
