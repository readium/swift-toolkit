//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Opens a `Publication` from a `PublicationAsset`.
///
/// - Parameters:
///   - parser: Parses the content of a publication `PublicationAsset`.
///   - contentProtections: Opens DRM-protected publications.
///   - onCreatePublication: Called on every parsed `Publication.Builder`. It can be used to modify
///     the manifest, the root container or the list of service factories of a `Publication`.
public class PublicationOpener {
    public typealias OnCreatePublication = (inout Publication.Builder) async -> Void

    private let parser: PublicationParser
    private let contentProtections: [ContentProtection]
    private let onCreatePublication: OnCreatePublication

    public init(
        parser: PublicationParser,
        contentProtections: [ContentProtection] = [],
        onCreatePublication: @escaping OnCreatePublication = { _ in }
    ) {
        self.parser = parser
        self.contentProtections = contentProtections
        self.onCreatePublication = onCreatePublication
    }
}
