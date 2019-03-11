//
//  WPPublication.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 11.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// Readium Web Publication Manifest
/// https://readium.org/webpub-manifest/schema/publication.schema.json
public struct WPPublication: Equatable {
    
    public var context: [String]  // @context
    public var metadata: WPMetadata
    public var links: [WPLink]
    public var readingOrder: [WPLink]
    public var resources: [WPLink]
    public var toc: [WPLink]

    
    // MARK: - EPUB Extension
    
    /// Provides navigation to positions in the Publication content that correspond to the locations of page boundaries present in a print source being represented by this EPUB Publication.
    public var pageList: [WPLink]
    /// Identifies fundamental structural components of the publication in order to enable Reading Systems to provide the User efficient access to them..
    public var landmarks: [WPLink]
    /// List of audio files.
    public var loa: [WPLink]
    /// List of illustrations.
    public var loi: [WPLink]
    /// List of tables.
    public var lot: [WPLink]
    /// List of videos.
    public var lov: [WPLink]
    
    
    // Sub-collections Extension
    public var subcollections: [WPSubcollection]
    
    
    public init(context: [String] = [], metadata: WPMetadata, links: [WPLink], readingOrder: [WPLink], resources: [WPLink] = [], toc: [WPLink] = [], pageList: [WPLink] = [], landmarks: [WPLink] = [], loa: [WPLink] = [], loi: [WPLink] = [], lot: [WPLink] = [], lov: [WPLink] = [], subcollections: [WPSubcollection] = []) {
        self.context = context
        self.metadata = metadata
        self.links = links
        self.readingOrder = readingOrder
        self.resources = resources
        self.toc = toc
        self.pageList = pageList
        self.landmarks = landmarks
        self.loa = loa
        self.loi = loi
        self.lot = lot
        self.lov = lov
        self.subcollections = subcollections
    }
    
    public init(json: Any) throws {
        guard var json = JSONDictionary(json) else {
            throw WPParsingError.publication
        }
        
        self.context = parseArray(json.pop("@context"), allowingSingle: true)
        self.metadata = try WPMetadata(json: json.pop("metadata"))
        self.subcollections = []
        self.links = [WPLink](json: json.pop("links"))
            .filter { !$0.rels.isEmpty }
        // `readerOrder` used to be `spine`, so we parse `spine` as a fallback.
        self.readingOrder = [WPLink](json: json.pop("readingOrder") ?? json.pop("spine"))
            .filter { $0.type != nil }
        self.resources = [WPLink](json: json.pop("resources"))
            .filter { $0.type != nil }
        self.toc = [WPLink](json: json.pop("toc"))
        self.pageList = [WPLink](json: json.pop("page-list"))
        self.landmarks = [WPLink](json: json.pop("landmarks"))
        self.loa = [WPLink](json: json.pop("loa"))
        self.loi = [WPLink](json: json.pop("loi"))
        self.lot = [WPLink](json: json.pop("lot"))
        self.lov = [WPLink](json: json.pop("lov"))
        
        // Parses sub-collections from remaining JSON properties.
        self.subcollections = [WPSubcollection](json: json.json)
        
        guard !links.isEmpty, !readingOrder.isEmpty else {
            throw WPParsingError.publication
        }
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "@context": encodeIfNotEmpty(context),
            "metadata": metadata.json,
            "links": links.json,
            "readingOrder": readingOrder.json,
            "resources": encodeIfNotEmpty(resources.json),
            "toc": encodeIfNotEmpty(toc.json),
            "page-list": encodeIfNotEmpty(pageList.json),
            "landmarks": encodeIfNotEmpty(landmarks.json),
            "loa": encodeIfNotEmpty(loa.json),
            "loi": encodeIfNotEmpty(loi.json),
            "lot": encodeIfNotEmpty(lot.json),
            "lov": encodeIfNotEmpty(lov.json)
        ]).merging(subcollections.json, uniquingKeysWith: { current, _ in current })
    }
    
    public var jsonString: String? {
        var options: JSONSerialization.WritingOptions = []
        if #available(iOS 11.0, *) {
            options.insert(.sortedKeys)
        }
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: options),
            let string = String(data: data, encoding: .utf8) else
        {
            return nil
        }
        
        // Unescapes slashes
        return string.replacingOccurrences(of: "\\/", with: "/")
    }

}
