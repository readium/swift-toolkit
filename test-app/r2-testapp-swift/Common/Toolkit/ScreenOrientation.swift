//
//  ScreenOrientation.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 16/04/2020.
//
//  Copyright 2020 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
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
