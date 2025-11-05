//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Hint about the nature of the layout for the publication.
///
/// https://readium.org/webpub-manifest/contexts/default/#layout-and-reading-progression
public enum Layout: String, Sendable {
    /// Reading systems are free to adapt text and layout entirely based on user
    /// preferences.
    ///
    /// Formats: Reflowable EPUB
    case reflowable

    /// Each resource is a “page” where both dimensions are usually contained in
    /// the device’s viewport. Based on user preferences, the reading system may
    /// also display two resources side by side in a spread.
    ///
    /// Formats: Divina, FXL EPUB or PDF
    case fixed

    /// Resources are displayed in a continuous scroll, usually by filling the
    /// width of the viewport, without any visible gap between between spine items.
    ///
    /// Formats: Scrolled Divina
    case scrolled
}
