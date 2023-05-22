//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared
import UIKit

protocol EPUBNavigatorViewModelDelegate: AnyObject {
    func epubNavigatorViewModel(_ viewModel: EPUBNavigatorViewModel, runScript script: String, in scope: EPUBScriptScope)
    func epubNavigatorViewModelInvalidatePaginationView(_ viewModel: EPUBNavigatorViewModel)
}

enum EPUBScriptScope {
    case currentResource
    case loadedResources
    case resource(href: String)
}

final class EPUBNavigatorViewModel: Loggable {
    enum Error: Swift.Error {
        case noHTTPServer
    }

    let publication: Publication
    let config: EPUBNavigatorViewController.Configuration
    let editingActions: EditingActionsController
    private let httpServer: HTTPServer?
    private let publicationEndpoint: HTTPServerEndpoint?
    let publicationBaseURL: URL
    let assetsURL: URL
    weak var delegate: EPUBNavigatorViewModelDelegate?

    let useLegacySettings: Bool

    /// Local file URL associated to the HTTP URL used to serve the file on the
    /// `httpServer`. This is used to serve custom font files, for example.
    @Atomic private var servedFiles: [URL: URL] = [:]

    convenience init(
        publication: Publication,
        config: EPUBNavigatorViewController.Configuration,
        httpServer: HTTPServer
    ) throws {
        let publicationEndpoint: HTTPServerEndpoint?
        let baseURL: URL
        if let url = publication.baseURL {
            publicationEndpoint = nil
            baseURL = url
        } else {
            let endpoint = UUID().uuidString
            publicationEndpoint = endpoint
            baseURL = try httpServer.serve(
                at: endpoint,
                publication: publication
            )
        }

        // FIXME: Remove in Readium 3.0
        // Serve the fonts under the /fonts endpoint as the Streamer's
        // EPUBHTMLInjector is expecting it there.
        if let fontsURL = Bundle.module.resourceURL?.appendingPathComponent("Assets/Static/fonts") {
            try httpServer.serve(at: "fonts", contentsOf: fontsURL)
        }

        try self.init(
            publication: publication,
            config: config,
            httpServer: httpServer,
            publicationEndpoint: publicationEndpoint,
            publicationBaseURL: baseURL,
            assetsURL: httpServer.serve(
                at: "readium",
                contentsOf: Bundle.module.resourceURL!.appendingPathComponent("Assets/Static")
            ),
            useLegacySettings: false
        )

        if let endpoint = publicationEndpoint {
            httpServer.transformResources(at: endpoint) { [weak self] in
                self?.injectReadiumCSS(in: $0) ?? $0
            }
        }
    }

    @available(*, deprecated, message: "See the 2.5.0 migration guide to migrate the Settings API")
    convenience init(
        publication: Publication,
        config: EPUBNavigatorViewController.Configuration,
        resourcesServer: ResourcesServer
    ) {
        guard let baseURL = publication.baseURL else {
            preconditionFailure("No base URL provided for the publication. Add it to the HTTP server.")
        }

        publication.userProperties.properties = config.userSettings.userProperties.properties

        self.init(
            publication: publication,
            config: config,
            httpServer: nil,
            publicationEndpoint: nil,
            publicationBaseURL: baseURL,
            assetsURL: {
                do {
                    return try resourcesServer.serve(
                        Bundle.module.resourceURL!.appendingPathComponent("Assets/Static"),
                        at: "/r2-navigator/epub"
                    )
                } catch {
                    EPUBNavigatorViewController.log(.error, error)
                    return URL(string: "")!
                }
            }(),
            useLegacySettings: true
        )
    }

    private init(
        publication: Publication,
        config: EPUBNavigatorViewController.Configuration,
        httpServer: HTTPServer?,
        publicationEndpoint: HTTPServerEndpoint?,
        publicationBaseURL: URL,
        assetsURL: URL,
        useLegacySettings: Bool
    ) {
        var config = config

        if let fontsDir = Bundle.module.resourceURL?.appendingPathComponent("Assets/Static/fonts") {
            config.fontFamilyDeclarations.append(
                CSSFontFamilyDeclaration(
                    fontFamily: .openDyslexic,
                    fontFaces: [
                        CSSFontFace(
                            file: fontsDir.appendingPathComponent("OpenDyslexic-Regular.otf"),
                            style: .normal, weight: .standard(.normal)
                        ),
                        CSSFontFace(
                            file: fontsDir.appendingPathComponent("OpenDyslexic-Italic.otf"),
                            style: .italic, weight: .standard(.normal)
                        ),
                        CSSFontFace(
                            file: fontsDir.appendingPathComponent("OpenDyslexic-Bold.otf"),
                            style: .normal, weight: .standard(.bold)
                        ),
                        CSSFontFace(
                            file: fontsDir.appendingPathComponent("OpenDyslexic-BoldItalic.otf"),
                            style: .italic, weight: .standard(.bold)
                        ),
                    ]
                ).eraseToAnyHTMLFontFamilyDeclaration()
            )
        }

        self.publication = publication
        self.config = config
        editingActions = EditingActionsController(
            actions: config.editingActions,
            rights: publication.rights
        )
        self.httpServer = httpServer
        self.publicationEndpoint = publicationEndpoint
        self.publicationBaseURL = URL(string: publicationBaseURL.absoluteString.addingSuffix("/"))!
        self.assetsURL = assetsURL
        self.useLegacySettings = useLegacySettings
        legacyReadingProgression = publication.metadata.effectiveReadingProgression

        settings = EPUBSettings(
            preferences: config.preferences,
            defaults: config.defaults,
            metadata: publication.metadata
        )

        css = ReadiumCSS(
            layout: CSSLayout(),
            rsProperties: config.readiumCSSRSProperties,
            baseURL: assetsURL.appendingPathComponent("/readium-css/"),
            fontFamilyDeclarations: config.fontFamilyDeclarations
        )

        css.update(with: settings)
    }

    deinit {
        if let endpoint = publicationEndpoint {
            httpServer?.remove(at: endpoint)
        }
    }

    func url(to link: Link) -> URL? {
        link.url(relativeTo: publicationBaseURL)
    }

    private func serveFile(at file: URL, baseEndpoint: HTTPServerEndpoint) throws -> URL {
        if let url = servedFiles[file] {
            return url
        }

        guard let httpServer = httpServer else {
            throw Error.noHTTPServer
        }
        let endpoint = baseEndpoint.addingSuffix("/") + file.lastPathComponent
        let url = try httpServer.serve(at: endpoint, contentsOf: file)
        $servedFiles.write { $0[file] = url }
        return url
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

    // MARK: - User preferences

    private(set) var settings: EPUBSettings

    func submitPreferences(_ preferences: EPUBPreferences) {
        let oldSettings = settings
        let newSettings = EPUBSettings(
            preferences: preferences,
            defaults: config.defaults,
            metadata: publication.metadata
        )
        settings = newSettings
        updateSpread()
        updateCSS(with: settings)
        css.update(with: settings)

        let needsInvalidation: Bool =
            oldSettings.readingProgression != newSettings.readingProgression
                || oldSettings.language != newSettings.language
                || oldSettings.verticalText != newSettings.verticalText
                || oldSettings.scroll != newSettings.scroll
                || oldSettings.spread != newSettings.spread

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
        useLegacySettings
            ? (ReadingProgression(legacyReadingProgression) ?? .ltr)
            : settings.readingProgression
    }

    var legacyReadingProgression: R2Shared.ReadingProgression

    var theme: Theme {
        useLegacySettings ? legacyTheme : settings.theme
    }

    private var legacyTheme: Theme {
        guard
            let appearance = config.userSettings.userProperties.getProperty(reference: ReadiumCSSReference.appearance.rawValue) as? Enumerable,
            appearance.values.count > appearance.index
        else {
            return .light
        }
        let value = appearance.values[appearance.index]
        switch value {
        case "readium-night-on":
            return .dark
        case "readium-sepia-on":
            return .sepia
        default:
            return .light
        }
    }

    var scroll: Bool {
        // Force-enables scroll when VoiceOver is running, because pagination
        // breaks the screen reader.
        guard !UIAccessibility.isVoiceOverRunning else {
            return true
        }
        return useLegacySettings ? legacyScroll : settings.scroll
    }

    private var legacyScroll: Bool {
        (config.userSettings.userProperties.getProperty(reference: ReadiumCSSReference.scroll.rawValue) as? Switchable)?.on ?? false
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

    private var spread: Spread {
        useLegacySettings ? legacySpread : settings.spread
    }

    private var legacySpread: Spread {
        let columnCount = config.userSettings.userProperties.getProperty(reference: ReadiumCSSReference.columnCount.rawValue) as? Enumerable

        switch columnCount?.index {
        case 0:
            return .auto
        case 1:
            return .never
        case 2:
            return .always
        default:
            return Spread(publication.metadata.presentation.spread) ?? .auto
        }
    }

    // MARK: - Readium CSS

    private var css: ReadiumCSS

    private func serveFont(at file: URL) throws -> URL {
        try serveFile(at: file, baseEndpoint: "custom-fonts/\(UUID().uuidString)")
    }

    func injectReadiumCSS(in resource: Resource) -> Resource {
        let link = resource.link
        guard
            link.mediaType.isHTML,
            publication.metadata.presentation.layout(of: link) == .reflowable
        else {
            return resource
        }

        return resource.mapAsString { [self] content in
            do {
                var content = try css.inject(in: content)
                for ff in config.fontFamilyDeclarations {
                    content = try ff.inject(in: content, servingFile: serveFont)
                }
                return content
            } catch {
                log(.error, error)
                return content
            }
        }
    }

    private func updateCSS(with settings: EPUBSettings) {
        let previousCSS = css
        css.update(with: settings)

        var properties: [String: String?] = [:]
        let rsProperties = css.rsProperties.cssProperties()
        if previousCSS.rsProperties.cssProperties() != rsProperties {
            for (k, v) in rsProperties {
                properties[k] = v
            }
        }
        let userProperties = css.userProperties.cssProperties()
        if previousCSS.userProperties.cssProperties() != userProperties {
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
}
