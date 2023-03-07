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

final class EPUBNavigatorViewModel {

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

    func editor(of preferences: EPUBPreferences) -> EPUBPreferencesEditor {
        EPUBPreferencesEditor(
            initialPreferences: preferences,
            metadata: publication.metadata,
            defaults: config.defaults
        )
    }
}
