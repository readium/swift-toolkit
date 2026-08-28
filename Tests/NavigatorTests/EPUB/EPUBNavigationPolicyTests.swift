//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumNavigator
import ReadiumShared
import Testing

struct EPUBNavigationPolicyTests {
    struct ExpectedLoads {
        let policy = makePolicy()

        @Test("The initial load of a spread resource in the main frame is allowed")
        func initialResourceLoad() {
            #expect(policy.decide(
                navigationTo: url("http://localhost/pub/chapter1.xhtml"),
                targetFrameURL: nil,
                targetsMainFrame: true,
                isLinkActivation: false
            ) == .allow)
        }

        @Test("The load of the fixed layout wrapper page is allowed")
        func wrapperPageLoad() {
            #expect(policy.decide(
                navigationTo: url("http://localhost/pub/"),
                targetFrameURL: nil,
                targetsMainFrame: true,
                isLinkActivation: false
            ) == .allow)
        }

        @Test("The load of a spread resource in a fixed layout iframe is allowed")
        func resourceLoadInIframe() {
            #expect(policy.decide(
                navigationTo: url("http://localhost/pub/chapter2.xhtml"),
                targetFrameURL: url("about:blank"),
                targetsMainFrame: false,
                isLinkActivation: false
            ) == .allow)
        }

        @Test("The initial `about:blank` load of a nested frame is allowed")
        func aboutBlankInNestedFrame() {
            #expect(policy.decide(
                navigationTo: url("about:blank"),
                targetFrameURL: nil,
                targetsMainFrame: false,
                isLinkActivation: false
            ) == .allow)
        }

        @Test("A navigation without a URL is allowed")
        func missingURL() {
            #expect(policy.decide(
                navigationTo: nil,
                targetFrameURL: nil,
                targetsMainFrame: true,
                isLinkActivation: false
            ) == .allow)
        }
    }

    struct ScriptNavigations {
        let policy = makePolicy()

        @Test("Setting `window.location` to another resource is delegated as an internal link")
        func redirectToOtherResource() {
            #expect(policy.decide(
                navigationTo: url("http://localhost/pub/other.xhtml"),
                targetFrameURL: url("http://localhost/pub/chapter1.xhtml"),
                targetsMainFrame: true,
                isLinkActivation: false
            ) == .internalLink(href: "other.xhtml"))
        }

        @Test("Setting `window.location` to a resource fragment is delegated as an internal link")
        func redirectToResourceFragment() {
            #expect(policy.decide(
                navigationTo: url("http://localhost/pub/other.xhtml#section2"),
                targetFrameURL: url("http://localhost/pub/chapter1.xhtml"),
                targetsMainFrame: true,
                isLinkActivation: false
            ) == .internalLink(href: "other.xhtml#section2"))
        }

        @Test("Setting `window.location` to an external HTTP URL is delegated as an external URL")
        func redirectToExternalURL() {
            #expect(policy.decide(
                navigationTo: url("https://example.com/page"),
                targetFrameURL: url("http://localhost/pub/chapter1.xhtml"),
                targetsMainFrame: true,
                isLinkActivation: false
            ) == .externalURL(url("https://example.com/page")))
        }

        @Test(
            "Setting `window.location` to an unsafe scheme is blocked",
            arguments: [
                "data:text/html;charset=utf-8,%3Cbody%3E",
                "javascript:alert(1)",
                "file:///etc/passwd",
                "blob:http://localhost/1234",
                "custom-app://action",
                "about:blank",
            ]
        )
        func redirectToUnsafeScheme(urlString: String) {
            #expect(policy.decide(
                navigationTo: url(urlString),
                targetFrameURL: url("http://localhost/pub/chapter1.xhtml"),
                targetsMainFrame: true,
                isLinkActivation: false
            ) == .block)
        }

        @Test("An HTTP URL on the same origin but outside the publication is treated as external")
        func redirectOutsidePublicationSameOrigin() {
            #expect(policy.decide(
                navigationTo: url("http://localhost/other-pub/chapter1.xhtml"),
                targetFrameURL: url("http://localhost/pub/chapter1.xhtml"),
                targetsMainFrame: true,
                isLinkActivation: false
            ) == .externalURL(url("http://localhost/other-pub/chapter1.xhtml")))
        }

        @Test("A URL served by the publication server but outside the publication route is blocked")
        func redirectOutsidePublicationRoute() {
            // The web view server uses a custom URL scheme in practice.
            let policy = EPUBNavigationPolicy(
                publicationBaseURL: AnyURL(string: "readium://pub/")!.absoluteURL!,
                expectedLoadURLs: [AnyURL(string: "readium://pub/chapter1.xhtml")!]
            )
            #expect(policy.decide(
                navigationTo: url("readium://other-pub/chapter1.xhtml"),
                targetFrameURL: url("readium://pub/chapter1.xhtml"),
                targetsMainFrame: true,
                isLinkActivation: false
            ) == .block)
        }
    }

    struct LinkActivations {
        let policy = makePolicy()

        @Test("Tapping an internal link is delegated as an internal link")
        func internalLink() {
            #expect(policy.decide(
                navigationTo: url("http://localhost/pub/other.xhtml#note1"),
                targetFrameURL: url("http://localhost/pub/chapter1.xhtml"),
                targetsMainFrame: true,
                isLinkActivation: true
            ) == .internalLink(href: "other.xhtml#note1"))
        }

        @Test("Tapping a link to the spread's own resource is delegated as an internal link")
        func linkToOwnResource() {
            #expect(policy.decide(
                navigationTo: url("http://localhost/pub/chapter1.xhtml"),
                targetFrameURL: url("http://localhost/pub/chapter1.xhtml"),
                targetsMainFrame: true,
                isLinkActivation: true
            ) == .internalLink(href: "chapter1.xhtml"))
        }

        @Test("Tapping an external link is delegated as an external URL",
              arguments: [
                  "https://example.com/page",
                  "mailto:hello@example.com",
                  "tel:+1234567890",
              ])
        func externalLink(urlString: String) {
            #expect(policy.decide(
                navigationTo: url(urlString),
                targetFrameURL: url("http://localhost/pub/chapter1.xhtml"),
                targetsMainFrame: true,
                isLinkActivation: true
            ) == .externalURL(url(urlString)))
        }

        @Test("Tapping an unsafe link is blocked",
              arguments: [
                  "data:text/html;charset=utf-8,%3Cbody%3E",
                  "about:blank",
              ])
        func unsafeLink(urlString: String) {
            #expect(policy.decide(
                navigationTo: url(urlString),
                targetFrameURL: url("http://localhost/pub/chapter1.xhtml"),
                targetsMainFrame: true,
                isLinkActivation: true
            ) == .block)
        }

        @Test("Tapping an internal link in a nested iframe is delegated as an internal link")
        func internalLinkInIframe() {
            #expect(policy.decide(
                navigationTo: url("http://localhost/pub/other.xhtml"),
                targetFrameURL: url("http://localhost/pub/embedded.xhtml"),
                targetsMainFrame: false,
                isLinkActivation: true
            ) == .internalLink(href: "other.xhtml"))
        }
    }

    struct NestedFrames {
        let policy = makePolicy()

        @Test("A nested iframe loading an external URL is allowed")
        func externalIframeLoad() {
            #expect(policy.decide(
                navigationTo: url("https://www.youtube.com/embed/1234"),
                targetFrameURL: url("about:blank"),
                targetsMainFrame: false,
                isLinkActivation: false
            ) == .allow)
        }

        @Test("A nested iframe loading a publication resource is allowed")
        func internalIframeLoad() {
            #expect(policy.decide(
                navigationTo: url("http://localhost/pub/embedded.xhtml"),
                targetFrameURL: nil,
                targetsMainFrame: false,
                isLinkActivation: false
            ) == .allow)
        }

        @Test("Redirecting a fixed layout resource iframe to another resource is delegated as an internal link")
        func resourceIframeRedirectToResource() {
            #expect(policy.decide(
                navigationTo: url("http://localhost/pub/other.xhtml"),
                targetFrameURL: url("http://localhost/pub/chapter1.xhtml"),
                targetsMainFrame: false,
                isLinkActivation: false
            ) == .internalLink(href: "other.xhtml"))
        }

        @Test("Redirecting a fixed layout resource iframe to a `data:` URL is blocked")
        func resourceIframeRedirectToData() {
            #expect(policy.decide(
                navigationTo: url("data:text/html;charset=utf-8,%3Cbody%3E"),
                targetFrameURL: url("http://localhost/pub/chapter2.xhtml"),
                targetsMainFrame: false,
                isLinkActivation: false
            ) == .block)
        }
    }
}

// MARK: - Helpers

/// Makes a policy for a publication served at `http://localhost/pub/`, with a
/// spread expected to load `chapter1.xhtml` and `chapter2.xhtml`, as well as
/// the fixed layout wrapper page at the base URL.
private func makePolicy() -> EPUBNavigationPolicy {
    let baseURL = HTTPURL(string: "http://localhost/pub/")!
    return EPUBNavigationPolicy(
        publicationBaseURL: baseURL,
        expectedLoadURLs: [
            AnyURL(string: "http://localhost/pub/chapter1.xhtml")!,
            AnyURL(string: "http://localhost/pub/chapter2.xhtml")!,
            baseURL.anyURL,
        ]
    )
}

private func url(_ string: String) -> URL {
    URL(string: string)!
}
