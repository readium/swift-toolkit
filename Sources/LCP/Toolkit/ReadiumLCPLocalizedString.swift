//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import SwiftUI

func ReadiumLCPLocalizedString(_ key: String, _ values: CVarArg...) -> String {
    ReadiumLCPLocalizedString(key, values)
}

func ReadiumLCPLocalizedString(_ key: String, _ values: [CVarArg]) -> String {
    ReadiumLocalizedString("ReadiumLCP.\(key)", in: Bundle.module, values)
}

func ReadiumLCPLocalizedStringKey(_ key: String, _ values: CVarArg...) -> LocalizedStringKey {
    LocalizedStringKey(ReadiumLCPLocalizedString(key, values))
}
