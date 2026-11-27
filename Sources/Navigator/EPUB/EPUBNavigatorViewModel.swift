//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import UIKit

@MainActor
protocol EPUBNavigatorViewModelDelegate: AnyObject {
    func epubNavigatorViewModel(_ viewModel: EPUBNavigatorViewModel, runScript script: String, in scope: EPUBScriptScope)
    func epubNavigatorViewModelInvalidatePaginationView(_ viewModel: EPUBNavigatorViewModel)
    func epubNavigatorViewModel(_ viewModel: EPUBNavigatorViewModel, didFailToLoadResourceAt href: RelativeURL, withError error: ReadError)
}

enum EPUBScriptScope {
    case currentResource
    case loadedResources
    case resource(href: AnyURL)
}

@MainActor final class EPUBNavigatorViewModel: Loggable {
    let publication: Publication
    let config: EPUBNavigatorViewController.Configuration
    let editingActions: EditingActionsController

    /// The base URL for the publication resources.
    private(set) var publicationBaseURL: AbsoluteURL!

    /// The base URL for Readium assets (CSS, scripts, etc.) and fonts.
    let assetsBaseURL: any AbsoluteURL

    /// The server used to serve publication resources and static assets to
    /// the web view.
    let server: WebViewServer

    /// Format sniffer used to infer the media type of resources served with
    /// the `server`.
    let formatSniffer: FormatSniffer

    weak var delegate: EPUBNavigatorViewModelDelegate?

    /// Reading order rendered by the navigator.
    let readingOrder: EPUBReadingOrder

    /// Layouts of the resources in the `readingOrder`, which determine the
    /// applicable settings.
    private let layouts: EPUBLayouts

    convenience init(
        publication: Publication,
        readingOrder: ReadingOrder,
        config: EPUBNavigatorViewController.Configuration
    ) {
        let assetsDirectory = Bundle.module.resourceURL!.fileURL!
            .appendingPath("Assets/Static", isDirectory: true)

        let formatSniffer = DefaultFormatSniffer()
        let server = WebViewServer(scheme: "readium", formatSniffer: formatSniffer)

        // Serve static assets directory.
        let assetsBaseURL = server.serve(directory: assetsDirectory, at: "assets")

        self.init(
            publication: publication,
            readingOrder: readingOrder,
            config: config,
            server: server,
            assetsBaseURL: assetsBaseURL,
            formatSniffer: formatSniffer
        )

        if let url = publication.baseURL {
            // The publication already has an HTTP base URL (e.g. served
            // remotely). Use it directly; the server only needs to serve
            // assets.
            publicationBaseURL = url
        } else {
            // Serve publication resources.
            publicationBaseURL = server.serve(at: UUID().uuidString) { [weak self] in
                await self?.serve(href: $0)
            }
        }
    }

    private init(
        publication: Publication,
        readingOrder: ReadingOrder,
        config: EPUBNavigatorViewController.Configuration,
        server: WebViewServer,
        assetsBaseURL: any AbsoluteURL,
        formatSniffer: FormatSniffer
    ) {
        self.publication = publication
        self.readingOrder = EPUBReadingOrder(
            readingOrder: readingOrder,
            preferredVariant: config.preferredResourceVariant
        )
        layouts = EPUBLayouts(
            readingOrder: self.readingOrder.links,
            metadata: publication.metadata
        )
        self.config = config
        editingActions = EditingActionsController(
            actions: config.editingActions,
            publication: publication
        )
        self.server = server
        self.assetsBaseURL = assetsBaseURL
        self.formatSniffer = formatSniffer
        servedFonts = server.serve(config.fontFamilyDeclarations)

        preferences = config.preferences
        settings = EPUBSettings(
            preferences: config.preferences,
            metadata: publication.metadata,
            layouts: layouts,
            config: config
        )

        css = ReadiumCSS(
            layout: CSSLayout(),
            baseURL: assetsBaseURL.appendingPath("readium-css", isDirectory: true),
            fontFamilyDeclarations: config.fontFamilyDeclarations,
            isEBPAJ: publication.metadata.isEBPAJ
        )

        css.update(with: settings, userInterfaceIdiom: userInterfaceIdiom)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceOverStatusDidChange),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func url(to link: Link) -> AnyURL {
        link.url(relativeTo: publicationBaseURL)
    }

    private var needsInvalidatePagination = false
    private func setNeedsInvalidatePagination() {
        guard !needsInvalidatePagination else {
            return
        }
        needsInvalidatePagination = true
        Task { @MainActor [self] in
            needsInvalidatePagination = false
            delegate?.epubNavigatorViewModelInvalidatePaginationView(self)
        }
    }

    // MARK: - Web View Server

    private func serve(href: RelativeURL) async -> (Resource, MediaType)? {
        guard var resource = publication.get(href) else {
            return nil
        }
        let mediaType = await resolveMediaType(for: resource, at: href)
        resource = injectReadiumCSS(in: resource, at: href)
        return (resource, mediaType)
    }

    /// Resolves the media type to use to serve the given `resource`.
    ///
    /// The media type declared in the manifest takes precedence, before falling
    /// back on the `Resource` properties and sniffing the `href`.
    ///
    /// The manifest takes precedence because a file with a `.xml` extension
    /// might be declared as `application/xhtml+xml` in the OPF.
    private func resolveMediaType(for resource: Resource, at href: RelativeURL) async -> MediaType {
        if let mediaType = publication.linkWithHREF(href)?.mediaType {
            return mediaType
        }
        if let mediaType = await resource.properties().getOrNil()?.mediaType {
            return mediaType
        }

        return href.pathExtension.flatMap { formatSniffer.sniffHints(.init(fileExtension: $0))?.mediaType }
            ?? .binary
    }

    // MARK: - User preferences

    /// Currently applied settings.
    private(set) var settings: EPUBSettings

    /// Last submitted preferences.
    private var preferences: EPUBPreferences

    func submitPreferences(_ preferences: EPUBPreferences) {
        self.preferences = preferences
        applyPreferences()
    }

    /// Resolves the settings which would be applied with `preferences`.
    func settings(for preferences: EPUBPreferences) -> EPUBSettings {
        EPUBSettings(
            preferences: preferences,
            metadata: publication.metadata,
            layouts: layouts,
            config: config
        )
    }

    private func applyPreferences() {
        let oldSettings = settings
        let newSettings = settings(for: preferences)

        settings = newSettings
        updateSpread()

        let needsInvalidation: Bool =
            oldSettings.readingProgression != newSettings.readingProgression
                || oldSettings.language != newSettings.language
                || oldSettings.verticalText != newSettings.verticalText
                || oldSettings.scroll != newSettings.scroll
                || oldSettings.spread != newSettings.spread
                || oldSettings.fit != newSettings.fit
                || oldSettings.offsetFirstPage != newSettings.offsetFirstPage

        // We don't commit the CSS changes if we invalidate the pagination, as
        // the resources will be reloaded anyway.
        updateCSS(with: settings, commitNow: !needsInvalidation)

        if needsInvalidation {
            setNeedsInvalidatePagination()
        }
    }

    var readingProgression: ReadingProgression {
        settings.readingProgression
    }

    var backgroundColor: Color {
        settings.effectiveBackgroundColor
    }

    var scroll: Bool {
        settings.scroll
    }

    var verticalText: Bool {
        settings.verticalText
    }

    var spread: Spread {
        settings.spread
    }

    var offsetFirstPage: Bool? {
        settings.offsetFirstPage
    }

    // MARK: Spread

    private(set) var spreadEnabled: Bool = false
    private var viewSize: CGSize?
    /// Content inset of the reflowable resources, see
    /// `viewDidLayout(size:reflowableContentInset:hingeWidth:)`.
    private var reflowableContentInset: UIEdgeInsets = .zero
    /// Width of the vertical hinge splitting the view in two equal sides, on
    /// a foldable device.
    private var hingeWidth: Double?
    private let layoutResolver = LayoutResolver()

    /// Updates the spread for the size the view is about to take.
    ///
    /// The CSS layout is not resolved here, as the content insets matching
    /// this size are not known yet. It is resolved once the view is laid out,
    /// see `viewDidLayout(size:reflowableContentInset:hingeWidth:)`.
    func viewSizeWillChange(_ newSize: CGSize) {
        guard viewSize != newSize else {
            return
        }
        viewSize = newSize
        updateSpread()
    }

    /// Resolves the CSS layout from the final size and insets of the view, and
    /// commits it when it changed.
    ///
    /// The margins at the ends of the lines can't be smaller than the
    /// `reflowableContentInset`, the content inset of reflowable resources,
    /// at the ends of the lines: left and right with horizontal text, top and
    /// bottom with vertical text. The spread views don't apply it there.
    ///
    /// `hingeWidth` is the width of the vertical hinge splitting the view in
    /// two equal sides, on a foldable device, or `nil` without one. See
    /// `LayoutResolver.verticalHingeWidth(divisions:in:tolerance:)`.
    func viewDidLayout(
        size: CGSize,
        reflowableContentInset: UIEdgeInsets,
        hingeWidth: Double?
    ) {
        viewSizeWillChange(size)
        self.hingeWidth = hingeWidth
        self.reflowableContentInset = reflowableContentInset

        // Most layout passes don't change the layout, for example when the
        // app toggles its bars, which doesn't change the content inset at the
        // ends of the lines. A pass with the same size and insets can still change
        // it: right after a foldable device is unfolded, the hinge is only
        // reported from the second pass.
        guard resolveLayout(with: settings) != resolvedLayout else {
            return
        }
        updateCSS(with: settings, commitNow: true)
    }

    private func updateSpread() {
        let size = viewSize ?? .zero
        let isLandscape = size.width > size.height
        let oldEnabled = spreadEnabled

        switch spread {
        case .never:
            spreadEnabled = false
        case .always:
            spreadEnabled = true
        case .auto:
            spreadEnabled = isLandscape
        }

        if oldEnabled != spreadEnabled {
            setNeedsInvalidatePagination()
        }
    }

    // MARK: - Readium CSS

    private var css: ReadiumCSS
    private let servedFonts: [FileURL: AbsoluteURL]

    /// Device used to choose the WebKit patch of Readium CSS.
    private let userInterfaceIdiom = UIDevice.current.userInterfaceIdiom

    func injectReadiumCSS<HREF: URLConvertible>(in resource: Resource, at href: HREF) -> Resource {
        guard
            let link = publication.linkWithHREF(href),
            link.mediaType?.isHTML == true,
            publication.metadata.epubLayout(of: link) == .reflowable
        else {
            return resource
        }

        let css = css
        let fontFamilyDeclarations = config.fontFamilyDeclarations
        let servedFonts = servedFonts

        return resource.mapAsString { content in
            do {
                var content = try css.inject(in: content)
                for ff in fontFamilyDeclarations {
                    content = try ff.inject(in: content, servedFiles: servedFonts)
                }
                return content
            } catch {
                EPUBNavigatorViewModel.log(.error, error)
                return content
            }
        }
    }

    /// Layout of the current CSS, resolved from the view size.
    private(set) var resolvedLayout: LayoutResolver.Layout?

    private func resolveLayout(with settings: EPUBSettings) -> LayoutResolver.Layout? {
        viewSize.flatMap { size -> LayoutResolver.Layout? in
            guard size.width > 0, size.height > 0 else { return nil }
            return layoutResolver.layout(
                settings: settings,
                fontScale: settings.fontSize,
                viewportSize: size,
                insets: reflowableContentInset,
                hingeWidth: hingeWidth
            )
        }
    }

    private func updateCSS(with settings: EPUBSettings, commitNow: Bool) {
        let previous = css
        resolvedLayout = resolveLayout(with: settings)
        css.update(
            with: settings,
            userInterfaceIdiom: userInterfaceIdiom,
            resolvedLayout: resolvedLayout
        )

        // HTML resources in the cache have the CSS already injected at the time
        // they were first served. Evict them so that any future resource load
        // (e.g. after a screen rotation) reflects the updated CSS instead of
        // the stale cached version. Non-HTML resources (images, audio, etc.)
        // are not affected by CSS changes and can remain cached.
        server.clearResourceCache { _, mediaType in mediaType.isHTML }

        if commitNow {
            commitCSSChange(from: previous, to: css)
        }
    }

    private func commitCSSChange(from previous: ReadiumCSS, to new: ReadiumCSS) {
        var properties: [String: String?] = [:]
        let rsProperties = new.rsProperties.cssProperties()
        if previous.rsProperties.cssProperties() != rsProperties {
            for (k, v) in rsProperties {
                properties[k] = v
            }
        }
        let userProperties = new.userProperties.cssProperties()
        if previous.userProperties.cssProperties() != userProperties {
            for (k, v) in userProperties {
                properties[k] = v
            }
        }
        if !properties.isEmpty {
            guard
                let data = try? JSONSerialization.data(withJSONObject: properties),
                let json = String(data: data, encoding: .utf8)
            else {
                log(.error, "Failed to serialize CSS properties to JSON")
                return
            }

            delegate?.epubNavigatorViewModel(
                self,
                runScript: "readium.setCSSProperties(\(json));",
                in: .loadedResources
            )
        }
    }

    // MARK: - Accessibility

    private var isVoiceOverRunning = UIAccessibility.isVoiceOverRunning

    @objc private func voiceOverStatusDidChange() {
        // Avoids excessive settings refresh when the status didn't change.
        guard isVoiceOverRunning != UIAccessibility.isVoiceOverRunning else {
            return
        }
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning

        // Re-apply preferences to force the scroll mode if needed.
        applyPreferences()
    }
}

private extension EPUBSettings {
    /// Resolves the settings applied by the navigator, shared by
    /// `EPUBNavigatorViewModel.init` and `settings(for:)`.
    @MainActor
    init(
        preferences: EPUBPreferences,
        metadata: Metadata,
        layouts: EPUBLayouts,
        config: EPUBNavigatorViewController.Configuration
    ) {
        self.init(
            preferences: preferences,
            defaults: config.defaults,
            metadata: metadata,
            layouts: layouts
        )

        // Force-enables scroll when VoiceOver is running, because pagination
        // breaks the screen reader.
        if UIAccessibility.isVoiceOverRunning {
            scroll = true
        }
    }
}
