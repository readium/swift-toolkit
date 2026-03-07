//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Resolves and fetches ``GuidedNavigationDocument`` objects.
public protocol GuidedNavigationDocumentProvider {
    /// Returns the HREF of the ``GuidedNavigationDocument`` associated with
    /// the given reading order resource, or `nil` if none exists.
    func guidedNavigationDocumentHREF(for readingOrderHREF: any URLConvertible) -> AnyURL?

    /// Returns the ``GuidedNavigationDocument`` at the given `href`, or `nil`
    /// if none is found.
    func guidedNavigationDocument(at href: any URLConvertible) async throws(ReadError) -> GuidedNavigationDocument?
}
