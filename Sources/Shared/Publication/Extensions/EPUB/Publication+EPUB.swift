//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// EPUB Web Publication Extension
/// https://readium.org/webpub-manifest/schema/extensions/epub/subcollections.schema.json
public extension Publication {
    /// Provides navigation to positions in the Publication content that correspond to the locations
    /// of page boundaries present in a print source being represented by this EPUB Publication.
    var pageList: [Link] {
        subcollections["pageList"]?.first?.links ?? []
    }

    /// Identifies fundamental structural components of the publication in order to enable Reading
    /// Systems to provide the User efficient access to them..
    var landmarks: [Link] {
        subcollections["landmarks"]?.first?.links ?? []
    }

    var listOfAudioClips: [Link] {
        subcollections["loa"]?.flatMap(\.links) ?? []
    }

    var listOfIllustrations: [Link] {
        subcollections["loi"]?.flatMap(\.links) ?? []
    }

    var listOfTables: [Link] {
        subcollections["lot"]?.flatMap(\.links) ?? []
    }

    var listOfVideoClips: [Link] {
        subcollections["lov"]?.flatMap(\.links) ?? []
    }
}
