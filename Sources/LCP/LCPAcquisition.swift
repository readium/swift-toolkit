//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Represents an on-going LCP acquisition task.
///
/// You can cancel the on-going download with `acquisition.cancel()`.
@available(*, deprecated)
public final class LCPAcquisition: Loggable {
    /// Informations about an acquired publication protected with LCP.
    @available(*, unavailable, renamed: "LCPAcquiredPublication")
    public struct Publication {
        /// Path to the downloaded publication.
        /// You must move this file to the user library's folder.
        public let localURL: FileURL

        /// Filename that should be used for the publication when importing it in the user library.
        public let suggestedFilename: String
    }

    @available(*, unavailable, renamed: "LCPProgress")
    /// Percent-based progress of the acquisition.
    public enum Progress {
        /// Undetermined progress, a spinner should be shown to the user.
        case indefinite
        /// A finite progress from 0.0 to 1.0, a progress bar should be shown to the user.
        case percent(Float)
    }

    /// Cancels the acquisition.
    @available(*, unavailable, message: "This is not needed with the new async variants")
    public func cancel() {}
}
