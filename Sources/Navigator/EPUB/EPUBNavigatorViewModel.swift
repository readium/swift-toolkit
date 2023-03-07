//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

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

    private let publication: Publication
    private let config: EPUBNavigatorViewController.Configuration
    private let useLegacySettings: Bool
    weak var delegate: EPUBNavigatorViewModelDelegate?

    init(
        publication: Publication,
        config: EPUBNavigatorViewController.Configuration,
        assetsBaseURL: URL,
        useLegacySettings: Bool
    ) {
        self.publication = publication
        self.config = config
        self.useLegacySettings = useLegacySettings

        self.settings = EPUBSettings(
            preferences: config.preferences,
            defaults: config.defaults,
            metadata: publication.metadata
        )

        self.css = ReadiumCSS(
            layout: CSSLayout(),
            rsProperties: config.readiumCSSRSProperties,
            assetsBaseURL: assetsBaseURL
        )

        css.update(with: settings)
    }

    // MARK: - User preferences

    private(set) var settings: EPUBSettings
    private var css: ReadiumCSS

    func submitPreferences(_ preferences: EPUBPreferences) {
        let oldSettings = settings
        let newSettings = EPUBSettings(
            preferences: preferences,
            defaults: config.defaults,
            metadata: publication.metadata
        )
        settings = newSettings
        updateCSS(with: settings)
        css.update(with: settings)

        let needsInvalidation: Bool = (
            oldSettings.readingProgression != newSettings.readingProgression ||
            oldSettings.language != newSettings.language ||
            oldSettings.verticalText != newSettings.verticalText ||
            oldSettings.spread != newSettings.spread
        )

        if needsInvalidation {
            delegate?.epubNavigatorViewModelInvalidatePaginationView(self)
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

    func editor(of preferences: EPUBPreferences) -> EPUBPreferencesEditor {
        EPUBPreferencesEditor(
            initialPreferences: preferences,
            metadata: publication.metadata,
            defaults: config.defaults
        )
    }
}
