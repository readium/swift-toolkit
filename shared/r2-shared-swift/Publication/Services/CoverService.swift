//
//  CoverService.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 31/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit

/// Provides an easy access to a bitmap version of the publication cover.
///
/// While at first glance, getting the cover could be seen as a helper, the implementation
/// actually depends on the publication format:
///
///  - Some might allow vector images or even HTML pages, in which case they need to be converted
///    to bitmaps.
///  - Others require to render the cover from a specific file format, e.g. PDF.
///
/// Furthermore, a reading app might want to use a custom strategy to choose the cover image, for
/// example by:
///
/// - iterating through the images collection for a publication parsed from an OPDS 2 feed
/// - generating a bitmap from scratch using the publication's title
/// - using a cover selected by the user
public protocol CoverService: PublicationService {
    
    /// Returns the publication cover as a bitmap at its maximum size.
    ///
    /// If the cover is not a bitmap format (e.g. SVG), it will be scaled down to fit the screen
    /// using `UIScreen.main.bounds.size`.
    var cover: UIImage? { get }

    /// Returns the publication cover as a bitmap, scaled down to fit the given `maxSize`.
    ///
    /// If the cover is not in a bitmap format (e.g. SVG), it is exported as a bitmap filling
    /// `maxSize`. The cover might be cached in memory for next calls.
    func coverFitting(maxSize: CGSize) -> UIImage?
    
}

public extension CoverService {
    
    func coverFitting(maxSize: CGSize) -> UIImage? {
        return cover?.scaleToFit(maxSize: maxSize)
    }

}


// MARK: Publication Helpers

public extension Publication {

    /// Returns the publication cover as a bitmap at its maximum size.
    var cover: UIImage? {
        warnIfMainThread()
        return findService(CoverService.self)?.cover
    }
    
    /// Returns the publication cover as a bitmap, scaled down to fit the given `maxSize`.
    func coverFitting(maxSize: CGSize) -> UIImage? {
        warnIfMainThread()
        return findService(CoverService.self)?.coverFitting(maxSize: maxSize)
    }
    
}


// MARK: PublicationServicesBuilder Helpers

public extension PublicationServicesBuilder {
    
    mutating func setCover(_ factory: ((PublicationServiceContext) -> CoverService?)?) {
        if let factory = factory {
            set(CoverService.self, factory)
        } else {
            remove(CoverService.self)
        }
    }
    
}

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
