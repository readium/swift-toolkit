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

private let pageListKey = "pageList"
private let landmarksKey = "landmarks"
private let loaKey = "loa"
private let loiKey = "loi"
private let lotKey = "lot"
private let lovKey = "lov"

/// EPUB Web Publication Extension
/// https://readium.org/webpub-manifest/schema/extensions/epub/subcollections.schema.json
extension Publication {

    /// Provides navigation to positions in the Publication content that correspond to the locations
    /// of page boundaries present in a print source being represented by this EPUB Publication.
    public var pageList: [Link] {
        get { return otherCollections.first(withRole: pageListKey)?.links ?? [] }
        set { setCollectionLinks(newValue, forRole: pageListKey) }
    }
    
    /// Identifies fundamental structural components of the publication in order to enable Reading
    /// Systems to provide the User efficient access to them..
    public var landmarks: [Link] {
        get { return otherCollections.first(withRole: landmarksKey)?.links ?? [] }
        set { setCollectionLinks(newValue, forRole: landmarksKey) }
    }
    
    public var listOfAudioClips: [Link] {
        get { return otherCollections.first(withRole: loaKey)?.links ?? [] }
        set { setCollectionLinks(newValue, forRole: loaKey) }
    }
    
    public var listOfIllustrations: [Link] {
        get { return otherCollections.first(withRole: loiKey)?.links ?? [] }
        set { setCollectionLinks(newValue, forRole: loiKey) }
    }
    
    public var listOfTables: [Link] {
        get { return otherCollections.first(withRole: lotKey)?.links ?? [] }
        set { setCollectionLinks(newValue, forRole: lotKey) }
    }
    
    public var listOfVideoClips: [Link] {
        get { return otherCollections.first(withRole: lovKey)?.links ?? [] }
        set { setCollectionLinks(newValue, forRole: lovKey) }
    }

}
