//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Default implementation of ``FormatSniffer`` guessing as well as possible all
/// formats known by Readium.
public final class DefaultFormatSniffer: CompositeFormatSniffer {
    /// - Parameter additionalSniffers: Additional sniffers to be used to guess
    ///   content format.
    public init(additionalSniffers: [FormatSniffer] = []) {
        super.init(additionalSniffers + [
            HTMLFormatSniffer(),
        ])
    }
}
