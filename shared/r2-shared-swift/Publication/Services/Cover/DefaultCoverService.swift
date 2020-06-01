//
//  DefaultCoverService.swift
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

/// A `CoverService` which will look for a `Link` with `cover` relation in the `Publication`
/// resources, and fetch its content.
public final class DefaultCoverService: CoverService, Loggable {
    
    public typealias BitmapFactory = (Link, Data) -> UIImage?
    
    private let coverLinks: [Link]
    private let fetcher: Fetcher
    private let makeBitmap: BitmapFactory?
    
    public init(coverLinks: [Link], fetcher: Fetcher, makeBitmap: BitmapFactory?) {
        self.coverLinks = coverLinks
        self.fetcher = fetcher
        self.makeBitmap = makeBitmap
    }
    
    public var cover: UIImage? {
        for link in coverLinks {
            if let cover = cover(at: link) {
                return cover
            }
        }
        return nil
    }
    
    func cover(at link: Link) -> UIImage? {
        let result = fetcher.get(link)
            .read()
            .tryMap { data in
                makeBitmap?(link, data) ?? UIImage(data: data)
        }
        
        switch result {
        case .success(let cover):
            return cover
        case .failure(let error):
            log(.error, "Can't read cover at \(link.href): \(error)")
            return nil
        }
    }
    
    /// Creates the `DefaultCoverService` factory.
    ///
    /// By default, only bitmap files are supported by this service, but you can provide a
    /// `makeBitmap` factory to convert raw `Data` to a bitmap.
    public static func create(makeBitmap: BitmapFactory? = nil) -> (PublicationServiceContext) -> DefaultCoverService? {
        return { context in
            let coverLinks = (context.manifest.resources + context.manifest.readingOrder + context.manifest.links).filter(byRel: "cover")
            return DefaultCoverService(coverLinks: coverLinks, fetcher: context.fetcher, makeBitmap: makeBitmap)
        }
    }
    
}
