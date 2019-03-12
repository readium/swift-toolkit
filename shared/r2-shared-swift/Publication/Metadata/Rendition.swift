//
//  Rendition.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu, Alexandre Camilleri on 09.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// Suggested orientation for the device when displaying the linked resource.
public enum RenditionOrientation: String {
    // Specifies that the Reading System can determine the orientation to rendered the spine item in.
    case auto
    // Specifies that the given spine item is to be rendered in landscape orientation.
    case landscape
    // Specifies that the given spine item is to be rendered in portrait orientation.
    case portrait
}

/// Indicates how the linked resource should be displayed in a reading environment that displays synthetic spreads.
public enum RenditionPage: String {
    case left
    case right
    case center
}
