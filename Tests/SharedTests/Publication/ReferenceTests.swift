//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

private let href = AnyURL(string: "res.html")!

@Suite("WebReference") struct WebReferenceTests {
    @Suite("init") struct InitTests {
        @Test("no fragment - no auto-selector") func noFragment() throws {
            let ref = try WebReference(href: #require(AnyURL(string: "res.html")))
            #expect(ref.cssSelector == nil)
            #expect(ref.text == nil)
            #expect(ref.href.fragment == nil)
        }

        @Test("href is normalized") func hrefIsNormalized() throws {
            let ref = try WebReference(href: #require(AnyURL(string: "HTTP://Example.COM/foo/./bar/../c%27est%20valide.html#section1")))
            #expect(ref.href.string == "http://Example.COM/foo/c'est%20valide.html")
        }

        @Test("HTML-ID fragment sets cssSelector") func htmlIdFragment() throws {
            let ref = try WebReference(href: #require(AnyURL(string: "res.html#section1")))
            #expect(ref.cssSelector == CSSSelector(id: "section1"))
            #expect(ref.text == nil)
            #expect(ref.href.fragment == nil)
        }

        @Test("text-directive fragment sets text") func textDirectiveFragment() throws {
            let ref = try WebReference(href: #require(AnyURL(string: "res.html#:~:text=hello")))
            #expect(ref.text == TextSelector(fragment: ":~:text=hello"))
            #expect(ref.cssSelector == nil)
            #expect(ref.href.fragment == nil)
        }

        @Test("explicit cssSelector overrides fragment") func explicitCSSOverridesFragment() throws {
            let css = CSSSelector(cssSelector: ".custom")
            let ref = try WebReference(href: #require(AnyURL(string: "res.html#section1")), cssSelector: css)
            #expect(ref.cssSelector == css)
            #expect(ref.href.fragment == nil)
        }

        @Test("explicit text overrides text-directive fragment") func explicitTextOverridesFragment() throws {
            let text = TextSelector.quote(TextQuote(start: "world"))
            let ref = try WebReference(href: #require(AnyURL(string: "res.html#:~:text=hello")), text: text)
            #expect(ref.text == text)
            #expect(ref.href.fragment == nil)
        }
    }

    @Suite("isRefined") struct IsRefinedTests {
        @Test("bare href") func bareHref() {
            #expect(WebReference(href: href).isRefined == false)
        }

        @Test("progression nil") func progressionNil() {
            #expect(WebReference(href: href, progression: nil).isRefined == false)
        }

        @Test("progression 0") func progressionZero() {
            #expect(WebReference(href: href, progression: 0).isRefined == false)
        }

        @Test("progression > 0") func progressionPositive() {
            #expect(WebReference(href: href, progression: 0.5).isRefined == true)
        }

        @Test("text set") func textSet() {
            let text = TextSelector.quote(TextQuote(start: "hello"))
            #expect(WebReference(href: href, text: text).isRefined == true)
        }

        @Test("cssSelector set") func cssSelectorSet() {
            let css = CSSSelector(cssSelector: "#section1")
            #expect(WebReference(href: href, cssSelector: css).isRefined == true)
        }
    }
}

@Suite("AudioReference") struct AudioReferenceTests {
    @Suite("init") struct InitTests {
        @Test("no fragment - no auto-selector") func noFragment() throws {
            let ref = try AudioReference(href: #require(AnyURL(string: "audio.mp3")))
            #expect(ref.temporal == nil)
            #expect(ref.href.fragment == nil)
        }

        @Test("href is normalized") func hrefIsNormalized() throws {
            let ref = try AudioReference(href: #require(AnyURL(string: "HTTP://Example.COM/foo/./bar/../c%27est%20valide.mp3#t=10")))
            #expect(ref.href.string == "http://Example.COM/foo/c'est%20valide.mp3")
        }

        @Test("temporal fragment sets temporal") func temporalFragment() throws {
            let ref = try AudioReference(href: #require(AnyURL(string: "audio.mp3#t=10")))
            #expect(ref.temporal == .position(TemporalPosition(time: 10)))
            #expect(ref.href.fragment == nil)
        }

        @Test("explicit temporal overrides fragment") func explicitTemporalOverridesFragment() throws {
            let temporal = TemporalSelector.position(TemporalPosition(time: 5))
            let ref = try AudioReference(href: #require(AnyURL(string: "audio.mp3#t=10")), temporal: temporal)
            #expect(ref.temporal == temporal)
            #expect(ref.href.fragment == nil)
        }
    }

    @Suite("isRefined") struct IsRefinedTests {
        @Test("no temporal") func noTemporal() {
            #expect(AudioReference(href: href).isRefined == false)
        }

        @Test("position at 0") func positionAtZero() {
            #expect(AudioReference(href: href, temporal: .position(TemporalPosition(time: 0))).isRefined == false)
        }

        @Test("position > 0") func positionPositive() {
            #expect(AudioReference(href: href, temporal: .position(TemporalPosition(time: 5))).isRefined == true)
        }

        @Test("clip start 0 end nil") func clipStartZeroEndNil() {
            #expect(AudioReference(href: href, temporal: .clip(TemporalClip(start: 0, end: nil))).isRefined == false)
        }

        @Test("clip start 0 end set") func clipStartZeroEndSet() {
            #expect(AudioReference(href: href, temporal: .clip(TemporalClip(start: 0, end: 10))).isRefined == true)
        }

        @Test("clip start > 0") func clipStartPositive() {
            #expect(AudioReference(href: href, temporal: .clip(TemporalClip(start: 5, end: nil))).isRefined == true)
        }
    }
}

@Suite("ImageReference") struct ImageReferenceTests {
    @Suite("init") struct InitTests {
        @Test("no fragment - no auto-selector") func noFragment() throws {
            let ref = try ImageReference(href: #require(AnyURL(string: "img.jpg")))
            #expect(ref.spatial == nil)
            #expect(ref.href.fragment == nil)
        }

        @Test("href is normalized") func hrefIsNormalized() throws {
            let ref = try ImageReference(href: #require(AnyURL(string: "HTTP://Example.COM/foo/./bar/../c%27est%20valide.jpg#xywh=0,0,100,100")))
            #expect(ref.href.string == "http://Example.COM/foo/c'est%20valide.jpg")
        }

        @Test("spatial fragment sets spatial") func spatialFragment() throws {
            let ref = try ImageReference(href: #require(AnyURL(string: "img.jpg#xywh=0,0,100,100")))
            #expect(ref.spatial == SpatialSelector(fragment: "xywh=0,0,100,100"))
            #expect(ref.href.fragment == nil)
        }

        @Test("explicit spatial overrides fragment") func explicitSpatialOverridesFragment() throws {
            let spatial = SpatialSelector(x: 10, y: 20, width: 50, height: 50, unit: .pixel)
            let ref = try ImageReference(href: #require(AnyURL(string: "img.jpg#xywh=0,0,100,100")), spatial: spatial)
            #expect(ref.spatial == spatial)
            #expect(ref.href.fragment == nil)
        }
    }

    @Suite("isRefined") struct IsRefinedTests {
        @Test("no spatial") func noSpatial() {
            #expect(ImageReference(href: href).isRefined == false)
        }

        @Test("spatial set") func spatialSet() {
            let spatial = SpatialSelector(x: 10, y: 20, width: 50, height: 50, unit: .pixel)
            #expect(ImageReference(href: href, spatial: spatial).isRefined == true)
        }
    }
}

@Suite("PDFReference") struct PDFReferenceTests {
    @Suite("init") struct InitTests {
        @Test("no fragment - no auto-selector") func noFragment() throws {
            let ref = try PDFReference(href: #require(AnyURL(string: "doc.pdf")))
            #expect(ref.page == nil)
            #expect(ref.href.fragment == nil)
        }

        @Test("href is normalized") func hrefIsNormalized() throws {
            let ref = try PDFReference(href: #require(AnyURL(string: "HTTP://Example.COM/foo/./bar/../c%27est%20valide.pdf#page=3")))
            #expect(ref.href.string == "http://Example.COM/foo/c'est%20valide.pdf")
        }

        @Test("page fragment sets page") func pageFragment() throws {
            let ref = try PDFReference(href: #require(AnyURL(string: "doc.pdf#page=3")))
            #expect(ref.page == PDFSelector(page: 3))
            #expect(ref.href.fragment == nil)
        }

        @Test("explicit page overrides fragment") func explicitPageOverridesFragment() throws {
            let page = PDFSelector(page: 5)
            let ref = try PDFReference(href: #require(AnyURL(string: "doc.pdf#page=3")), page: page)
            #expect(ref.page == page)
            #expect(ref.href.fragment == nil)
        }
    }

    @Suite("isRefined") struct IsRefinedTests {
        @Test("bare href") func bareHref() {
            #expect(PDFReference(href: href).isRefined == false)
        }

        @Test("progression 0") func progressionZero() {
            #expect(PDFReference(href: href, progression: 0).isRefined == false)
        }

        @Test("progression > 0") func progressionPositive() {
            #expect(PDFReference(href: href, progression: 0.5).isRefined == true)
        }

        @Test("text set") func textSet() {
            let text = TextSelector.quote(TextQuote(start: "hello"))
            #expect(PDFReference(href: href, text: text).isRefined == true)
        }

        @Test("page 1 no rect") func pageOneNoRect() {
            #expect(PDFReference(href: href, page: PDFSelector(page: 1)).isRefined == false)
        }

        @Test("page > 1") func pageGreaterThanOne() {
            #expect(PDFReference(href: href, page: PDFSelector(page: 2)).isRefined == true)
        }

        @Test("page 1 with rect") func pageOneWithRect() {
            let rect = PDFSelector.Rect(left: 0, top: 0, width: 100, height: 100)
            #expect(PDFReference(href: href, page: PDFSelector(page: 1, rect: rect)).isRefined == true)
        }
    }
}
