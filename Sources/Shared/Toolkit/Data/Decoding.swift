//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Errors produced when trying to decode content.
public enum DecodeError: Error {
    /// Content could not be successfully decoded because it doesn't match what was expected.
    case Decoding(Error)
}
