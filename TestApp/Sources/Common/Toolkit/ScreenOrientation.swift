//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

enum ScreenOrientation: String {
    case landscape
    case portrait

    static var current: ScreenOrientation {
        let orientation = UIDevice.current.orientation
        return orientation.isLandscape ? .landscape : .portrait
    }
}
