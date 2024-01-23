//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

func R2NavigatorLocalizedString(_ key: String, _ values: CVarArg...) -> String {
    R2LocalizedString("R2Navigator.\(key)", in: Bundle.module, values)
}
