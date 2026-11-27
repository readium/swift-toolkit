//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing

enum PDFSettingsTests {
    @Suite("Resolving the settings") struct Resolution {
        @Test("falls back on fixed values when nothing is set")
        func unset() {
            let settings = settings()
            #expect(settings.backgroundColor == nil)
            #expect(settings.fit == .auto)
            #expect(settings.offsetFirstPage == false)
            #expect(settings.pageSpacing == 0)
            #expect(settings.readingProgression == .ltr)
            #expect(settings.scroll == false)
            #expect(settings.scrollAxis == .vertical)
            #expect(settings.spread == .auto)
            #expect(settings.visibleScrollbar == true)
        }

        @Test("prefers the preferences, then the publication metadata, then the defaults")
        func precedence() {
            let preferences = PDFPreferences(
                backgroundColor: Color(hex: "#FF0000"),
                fit: .width,
                offsetFirstPage: true,
                pageSpacing: 10,
                readingProgression: .ltr,
                scroll: true,
                scrollAxis: .horizontal,
                spread: .never,
                visibleScrollbar: false
            )
            let defaults = PDFDefaults(
                backgroundColor: Color(hex: "#00FF00"),
                fit: .page,
                offsetFirstPage: false,
                pageSpacing: 20,
                readingProgression: .rtl,
                scroll: false,
                scrollAxis: .vertical,
                spread: .always,
                visibleScrollbar: true
            )
            // Every field of the fixtures has a distinct value.
            let defaultValues = values(of: defaults)
            #expect(values(of: preferences).filter { defaultValues[$0.key] == $0.value }.keys.sorted() == [])

            #expect(values(of: settings(defaults: defaults)) == values(of: defaults))
            #expect(values(of: settings(preferences, defaults: defaults, metadataReadingProgression: .rtl)) == values(of: preferences))

            // The reading progression is the only setting given by the
            // publication metadata.
            #expect(settings(defaults: defaults, metadataReadingProgression: .ltr).readingProgression == .ltr)
        }

        @Test("replaces a negative page spacing with 0")
        func negativePageSpacing() {
            var preferences = PDFPreferences()
            preferences.pageSpacing = -10
            #expect(settings(preferences).pageSpacing == 0)

            var defaults = PDFDefaults()
            defaults.pageSpacing = -10
            #expect(settings(defaults: defaults).pageSpacing == 0)
        }
    }

    @Suite("Applicable settings") struct Applicable {
        @Test("are tested for every setting")
        func listsEverySetting() {
            #expect(Set(allSettings.map(\.name)) == Set(Mirror(reflecting: settings()).children.compactMap(\.label)))
        }

        struct Example: Sendable, CustomTestStringConvertible {
            let name: String
            var preferences = PDFPreferences()
            var defaults = PDFDefaults()
            let expected: Set<String>

            var testDescription: String {
                name
            }
        }

        @Test("depend on the scroll mode, the scroll axis and the spread", arguments: [
            Example(
                name: "paginated",
                expected: ["backgroundColor", "offsetFirstPage", "pageSpacing", "readingProgression", "scroll", "spread"]
            ),
            Example(
                name: "paginated without spread",
                preferences: PDFPreferences(spread: .never),
                expected: ["backgroundColor", "pageSpacing", "readingProgression", "scroll", "spread"]
            ),
            Example(
                name: "scrolled horizontally",
                preferences: PDFPreferences(scroll: true, scrollAxis: .horizontal),
                expected: ["backgroundColor", "fit", "pageSpacing", "scroll", "scrollAxis", "visibleScrollbar"]
            ),
            Example(
                name: "scrolled vertically",
                preferences: PDFPreferences(scroll: true, scrollAxis: .vertical),
                expected: ["backgroundColor", "fit", "offsetFirstPage", "pageSpacing", "scroll", "scrollAxis", "spread", "visibleScrollbar"]
            ),
        ])
        func applicable(_ example: Example) {
            let settings = settings(example.preferences, defaults: example.defaults)
            #expect(Set(allSettings.filter { settings.isApplicable($0.keyPath) }.map(\.name)) == example.expected)
        }
    }

    @Suite("Settings resolved by the navigator") @MainActor struct NavigatorResolution {
        @Test("use the publication metadata and the defaults of the configuration")
        func usesPublicationAndDefaults() throws {
            let navigator = try makeNavigator(defaults: PDFDefaults(pageSpacing: 8, scroll: true))
            let settings = navigator.settings(for: PDFPreferences(scroll: false))
            #expect(settings.readingProgression == .rtl)
            #expect(settings.pageSpacing == 8)
            #expect(settings.scroll == false)

            // The type-erased navigator forwards the call.
            #expect(navigator.eraseToAnyConfigurable().settings(for: PDFPreferences(scroll: false)) == settings)
        }

        @Test("are applied unchanged by submitting the same preferences")
        func appliedBySubmitting() throws {
            let navigator = try makeNavigator(defaults: PDFDefaults(pageSpacing: 8))
            let preferences = PDFPreferences(fit: .width, scroll: true, spread: .never)
            let resolved = navigator.settings(for: preferences)
            #expect(navigator.settings != resolved)

            navigator.submitPreferences(preferences)
            #expect(navigator.settings == resolved)
        }
    }
}

@MainActor
private func makeNavigator(defaults: PDFDefaults) throws -> PDFNavigatorViewController {
    try PDFNavigatorViewController(
        publication: Publication(manifest: Manifest(
            metadata: Metadata(title: "Test", readingProgression: .rtl),
            readingOrder: [Link(href: "doc.pdf", mediaType: .pdf)]
        )),
        initialLocation: nil,
        config: .init(defaults: defaults)
    )
}

private func settings(
    _ preferences: PDFPreferences = PDFPreferences(),
    defaults: PDFDefaults = PDFDefaults(),
    metadataReadingProgression: ReadiumShared.ReadingProgression = .auto
) -> PDFSettings {
    PDFSettings(
        publication: Publication(manifest: Manifest(metadata: Metadata(title: "Test", readingProgression: metadataReadingProgression))),
        preferences: preferences,
        defaults: defaults
    )
}

/// Values of the stored properties of `value`, with their names, unwrapping
/// the optionals.
private func values(of value: Any) -> [String: String] {
    Dictionary(uniqueKeysWithValues: Mirror(reflecting: value).children.map { child in
        let wrapped = Mirror(reflecting: child.value)
        let unwrapped = wrapped.displayStyle == .optional ? wrapped.children.first?.value ?? "nil" : child.value
        return (child.label ?? "?", String(describing: unwrapped))
    })
}

/// Every setting of `PDFSettings`, with its name.
private var allSettings: [(name: String, keyPath: PartialKeyPath<PDFSettings>)] {
    [
        ("backgroundColor", \.backgroundColor),
        ("fit", \.fit),
        ("offsetFirstPage", \.offsetFirstPage),
        ("pageSpacing", \.pageSpacing),
        ("readingProgression", \.readingProgression),
        ("scroll", \.scroll),
        ("scrollAxis", \.scrollAxis),
        ("spread", \.spread),
        ("visibleScrollbar", \.visibleScrollbar),
    ]
}
