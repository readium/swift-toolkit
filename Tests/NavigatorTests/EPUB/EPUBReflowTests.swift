//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumNavigator
import ReadiumShared
import Testing
import UIKit

@MainActor
struct EPUBReflowTests {
    @Test(.timeLimit(.minutes(2)))
    func retainsPassageThroughFontChangesAndReloadThenAdoptsNavigation() async throws {
        let href = AnyURL(string: "chapter.xhtml")!
        let words = (0..<1600).map { "<span id='w\($0)'>word\($0)</span>" }.joined(separator: " ")
        let publication = Publication(
            manifest: Manifest(metadata: Metadata(title: "Reflow regression"), readingOrder: [
                Link(href: href.string, mediaType: .xhtml),
            ]),
            container: SingleResourceContainer(
                resource: DataResource(string: "<html xmlns='http://www.w3.org/1999/xhtml'><head><title>Reflow</title></head><body><p>\(words)</p></body></html>"),
                at: href
            )
        )
        let navigator = try EPUBNavigatorViewController(publication: publication, initialLocation: nil,
            config: .init(preferences: .init(fontSize: 1.25, spread: .never)))
        let host = UIViewController()
        host.addChild(navigator)
        host.view.addSubview(navigator.view)
        navigator.view.frame = CGRect(x: 0, y: 0, width: 400, height: 700)
        navigator.didMove(toParent: host)
        let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            .map { UIWindow(windowScene: $0) } ?? UIWindow(frame: host.view.bounds)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }

        try await settle(navigator)
        #expect(await navigator.go(to: Locator(href: href, mediaType: .xhtml,
            locations: .init(progression: 0.65)), options: .init(animated: false)))
        try await settle(navigator)
        let original = try await firstWord(navigator)
        #expect(Int(original.dropFirst())! > 500)
        // Font changes reflow the existing document. Spread changes reload it.
        for _ in 0..<3 {
            for fontSize in [1.625, 1.25] {
                navigator.submitPreferences(.init(fontSize: fontSize, spread: .never))
                try await settle(navigator)
                #expect(try await visible(original, in: navigator))
            }
        }
        for spread in [Spread.always, .never] {
            navigator.submitPreferences(.init(fontSize: 1.25, spread: spread))
            try await settle(navigator)
            #expect(try await visible(original, in: navigator))
        }
        #expect(await navigator.goForward(options: .init(animated: false)))
        try await settle(navigator)
        let moved = try await firstWord(navigator)
        #expect(moved != original)
        navigator.submitPreferences(.init(fontSize: 1.625, spread: .never))
        try await settle(navigator)
        #expect(try await visible(moved, in: navigator))
    }

    private func settle(_ navigator: EPUBNavigatorViewController) async throws {
        var previous = ""
        var stable = 0
        for _ in 0..<100 {
            try await Task.sleep(for: .milliseconds(100))
            if case let .success(value) = await navigator.evaluateJavaScript("document.readyState === 'complete' && readium.link ? [innerWidth,innerHeight,scrollX,document.body.scrollWidth].join(':') : ''"),
               let value = value as? String, !value.isEmpty {
                stable = value == previous ? stable + 1 : 0
                previous = value
                if stable >= 6 { return }
            }
        }
        throw Failure.timeout
    }

    private func firstWord(_ navigator: EPUBNavigatorViewController) async throws -> String {
        let result = try await navigator.evaluateJavaScript("Array.from(document.querySelectorAll('span')).find(e => {const r=e.getBoundingClientRect(); return r.left>=0 && r.top>=0 && r.right<=innerWidth && r.bottom<=innerHeight;})?.id").get()
        return try #require(result as? String)
    }

    private func visible(_ id: String, in navigator: EPUBNavigatorViewController) async throws -> Bool {
        let result = try await navigator.evaluateJavaScript("(() => {const r=document.getElementById('\(id)').getBoundingClientRect(); return r.right>0 && r.left<innerWidth && r.bottom>0 && r.top<innerHeight;})()").get() as? Bool == true
        return result
    }

    private enum Failure: Error { case timeout }
}
