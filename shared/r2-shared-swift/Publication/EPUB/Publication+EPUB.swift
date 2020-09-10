//
//  Publication+EPUB.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 14.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// EPUB Web Publication Extension
/// https://readium.org/webpub-manifest/schema/extensions/epub/subcollections.schema.json
extension Publication {

    /// Provides navigation to positions in the Publication content that correspond to the locations
    /// of page boundaries present in a print source being represented by this EPUB Publication.
    public var pageList: [Link] {
        otherCollections.first(withRole: "pageList")?.links ?? []
    }
    
    /// Identifies fundamental structural components of the publication in order to enable Reading
    /// Systems to provide the User efficient access to them..
    public var landmarks: [Link] {
        otherCollections.first(withRole: "landmarks")?.links ?? []
    }
    
    public var listOfAudioClips: [Link] {
        otherCollections.first(withRole: "loa")?.links ?? []
    }
    
    public var listOfIllustrations: [Link] {
        otherCollections.first(withRole: "loi")?.links ?? []
    }
    
    public var listOfTables: [Link] {
        otherCollections.first(withRole: "lot")?.links ?? []
    }
    
    public var listOfVideoClips: [Link] {
        otherCollections.first(withRole: "lov")?.links ?? []
    }

}
