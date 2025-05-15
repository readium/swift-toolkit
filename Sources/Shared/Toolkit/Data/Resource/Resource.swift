//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Acts as a proxy to an actual resource by handling read access.
public protocol Resource: Streamable {
    /// URL locating this resource, when available.
    ///
    /// This can be used to optimize access to a resource's content for the
    /// caller. For example if the resource is available on the local file
    /// system, a caller might prefer using a file handle instead of the
    /// ``Resource`` API.
    ///
    /// Note that this must represent the same content available in
    /// ``Resource``. If you transform the resources content on the fly (e.g.
    /// with ``TransformingResource``), then the `sourceURL` becomes nil.
    ///
    /// A ``Resource`` located in a ZIP archive will have a nil `sourceURL`, as
    /// there is no direct access to the ZIP entry using an absolute URL.
    var sourceURL: AbsoluteURL? { get }

    /// Properties associated to the resource.
    ///
    /// This is opened for extensions.
    func properties() async -> ReadResult<ResourceProperties>
}
