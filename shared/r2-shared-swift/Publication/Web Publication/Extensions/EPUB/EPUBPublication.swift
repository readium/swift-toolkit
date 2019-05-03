//
//  EPUBPublication.swift
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
public protocol EPUBPublication {
    
    /// Provides navigation to positions in the Publication content that correspond to the locations of page boundaries present in a print source being represented by this EPUB Publication.
    var pageList: [Link] { get set }
    
    /// Identifies fundamental structural components of the publication in order to enable Reading Systems to provide the User efficient access to them..
    var landmarks: [Link] { get set }
    
    var listOfAudioFiles: [Link] { get set }
    var listOfIllustrations: [Link] { get set }
    var listOfTables: [Link] { get set }
    var listOfVideos: [Link] { get set }

}


private let pageListKey = "page-list"
private let landmarksKey = "landmarks"
private let loaKey = "loa"
private let loiKey = "loi"
private let lotKey = "lot"
private let lovKey = "lov"

extension WebPublication: EPUBPublication {

    public var pageList: [Link] {
        get { return otherCollections.first(withRole: pageListKey)?.links ?? [] }
        set { setCollectionLinks(newValue, forRole: pageListKey) }
    }
    
    public var landmarks: [Link] {
        get { return otherCollections.first(withRole: landmarksKey)?.links ?? [] }
        set { setCollectionLinks(newValue, forRole: landmarksKey) }
    }
    
    public var listOfAudioFiles: [Link] {
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
    
    public var listOfVideos: [Link] {
        get { return otherCollections.first(withRole: lovKey)?.links ?? [] }
        set { setCollectionLinks(newValue, forRole: lovKey) }
    }

}
