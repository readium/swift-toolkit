//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import UIKit

@MainActor protocol EPUBNavigatorViewModelDelegate: AnyObject {
    func epubNavigatorViewModel(_ viewModel: EPUBNavigatorViewModel, runScript script: String, in scope: EPUBScriptScope)
    func epubNavigatorViewModelInvalidatePaginationView(_ viewModel: EPUBNavigatorViewModel)
    func epubNavigatorViewModel(_ viewModel: EPUBNavigatorViewModel, didFailToLoadResourceAt href: RelativeURL, withError error: ReadError)
}

enum EPUBScriptScope: Sendable {
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

    /// Local file URL associated to the HTTP URL used to serve the file on the
    /// `server`. This is used to serve custom font files, for example.
    @Atomic private var servedFonts: [FileURL: AbsoluteURL] = [:]

    let readingOrder: ReadingOrder

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
            publicationBaseURL = server.serve(at: UUID().uuidString) { [weak self] href in
                await self?.serve(href: href)
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
        var config = config

        if let fontsDir = Bundle.module.resourceURL?.fileURL?.appendingPath("Assets/Static/fonts", isDirectory: true) {
            config.fontFamilyDeclarations.append(
                CSSFontFamilyDeclaration(
                    fontFamily: .openDyslexic,
                    fontFaces: [
                        CSSFontFace(
                            file: fontsDir.appendingPath("OpenDyslexic-Regular.otf", isDirectory: false),
                            style: .normal, weight: .standard(.normal)
                        ),
                        CSSFontFace(
                            file: fontsDir.appendingPath("OpenDyslexic-Italic.otf", isDirectory: false),
                            style: .italic, weight: .standard(.normal)
                        ),
                        CSSFontFace(
                            file: fontsDir.appendingPath("OpenDyslexic-Bold.otf", isDirectory: false),
                            style: .normal, weight: .standard(.bold)
                        ),
                        CSSFontFace(
                            file: fontsDir.appendingPath("OpenDyslexic-BoldItalic.otf", isDirectory: false),
                            style: .italic, weight: .standard(.bold)
                        ),
                    ]
                ).eraseToAnyHTMLFontFamilyDeclaration()
            )
        }

        self.publication = publication
        self.readingOrder = readingOrder
        self.config = config
        editingActions = EditingActionsController(
            actions: config.editingActions,
            publication: publication
        )
        self.server = server
        self.assetsBaseURL = assetsBaseURL
        self.formatSniffer = formatSniffer

        preferences = config.preferences
        settings = EPUBSettings(publication: publication, config: config)

        _css = Atomic(wrappedValue: ReadiumCSS(
            layout: CSSLayout(),
            rsProperties: config.readiumCSSRSProperties,
            baseURL: assetsBaseURL.appendingPath("readium-css", isDirectory: true),
            fontFamilyDeclarations: config.fontFamilyDeclarations
        ))

        $css.write { $0.update(with: settings) }

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
        DispatchQueue.main.async { [self] in
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

        let server = server
        let scheme = server.scheme
        let servedFontsAtomic = _servedFonts
        let cssAtomic = _css
        let fontDeclarations = config.fontFamilyDeclarations
        let publication = publication

        let serveFont: @Sendable (FileURL) async throws -> AbsoluteURL = { file in
            if let url = servedFontsAtomic.read()[file] {
                return url
            }

            let name = file.lastPathSegment ?? UUID().uuidString
            let path = "assets/fonts/\(name)"
            let urlString = "\(scheme)://\(path)"
            let url = AnyURL(string: urlString)!.absoluteURL!

            servedFontsAtomic.write { $0[file] = url }

            _ = await MainActor.run {
                server.serve(file: file, at: path)
            }

            return url
        }

        let css = cssAtomic.read()

        resource = Self.injectReadiumCSS(
            in: resource,
            at: href,
            publication: publication,
            css: css,
            fontFamilyDeclarations: fontDeclarations,
            serveFont: serveFont
        )

        return (resource, mediaType)
    }

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

    private func applyPreferences() {
        let oldSettings = settings
        let newSettings = EPUBSettings(
            preferences: preferences,
            publication: publication,
            config: config
        )

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

    func editor(of preferences: EPUBPreferences) -> EPUBPreferencesEditor {
        EPUBPreferencesEditor(
            initialPreferences: preferences,
            metadata: publication.metadata,
            defaults: config.defaults
        )
    }

    var readingProgression: ReadingProgression {
        settings.readingProgression
    }

    var theme: Theme {
        settings.theme
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

    func viewSizeWillChange(_ newSize: CGSize) {
        guard viewSize != newSize else {
            return
        }
        viewSize = newSize
        updateSpread()
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

    @Atomic private var css: ReadiumCSS

    nonisolated static func injectReadiumCSS<HREF: URLConvertible>(
        in resource: Resource,
        at href: HREF,
        publication: Publication,
        css: ReadiumCSS,
        fontFamilyDeclarations: [AnyHTMLFontFamilyDeclaration],
        serveFont: @escaping @Sendable (FileURL) async throws -> AbsoluteURL
    ) -> Resource {
        guard
            let link = publication.linkWithHREF(href),
            link.mediaType?.isHTML == true,
            publication.metadata.epubLayout == .reflowable
        else {
            return resource
        }

        return resource.mapAsString { content in
            do {
                var content = try css.inject(in: content)
                for ff in fontFamilyDeclarations {
                    content = try await ff.inject(in: content, servingFile: serveFont)
                }
                return content
            } catch {
                log(.error, error)
                return content
            }
        }
    }

    private func updateCSS(with settings: EPUBSettings, commitNow: Bool) {
        let previous = css
        $css.write { $0.update(with: settings) }

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
    @MainActor
    init(
        preferences: EPUBPreferences? = nil,
        publication: Publication,
        config: EPUBNavigatorViewController.Configuration
    ) {
        self.init(
            preferences: preferences ?? config.preferences,
            defaults: config.defaults,
            metadata: publication.metadata
        )

        // Force-enables scroll when VoiceOver is running, because pagination
        // breaks the screen reader.
        if UIAccessibility.isVoiceOverRunning {
            scroll = true
        }
    }
}
