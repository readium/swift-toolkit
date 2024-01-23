//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Routes requests to child fetchers, depending on a provided predicate.
///
/// This can be used for example to serve a publication containing both local and remote resources,
/// and more generally to concatenate different content sources.
///
/// The `routes` will be tested in the given order.
final class RoutingFetcher: Fetcher {
    /// Holds a child fetcher and the predicate used to determine if it can answer a request.
    ///
    /// The default value for `accepts` means that the fetcher will accept any link.
    struct Route {
        let fetcher: Fetcher
        let accepts: (Link) -> Bool

        init(fetcher: Fetcher, accepts: @escaping (Link) -> Bool = { _ in true }) {
            self.fetcher = fetcher
            self.accepts = accepts
        }
    }

    private let routes: [Route]

    /// Creates a `RoutingFetcher` from a list of routes, which will be tested in the given order.
    init(routes: [Route]) {
        self.routes = routes
    }

    /// Will route requests to `local` if the `Link::href` starts with `/`, otherwise to `remote`.
    convenience init(local: Fetcher, remote: Fetcher) {
        self.init(routes: [
            Route(fetcher: local, accepts: { $0.href.hasPrefix("/") }),
            Route(fetcher: remote),
        ])
    }

    var links: [Link] { routes.flatMap(\.fetcher.links) }

    func get(_ link: Link) -> Resource {
        guard let route = routes.first(where: { $0.accepts(link) }) else {
            return FailureResource(link: link, error: .notFound(nil))
        }
        return route.fetcher.get(link)
    }

    func close() {
        for route in routes {
            route.fetcher.close()
        }
    }
}
