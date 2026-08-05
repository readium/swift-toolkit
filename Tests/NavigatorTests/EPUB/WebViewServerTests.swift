//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import WebKit
import XCTest

/// A `WKURLSchemeTask` standing in for WebKit's, recording what the server
/// responded and letting the test await completion.
private final class URLSchemeTaskSpy: NSObject, WKURLSchemeTask, @unchecked Sendable {
    let request: URLRequest

    private(set) var receivedData = Data()
    private(set) var response: URLResponse?
    private(set) var error: Error?
    private(set) var isFinished = false

    private var continuation: CheckedContinuation<Void, Never>?

    init(url: String) {
        request = URLRequest(url: URL(string: url)!)
        super.init()
    }

    /// The body the server sent, decoded as UTF-8.
    var receivedString: String? {
        String(data: receivedData, encoding: .utf8)
    }

    var statusCode: Int? {
        (response as? HTTPURLResponse)?.statusCode
    }

    func header(_ name: String) -> String? {
        (response as? HTTPURLResponse)?.value(forHTTPHeaderField: name)
    }

    /// Waits until the server either finished or failed the task.
    func complete() async {
        guard !isFinished, error == nil else {
            return
        }

        await withCheckedContinuation { continuation = $0 }
    }

    func didReceive(_ response: URLResponse) {
        self.response = response
    }

    func didReceive(_ data: Data) {
        receivedData.append(data)
    }

    func didFinish() {
        isFinished = true
        resume()
    }

    func didFailWithError(_ error: any Error) {
        self.error = error
        resume()
    }

    private func resume() {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume()
    }
}

@MainActor
final class WebViewServerTests: XCTestCase {
    private let scheme = "readium"

    // MARK: - Resource caching

    /// Two publications are served under different routes but use the same
    /// internal file names. Caching on the publication-relative path alone
    /// would serve one book's bytes for the other.
    func testResourcesWithTheSameRelativePathAreNotSharedAcrossRoutes() async {
        let sut = makeSUT()
        sut.serve(at: "book-a", handler: resources(["chapter1.xhtml": "A"]))
        sut.serve(at: "book-b", handler: resources(["chapter1.xhtml": "B"]))

        let a = await sut.get("\(scheme)://book-a/chapter1.xhtml")
        let b = await sut.get("\(scheme)://book-b/chapter1.xhtml")

        XCTAssertEqual(a.receivedString, "A")
        XCTAssertEqual(b.receivedString, "B", "Book B was served book A's cached resource")
    }

    /// The cache still has to do its job within a single route: the same
    /// resource instance is reused so buffered reads keep their benefit.
    func testResourcesAreCachedWithinARoute() async {
        let sut = makeSUT()
        var handlerCallCount = 0
        sut.serve(at: "book-a", handler: resources(["chapter1.xhtml": "A"]) { handlerCallCount += 1 })

        _ = await sut.get("\(scheme)://book-a/chapter1.xhtml")
        _ = await sut.get("\(scheme)://book-a/chapter1.xhtml")

        XCTAssertEqual(handlerCallCount, 1, "The resource should have been served from the cache the second time")
    }

    /// Evicting HTML because one publication's settings changed must not
    /// throw away every other publication's resources.
    func testClearingTheCacheOfOneRouteLeavesTheOthersAlone() async {
        let sut = makeSUT()
        var callsA = 0
        var callsB = 0
        sut.serve(at: "book-a", handler: resources(["chapter1.xhtml": "A"]) { callsA += 1 })
        sut.serve(at: "book-b", handler: resources(["chapter1.xhtml": "B"]) { callsB += 1 })

        _ = await sut.get("\(scheme)://book-a/chapter1.xhtml")
        _ = await sut.get("\(scheme)://book-b/chapter1.xhtml")
        XCTAssertEqual(callsA, 1)
        XCTAssertEqual(callsB, 1)

        sut.clearResourceCache(atRoute: "book-a") { _, mediaType in mediaType.isHTML }

        _ = await sut.get("\(scheme)://book-a/chapter1.xhtml")
        _ = await sut.get("\(scheme)://book-b/chapter1.xhtml")

        XCTAssertEqual(callsA, 2, "Book A's resource should have been evicted and re-served")
        XCTAssertEqual(callsB, 1, "Book B's resource was evicted by a change to book A")
    }

    func testClearingTheCacheHonoursThePredicate() async {
        let sut = makeSUT()
        var htmlCalls = 0
        var imageCalls = 0
        sut.serve(at: "book-a", handler: { relativeURL in
            switch relativeURL.string {
            case "chapter1.xhtml":
                htmlCalls += 1
                return (DataResource(string: "html"), .xhtml)
            case "cover.jpg":
                imageCalls += 1
                return (DataResource(string: "image"), .jpeg)
            default:
                return nil
            }
        })

        _ = await sut.get("\(scheme)://book-a/chapter1.xhtml")
        _ = await sut.get("\(scheme)://book-a/cover.jpg")

        sut.clearResourceCache(atRoute: "book-a") { _, mediaType in mediaType.isHTML }

        _ = await sut.get("\(scheme)://book-a/chapter1.xhtml")
        _ = await sut.get("\(scheme)://book-a/cover.jpg")

        XCTAssertEqual(htmlCalls, 2, "The HTML resource should have been evicted")
        XCTAssertEqual(imageCalls, 1, "The image does not match the predicate and should have stayed cached")
    }

    // MARK: - Embedding

    /// A publication's documents must not be embeddable by a document of
    /// another origin, which on a shared server means another publication.
    func testPublicationResourcesRestrictEmbedding() async {
        let sut = makeSUT()
        sut.serve(at: "book-a", handler: resources(["chapter1.xhtml": "A"]))

        let response = await sut.get("\(scheme)://book-a/chapter1.xhtml")

        XCTAssertEqual(response.header("Content-Security-Policy"), "frame-ancestors 'self'")
    }

    /// Fixed-layout publications load their spine resources into iframes of a
    /// wrapper page served from the same origin, so same-origin framing has to
    /// stay allowed.
    func testEmbeddingPolicyAllowsSameOriginFraming() {
        XCTAssertTrue(
            WebViewServer.publicationContentSecurityPolicy.contains("'self'"),
            "Fixed-layout publications frame their own resources"
        )
        XCTAssertFalse(WebViewServer.publicationContentSecurityPolicy.contains("'none'"))
    }

    // MARK: - Route lifetime

    func testRemovedRouteStopsBeingServed() async {
        let sut = makeSUT()
        sut.serve(at: "book-a", handler: resources(["chapter1.xhtml": "A"]))
        sut.serve(at: "book-b", handler: resources(["chapter1.xhtml": "B"]))

        sut.remove(at: "book-a")

        let a = await sut.get("\(scheme)://book-a/chapter1.xhtml")
        XCTAssertNotNil(a.error, "The removed route is still being served")

        let b = await sut.get("\(scheme)://book-b/chapter1.xhtml")
        XCTAssertEqual(b.receivedString, "B", "Removing one route took another one down with it")
    }

    /// Closing a publication has to release the resources it had cached,
    /// otherwise a shared server would hold on to them for the lifetime of the
    /// app.
    func testRemovingARouteDropsItsCachedResources() async {
        let sut = makeSUT()
        var callsA = 0
        var callsB = 0
        sut.serve(at: "book-a", handler: resources(["chapter1.xhtml": "A"]) { callsA += 1 })
        sut.serve(at: "book-b", handler: resources(["chapter1.xhtml": "B"]) { callsB += 1 })

        _ = await sut.get("\(scheme)://book-a/chapter1.xhtml")
        _ = await sut.get("\(scheme)://book-b/chapter1.xhtml")

        sut.remove(at: "book-a")
        // Serving the route again stands in for reopening the publication.
        sut.serve(at: "book-a", handler: resources(["chapter1.xhtml": "A"]) { callsA += 1 })
        _ = await sut.get("\(scheme)://book-a/chapter1.xhtml")

        XCTAssertEqual(callsA, 2, "The cached resource outlived the route it was served from")
        XCTAssertEqual(callsB, 1, "Book B's cache was dropped along with book A's route")
    }

    /// Route names are matched on segment boundaries: `book1` and `book10` are
    /// unrelated routes even though one is a textual prefix of the other.
    func testRemovingARouteLeavesRoutesWithACollidingNameAlone() async {
        let sut = makeSUT()
        sut.serve(at: "book1", handler: resources(["chapter1.xhtml": "one"]))
        sut.serve(at: "book10", handler: resources(["chapter1.xhtml": "ten"]))

        sut.remove(at: "book1")

        let removed = await sut.get("\(scheme)://book1/chapter1.xhtml")
        XCTAssertNotNil(removed.error, "The removed route is still being served")

        let survivor = await sut.get("\(scheme)://book10/chapter1.xhtml")
        XCTAssertEqual(survivor.receivedString, "ten", "Removing book1 also took down book10")
    }

    func testRemovingARouteKeepsTheCacheOfRoutesWithACollidingName() async {
        let sut = makeSUT()
        var calls = 0
        sut.serve(at: "book1", handler: resources(["chapter1.xhtml": "one"]))
        sut.serve(at: "book10", handler: resources(["chapter1.xhtml": "ten"]) { calls += 1 })

        _ = await sut.get("\(scheme)://book10/chapter1.xhtml")
        XCTAssertEqual(calls, 1)

        sut.remove(at: "book1")
        _ = await sut.get("\(scheme)://book10/chapter1.xhtml")

        XCTAssertEqual(calls, 1, "Removing book1 evicted book10's cached resource")
    }

    func testClearingTheCacheLeavesRoutesWithACollidingNameAlone() async {
        let sut = makeSUT()
        var calls = 0
        sut.serve(at: "book1", handler: resources(["chapter1.xhtml": "one"]))
        sut.serve(at: "book10", handler: resources(["chapter1.xhtml": "ten"]) { calls += 1 })

        _ = await sut.get("\(scheme)://book10/chapter1.xhtml")
        sut.clearResourceCache(atRoute: "book1") { _, _ in true }
        _ = await sut.get("\(scheme)://book10/chapter1.xhtml")

        XCTAssertEqual(calls, 1, "Clearing book1's cache evicted book10's resource")
    }

    func testUnknownRouteFails() async {
        let sut = makeSUT()
        sut.serve(at: "book-a", handler: resources(["chapter1.xhtml": "A"]))

        let response = await sut.get("\(scheme)://book-b/chapter1.xhtml")

        XCTAssertNotNil(response.error)
    }

    // MARK: - Helpers

    private func makeSUT() -> WebViewServer {
        WebViewServer(scheme: scheme, formatSniffer: DefaultFormatSniffer())
    }

    /// Builds a resource handler serving the given UTF-8 bodies by path.
    private func resources(
        _ bodies: [String: String],
        onServe: @escaping () -> Void = {}
    ) -> (RelativeURL) async -> (Resource, MediaType)? {
        { relativeURL in
            guard let body = bodies[relativeURL.string] else {
                return nil
            }
            onServe()
            return (DataResource(string: body), .xhtml)
        }
    }
}

private extension WebViewServer {
    /// Serves the given URL and waits for the response.
    func get(_ url: String) async -> URLSchemeTaskSpy {
        let task = URLSchemeTaskSpy(url: url)
        start(task)
        await task.complete()
        return task
    }
}
