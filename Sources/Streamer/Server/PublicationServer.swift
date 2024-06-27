//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumGCDWebServer
import ReadiumShared
import UIKit

/// Errors thrown by the `PublicationServer`.
///
/// - parser: An error thrown by the Parser.
/// - fetcher: An error thrown by the Fetcher.
/// - nilBaseUrl: The base url is nil.
/// - usedEndpoint: This endpoint is already in use.
@available(*, unavailable, message: "See the 2.5.0 migration guide to migrate the HTTP server")
public enum PublicationServerError: Error {
    case parser(underlyingError: Error)
    case fetcher(underlyingError: Error)
    case nilBaseURL
    case usedEndpoint
}

/// The HTTP server for the publication's manifests and assets. Serves Epubs.
@available(*, unavailable, message: "See the 2.5.0 migration guide to migrate the HTTP server")
public class PublicationServer {}
