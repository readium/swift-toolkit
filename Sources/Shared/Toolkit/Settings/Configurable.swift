//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public protocol ConfigurableSettings {}

public protocol Configurable {
    associatedtype Settings: ConfigurableSettings

    var settings: Observable<Settings> { get }

    func submitPreferences(_ preferences: Preferences)
}