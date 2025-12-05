//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// List of OPDS versions compliant with the parser.
public enum Version {
    /// OPDS 1.x must be an XML ressource
    case OPDS1
    /// OPDS 2.x must be a JSON ressource
    case OPDS2
}

/// An intermediate structure return when the generic helper method public static
/// func parseURL(url: URL, completion: (ParseData?, Error?) -> Void) from OPDSParser class is called.
public struct ParseData {
    /// The ressource URL
    public var url: URL

    /// The URLResponse got after fetching the ressource
    public var response: URLResponse

    /// The OPDS version
    public var version: Version

    /// The feed
    public var feed: Feed? {
        didSet {
            // Publication is nil when feed is not
            if feed != nil { publication = nil }
        }
    }

    /// The publication
    public var publication: Publication? {
        didSet {
            // Feed is nil when publication is not
            if publication != nil { feed = nil }
        }
    }

    init(url: URL, response: URLResponse, version: Version) {
        self.url = url
        self.response = response
        self.version = version
    }
}
