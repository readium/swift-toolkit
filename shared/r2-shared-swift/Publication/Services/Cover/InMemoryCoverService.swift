//
//  InMemoryCoverService.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 01/06/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit

/// A `CoverService` which uses a provided in-memory bitmap.
public final class InMemoryCoverService: CoverService {
    
    public let cover: UIImage?
    
    public init(cover: UIImage?) {
        self.cover = cover
    }
    
    private lazy var coverLink = Link(
        href: "/~readium/cover",
        type: "image/png",
        rel: "cover",
        height: (cover?.size.height).map { Int($0) },
        width: (cover?.size.width).map { Int($0) }
    )
    
    public var links: [Link] {
        (cover != nil) ? [coverLink] : []
    }
    
    public func get(link: Link) -> Resource? {
        guard link.href == coverLink.href, let data = cover?.pngData() else {
            return nil
        }
        return DataResource(link: coverLink, data: data)
    }
    
    public static func create(cover: UIImage?) -> (PublicationServiceContext) -> InMemoryCoverService? {
        return { _ in InMemoryCoverService(cover: cover) }
    }
    
}
