//
//  ContentProtectionService+WS.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 09/08/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

public extension ContentProtectionService {

    var links: [Link] {
        handlers.map { $0.routeLink }
    }
    
    func get(link: Link) -> Resource? {
        guard let handler = handlers.first(where: { $0.accepts(link: link) }) else {
            return nil
        }
        let link = handler.routeLink.copy(href: link.href)
        
        let response: ResourceResult<String> = handler.handle(link: link, for: self)
            .flatMap {
                guard let jsonResponse = serializeJSONString($0) else {
                    return .failure(.other(JSONError.serializing(ContentProtectionService.self)))
                }
                return .success(jsonResponse)
            }
        
        switch response {
        case .success(let body):
            return DataResource(link: link, string: body)
        case .failure(let error):
            return FailureResource(link: link, error: error)
        }
    }

}

public enum ContentProtectionServiceError: LocalizedError {
    case missingParameter(name: String)
    
    public var errorDescription: String? {
        switch self {
        case .missingParameter(let name):
            return "The `\(name)` parameter is required"
        }
    }
}

/// Content Protection's web service route handlers.
private let handlers: [RouteHandler] = [
    ContentProtectionRouteHandler(),
    CopyRightsRouteHandler(),
    PrintRightsRouteHandler()
]

private protocol RouteHandler {
    
    var routeLink: Link { get }
    
    func accepts(link: Link) -> Bool
    
    func handle(link: Link, for service: ContentProtectionService) -> ResourceResult<Any>
    
}

private final class ContentProtectionRouteHandler: RouteHandler {
    
    let routeLink = Link(
        href: "/~readium/content-protection",
        type: MediaType.readiumContentProtection.string
    )
    
    func accepts(link: Link) -> Bool {
        return link.href == routeLink.href
    }

    func handle(link: Link, for service: ContentProtectionService) -> ResourceResult<Any> {
        return .success([
            "isRestricted": service.isRestricted,
            "error": service.error?.localizedDescription as Any,
            "name": service.name?.json as Any,
            "rights": [
                "canCopy": service.rights.canCopy,
                "canPrint": service.rights.canPrint
            ]
        ].compactMapValues { $0 })
    }

}

private final class CopyRightsRouteHandler: RouteHandler {
    
    /// `text` is the percent-encoded string to copy.
    /// `peek` is true or false. When missing, it defaults to false.
    let routeLink = Link(
        href: "/~readium/rights/copy{?text,peek}",
        type: MediaType.readiumRightsCopy.string,
        templated: true
    )
    
    func accepts(link: Link) -> Bool {
        return link.href.hasPrefix("/~readium/rights/copy")
    }
    
    func handle(link: Link, for service: ContentProtectionService) -> ResourceResult<Any> {
        let params = HREF(link.href).queryParameters
        let peek = params.first(named: "peek").flatMap(Bool.init) ?? false
        guard let text = params.first(named: "text") else {
            return .failure(.badRequest(ContentProtectionServiceError.missingParameter(name: "text")))
        }
        
        let allowed = peek
            ? service.rights.canCopy(text: text)
            : service.rights.copy(text: text)
        
        return allowed
            ? .success([:])
            : .failure(.forbidden)
    }
    
}

private final class PrintRightsRouteHandler: RouteHandler {
    
    /// `pageCount` is the number of pages to print, as a positive integer.
    /// `peek` is true or false. When missing, it defaults to false.
    let routeLink = Link(
        href: "/~readium/rights/print{?pageCount,peek}",
        type: MediaType.readiumRightsPrint.string,
        templated: true
    )
    
    func accepts(link: Link) -> Bool {
        return link.href.hasPrefix("/~readium/rights/print")
    }
    
    func handle(link: Link, for service: ContentProtectionService) -> ResourceResult<Any> {
        let params = HREF(link.href).queryParameters
        let peek = params.first(named: "peek").flatMap(Bool.init) ?? false
        guard let pageCount = params.first(named: "pageCount").flatMap(Int.init) else {
            return .failure(.badRequest(ContentProtectionServiceError.missingParameter(name: "pageCount")))
        }
       
        let allowed = peek
            ? service.rights.canPrint(pageCount: pageCount)
            : service.rights.print(pageCount: pageCount)
        
        return allowed
            ? .success([:])
            : .failure(.forbidden)
    }
    
}
