//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension ContentProtectionService {
    var links: [Link] {
        handlers.map(\.routeLink)
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
        case let .success(body):
            return DataResource(link: link, string: body)
        case let .failure(error):
            return FailureResource(link: link, error: error)
        }
    }
}

public enum ContentProtectionServiceError: LocalizedError {
    case missingParameter(name: String)

    public var errorDescription: String? {
        switch self {
        case let .missingParameter(name):
            return "The `\(name)` parameter is required"
        }
    }
}

/// Content Protection's web service route handlers.
private let handlers: [RouteHandler] = [
    ContentProtectionRouteHandler(),
    CopyRightsRouteHandler(),
    PrintRightsRouteHandler(),
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
        link.href == routeLink.href
    }

    func handle(link: Link, for service: ContentProtectionService) -> ResourceResult<Any> {
        .success([
            "isRestricted": service.isRestricted,
            "error": service.error?.localizedDescription as Any,
            "name": service.name?.json as Any,
            "rights": [
                "canCopy": service.rights.canCopy,
                "canPrint": service.rights.canPrint,
            ],
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
        link.href.hasPrefix("/~readium/rights/copy")
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
            ? .success([:] as [String: Any])
            : .failure(.forbidden(nil))
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
        link.href.hasPrefix("/~readium/rights/print")
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
            ? .success([:] as [String: Any])
            : .failure(.forbidden(nil))
    }
}
