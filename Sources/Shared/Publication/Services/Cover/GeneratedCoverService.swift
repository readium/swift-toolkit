//
//  GeneratedCoverService.swift
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

/// A `CoverService` which holds a lazily generated cover bitmap in memory.
public final class GeneratedCoverService: CoverService {
    
    enum Error: Swift.Error {
        case generationFailed
    }
    
    private let makeCover: () throws -> UIImage
    private lazy var generatedCover = ResourceResult<UIImage> { try makeCover() }
    
    public init(makeCover: @escaping () throws -> UIImage) {
        self.makeCover = makeCover
    }
    
    public convenience init(cover: UIImage) {
        self.init(makeCover: { cover })
    }
    
    private let coverLink = Link(
        href: "/~readium/cover",
        type: "image/png",
        rel: .cover
    )
    
    public var cover: UIImage? { try? generatedCover.get() }
    
    public var links: [Link] { [coverLink] }

    public func get(link: Link) -> Resource? {
        guard link.href == coverLink.href else {
            return nil
        }
        
        return LazyResource {
            do {
                let cover = try self.generatedCover.get()
                return DataResource(
                    link: self.coverLink.copy(
                        height: Int(cover.size.height),
                        width: Int(cover.size.width)
                    ),
                    data: try cover.pngData().orThrow(Error.generationFailed)
                )
            } catch {
                return FailureResource(link: self.coverLink, error: .wrap(error))
            }
        }
    }
    
    public static func makeFactory(makeCover: @escaping () -> UIImage) -> (PublicationServiceContext) -> GeneratedCoverService? {
        return { _ in GeneratedCoverService(makeCover: makeCover) }
    }
    
    public static func makeFactory(cover: UIImage) -> (PublicationServiceContext) -> GeneratedCoverService? {
        return { _ in GeneratedCoverService(cover: cover) }
    }
    
}
