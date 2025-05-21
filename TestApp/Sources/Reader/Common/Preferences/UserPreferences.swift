//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import ReadiumNavigator
import ReadiumShared
import SwiftUI

final class UserPreferencesViewModel<
    S: ConfigurableSettings,
    P: ConfigurablePreferences,
    E: PreferencesEditor
>: ObservableObject where E.Preferences == P {
    @Published private(set) var editor: E

    private let bookId: Book.Id
    private let configurable: AnyConfigurable<S, P, E>
    private let store: AnyUserPreferencesStore<P>
    private var subscriptions = Set<AnyCancellable>()

    init<C: Configurable, ST: UserPreferencesStore>(
        bookId: Book.Id,
        preferences: P,
        configurable: C,
        store: ST
    ) where C.Settings == S, C.Preferences == P, C.Editor == E, ST.Preferences == P {
        editor = configurable.editor(of: preferences)
        self.bookId = bookId
        self.configurable = configurable.eraseToAnyConfigurable()
        self.store = store.eraseToAnyPreferencesStore()

        let preferences = store.preferencesPublisher(for: bookId)
            .receive(on: DispatchQueue.main)

        preferences
            .compactMap { configurable.editor(of: $0) }
            .assign(to: &$editor)

        preferences
            // First one is dropped to avoid refreshing the navigator when
            // opening the user preferences screen.
            .dropFirst()
            .sink { configurable.submitPreferences($0) }
            .store(in: &subscriptions)
    }

    func commit() {
        Task {
            try! await store.savePreferences(editor.preferences, of: bookId)
        }
    }
}

struct UserPreferences<
    S: ConfigurableSettings,
    P: ConfigurablePreferences,
    E: PreferencesEditor
>: View where E.Preferences == P {
    @ObservedObject var model: UserPreferencesViewModel<S, P, E>
    var onClose: () -> Void

    private let languages: [Language?] = [nil] + Language.all
        .map { $0.removingRegion() }
        .removingDuplicates()
        .sorted { l1, l2 in l1.localizedDescription() <= l2.localizedDescription() }

    var body: some View {
        userPreferences(editor: model.editor, commit: model.commit)
    }

    @ViewBuilder func userPreferences<PE: PreferencesEditor>(editor: PE, commit: @escaping () -> Void) -> some View {
        NavigationView {
            List {
                switch editor {
                case let editor as PDFPreferencesEditor:
                    fixedLayoutUserPreferences(
                        commit: commit,
                        offsetFirstPage: editor.offsetFirstPage,
                        pageSpacing: editor.pageSpacing,
                        readingProgression: editor.readingProgression,
                        scroll: editor.scroll,
                        scrollAxis: editor.scrollAxis,
                        spread: editor.spread,
                        visibleScrollbar: editor.visibleScrollbar
                    )

                case let editor as EPUBPreferencesEditor:
                    switch editor.layout {
                    case .reflowable:
                        reflowableUserPreferences(
                            commit: commit,
                            backgroundColor: editor.backgroundColor,
                            columnCount: editor.columnCount,
                            fontFamily: editor.fontFamily,
                            fontSize: editor.fontSize,
                            fontWeight: editor.fontWeight,
                            hyphens: editor.hyphens,
                            imageFilter: editor.imageFilter,
                            language: editor.language,
                            letterSpacing: editor.letterSpacing,
                            ligatures: editor.ligatures,
                            lineHeight: editor.lineHeight,
                            pageMargins: editor.pageMargins,
                            paragraphIndent: editor.paragraphIndent,
                            paragraphSpacing: editor.paragraphSpacing,
                            publisherStyles: editor.publisherStyles,
                            readingProgression: editor.readingProgression,
                            scroll: editor.scroll,
                            textAlign: editor.textAlign,
                            textColor: editor.textColor,
                            textNormalization: editor.textNormalization,
                            theme: editor.theme,
                            typeScale: editor.typeScale,
                            verticalText: editor.verticalText,
                            wordSpacing: editor.wordSpacing
                        )
                    case .fixed:
                        fixedLayoutUserPreferences(
                            commit: commit,
                            backgroundColor: editor.backgroundColor,
                            language: editor.language,
                            readingProgression: editor.readingProgression,
                            spread: editor.spread
                        )
                    }

                case let editor as AudioPreferencesEditor:
                    audioUserPreferences(
                        commit: commit,
                        volume: editor.volume,
                        speed: editor.speed
                    )

                default:
                    Text("No user preferences available.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("User Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }

                ToolbarItemGroup(placement: .destructiveAction) {
                    Button("Reset") {
                        editor.clear()
                        commit()
                    }
                }
            }
        }
    }

    private func button(_ label: String, action: @escaping () -> Void) -> some View {
        Button(
            action: action,
            label: { Text(label) }
        ).buttonStyle(.borderless)
    }

    /// User preferences screen for a publication with a fixed layout, such as
    /// fixed-layout EPUB, PDF or comic book.
    @ViewBuilder func fixedLayoutUserPreferences(
        commit: @escaping () -> Void,
        backgroundColor: AnyPreference<ReadiumNavigator.Color>? = nil,
        fit: AnyEnumPreference<ReadiumNavigator.Fit>? = nil,
        language: AnyPreference<Language?>? = nil,
        offsetFirstPage: AnyPreference<Bool>? = nil,
        pageSpacing: AnyRangePreference<Double>? = nil,
        readingProgression: AnyEnumPreference<ReadiumNavigator.ReadingProgression>? = nil,
        scroll: AnyPreference<Bool>? = nil,
        scrollAxis: AnyEnumPreference<ReadiumNavigator.Axis>? = nil,
        spread: AnyEnumPreference<ReadiumNavigator.Spread>? = nil,
        visibleScrollbar: AnyPreference<Bool>? = nil
    ) -> some View {
        if language != nil || readingProgression != nil {
            Section {
                if let language = language {
                    languageRow(
                        title: "Language",
                        preference: language,
                        commit: commit
                    )
                }

                if let readingProgression = readingProgression {
                    pickerRow(
                        title: "Reading progression",
                        preference: readingProgression,
                        commit: commit,
                        formatValue: { v in
                            switch v {
                            case .ltr: return "LTR"
                            case .rtl: return "RTL"
                            }
                        }
                    )
                }
            }
        }

        if let backgroundColor = backgroundColor {
            Section {
                colorRow(
                    title: "Background color",
                    preference: backgroundColor,
                    commit: commit
                )
            }
        }

        if let scroll = scroll {
            Section {
                toggleRow(
                    title: "Scroll",
                    preference: scroll,
                    commit: commit
                )

                if let scrollAxis = scrollAxis {
                    pickerRow(
                        title: "Scroll axis",
                        preference: scrollAxis,
                        commit: commit,
                        formatValue: { v in
                            switch v {
                            case .horizontal: return "Horizontal"
                            case .vertical: return "Vertical"
                            }
                        }
                    )
                }
            }
        }

        if let spread = spread {
            Section {
                pickerRow(
                    title: "Spread",
                    preference: spread,
                    commit: commit,
                    formatValue: { v in
                        switch v {
                        case .auto: return "Auto"
                        case .never: return "Never"
                        case .always: return "Always"
                        }
                    }
                )
            }

            if let offsetFirstPage = offsetFirstPage {
                toggleRow(
                    title: "Offset first page",
                    preference: offsetFirstPage,
                    commit: commit
                )
            }
        }

        if let fit = fit {
            Section {
                pickerRow(
                    title: "Fit",
                    preference: fit,
                    commit: commit,
                    formatValue: { v in
                        switch v {
                        case .cover: return "Cover"
                        case .contain: return "Contain"
                        case .width: return "Width"
                        case .height: return "Height"
                        }
                    }
                )
            }
        }

        if let pageSpacing = pageSpacing {
            Section {
                stepperRow(
                    title: "Page spacing",
                    preference: pageSpacing,
                    commit: commit
                )
            }
        }
    }

    /// User settings for a publication with adjustable fonts and dimensions,
    /// such as a reflowable EPUB, HTML document or PDF with reflow mode
    /// enabled.
    @ViewBuilder func reflowableUserPreferences(
        commit: @escaping () -> Void,
        backgroundColor: AnyPreference<ReadiumNavigator.Color>? = nil,
        columnCount: AnyEnumPreference<ColumnCount>? = nil,
        fontFamily: AnyPreference<FontFamily?>? = nil,
        fontSize: AnyRangePreference<Double>? = nil,
        fontWeight: AnyRangePreference<Double>? = nil,
        hyphens: AnyPreference<Bool>? = nil,
        imageFilter: AnyEnumPreference<ImageFilter?>? = nil,
        language: AnyPreference<Language?>? = nil,
        letterSpacing: AnyRangePreference<Double>? = nil,
        ligatures: AnyPreference<Bool>? = nil,
        lineHeight: AnyRangePreference<Double>? = nil,
        pageMargins: AnyRangePreference<Double>? = nil,
        paragraphIndent: AnyRangePreference<Double>? = nil,
        paragraphSpacing: AnyRangePreference<Double>? = nil,
        publisherStyles: AnyPreference<Bool>? = nil,
        readingProgression: AnyEnumPreference<ReadiumNavigator.ReadingProgression>? = nil,
        scroll: AnyPreference<Bool>? = nil,
        textAlign: AnyEnumPreference<ReadiumNavigator.TextAlignment?>? = nil,
        textColor: AnyPreference<ReadiumNavigator.Color>? = nil,
        textNormalization: AnyPreference<Bool>? = nil,
        theme: AnyEnumPreference<Theme>? = nil,
        typeScale: AnyRangePreference<Double>? = nil,
        verticalText: AnyPreference<Bool>? = nil,
        wordSpacing: AnyRangePreference<Double>? = nil
    ) -> some View {
        if language != nil || readingProgression != nil || verticalText != nil {
            Section {
                if let language = language {
                    languageRow(
                        title: "Language",
                        preference: language,
                        commit: commit
                    )
                }

                if let readingProgression = readingProgression {
                    pickerRow(
                        title: "Reading progression",
                        preference: readingProgression,
                        commit: commit,
                        formatValue: { v in
                            switch v {
                            case .ltr: return "LTR"
                            case .rtl: return "RTL"
                            }
                        }
                    )
                }

                if let verticalText = verticalText {
                    toggleRow(
                        title: "Vertical text",
                        preference: verticalText,
                        commit: commit
                    )
                }
            }
        }

        if scroll != nil || columnCount != nil || pageMargins != nil {
            Section {
                if let scroll = scroll {
                    toggleRow(
                        title: "Scroll",
                        preference: scroll,
                        commit: commit
                    )
                }

                if let columnCount = columnCount {
                    pickerRow(
                        title: "Columns",
                        preference: columnCount,
                        commit: commit,
                        formatValue: { v in
                            switch v {
                            case .auto: return "Auto"
                            case .one: return "1"
                            case .two: return "2"
                            }
                        }
                    )
                }

                if let pageMargins = pageMargins {
                    stepperRow(
                        title: "Page margins",
                        preference: pageMargins,
                        commit: commit
                    )
                }
            }
        }

        if theme != nil || imageFilter != nil || textColor != nil || backgroundColor != nil {
            Section {
                if let theme = theme {
                    pickerRow(
                        title: "Theme",
                        preference: theme,
                        commit: commit,
                        formatValue: { v in
                            switch v {
                            case .light: return "Light"
                            case .dark: return "Dark"
                            case .sepia: return "Sepia"
                            }
                        }
                    )
                }

                if let imageFilter = imageFilter {
                    pickerRow(
                        title: "Image filter",
                        preference: imageFilter,
                        commit: commit,
                        formatValue: { v in
                            switch v {
                            case nil: return "None"
                            case .darken: return "Darken colors"
                            case .invert: return "Invert colors"
                            }
                        }
                    )
                }

                if let textColor = textColor {
                    colorRow(
                        title: "Text color",
                        preference: textColor,
                        commit: commit
                    )
                }

                if let backgroundColor = backgroundColor {
                    colorRow(
                        title: "Background color",
                        preference: backgroundColor,
                        commit: commit
                    )
                }
            }
        }

        if fontFamily != nil || fontSize != nil || fontWeight != nil || textNormalization != nil {
            Section {
                if let fontFamily = fontFamily {
                    pickerRow(
                        title: "Typeface",
                        preference: fontFamily
                            .with(supportedValues: [
                                nil,
                                .sansSerif,
                                .iaWriterDuospace,
                                .accessibleDfA,
                                .openDyslexic,
                                .literata,
                            ])
                            .eraseToAnyPreference(),
                        commit: commit,
                        formatValue: { ff in
                            if let ff = ff {
                                switch ff {
                                case .sansSerif: return "Sans serif"
                                default: return ff.rawValue
                                }
                            } else {
                                return "Original"
                            }
                        }
                    )
                }

                if let fontSize = fontSize {
                    stepperRow(
                        title: "Font size",
                        preference: fontSize,
                        commit: commit
                    )
                }

                if let fontWeight = fontWeight {
                    stepperRow(
                        title: "Font weight",
                        preference: fontWeight,
                        commit: commit
                    )
                }

                if let textNormalization = textNormalization {
                    toggleRow(
                        title: "Text normalization",
                        preference: textNormalization,
                        commit: commit
                    )
                }
            }
        }

        if let publisherStyles = publisherStyles {
            Section {
                toggleRow(
                    title: "Publisher styles",
                    preference: publisherStyles,
                    commit: commit
                )

                // The following settings all require the publisher styles to
                // be disabled for EPUB. To simplify the interface, they are
                // hidden when the publisher styles are on.
                if !publisherStyles.effectiveValue {
                    if let textAlign = textAlign {
                        pickerRow(
                            title: "Text alignment",
                            preference: textAlign,
                            commit: commit,
                            formatValue: { v in
                                switch v {
                                case nil: return "Default"
                                case .center: return "Center"
                                case .left: return "Left"
                                case .right: return "Right"
                                case .justify: return "Justify"
                                case .start: return "Start"
                                case .end: return "End"
                                }
                            }
                        )
                    }

                    if let typeScale = typeScale {
                        stepperRow(
                            title: "Type scale",
                            preference: typeScale,
                            commit: commit
                        )
                    }

                    if let lineHeight = lineHeight {
                        stepperRow(
                            title: "Line height",
                            preference: lineHeight,
                            commit: commit
                        )
                    }

                    if let paragraphIndent = paragraphIndent {
                        stepperRow(
                            title: "Paragraph indent",
                            preference: paragraphIndent,
                            commit: commit
                        )
                    }

                    if let paragraphSpacing = paragraphSpacing {
                        stepperRow(
                            title: "Paragraph spacing",
                            preference: paragraphSpacing,
                            commit: commit
                        )
                    }

                    if let wordSpacing = wordSpacing {
                        stepperRow(
                            title: "Word spacing",
                            preference: wordSpacing,
                            commit: commit
                        )
                    }

                    if let letterSpacing = letterSpacing {
                        stepperRow(
                            title: "Letter spacing",
                            preference: letterSpacing,
                            commit: commit
                        )
                    }

                    if let hyphens = hyphens {
                        toggleRow(
                            title: "Hyphens",
                            preference: hyphens,
                            commit: commit
                        )
                    }

                    if let ligatures = ligatures {
                        toggleRow(
                            title: "Ligatures",
                            preference: ligatures,
                            commit: commit
                        )
                    }
                }
            }
        }
    }

    /// User preferences screen for an audiobook.
    @ViewBuilder func audioUserPreferences(
        commit: @escaping () -> Void,
        volume: AnyRangePreference<Double>? = nil,
        speed: AnyRangePreference<Double>? = nil
    ) -> some View {
        Section {
            if let volume = volume {
                stepperRow(
                    title: "Volume",
                    preference: volume,
                    commit: commit
                )
            }

            if let speed = speed {
                stepperRow(
                    title: "Speed",
                    preference: speed,
                    commit: commit
                )
            }
        }
    }

    /// Component for a boolean `Preference` switchable with a `Toggle` button.
    @ViewBuilder func toggleRow(
        title: String,
        preference: AnyPreference<Bool>,
        commit: @escaping () -> Void
    ) -> some View {
        toggleRow(
            title: title,
            value: preference.binding(onSet: commit),
            isActive: preference.isEffective,
            onClear: { preference.clear(); commit() }
        )
    }

    /// Component for a boolean `Preference` switchable with a `Toggle` button.
    @ViewBuilder func toggleRow(
        title: String,
        value: Binding<Bool>,
        isActive: Bool,
        onClear: @escaping () -> Void
    ) -> some View {
        preferenceRow(
            isActive: isActive,
            onClear: onClear
        ) {
            Toggle(title, isOn: value)
        }
    }

    /// Component for an `EnumPreference` displayed in a `Picker` view.
    @ViewBuilder func pickerRow<V: Hashable>(
        title: String,
        preference: AnyEnumPreference<V>,
        commit: @escaping () -> Void,
        formatValue: @escaping (V) -> String
    ) -> some View {
        pickerRow(
            title: title,
            value: preference.binding(onSet: commit),
            values: preference.supportedValues,
            isActive: preference.isEffective,
            onClear: { preference.clear(); commit() },
            formatValue: formatValue
        )
    }

    /// Component for an `EnumPreference` displayed in a `Picker` view.
    @ViewBuilder func pickerRow<V: Hashable>(
        title: String,
        value: Binding<V>,
        values: [V],
        isActive: Bool,
        onClear: @escaping () -> Void,
        formatValue: @escaping (V) -> String
    ) -> some View {
        preferenceRow(
            isActive: isActive,
            onClear: onClear
        ) {
            Picker(title, selection: value) {
                ForEach(values, id: \.self) {
                    Text(formatValue($0)).tag($0)
                }
            }
        }
    }

    /// Component for a `RangePreference` modifiable by a `Stepper` view.
    @ViewBuilder func stepperRow<V: Comparable>(
        title: String,
        preference: AnyRangePreference<V>,
        commit: @escaping () -> Void
    ) -> some View {
        stepperRow(
            title: title,
            value: preference.format(value: preference.value ?? preference.effectiveValue),
            isActive: preference.isEffective,
            onIncrement: { preference.increment(); commit() },
            onDecrement: { preference.decrement(); commit() },
            onClear: { preference.clear(); commit() }
        )
    }

    /// Component for a `RangePreference` modifiable by a `Stepper` view.
    @ViewBuilder func stepperRow(
        title: String,
        value: String,
        isActive: Bool,
        onIncrement: @escaping () -> Void,
        onDecrement: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        preferenceRow(
            isActive: isActive,
            onClear: onClear
        ) {
            HStack {
                Stepper(title,
                        onIncrement: onIncrement,
                        onDecrement: onDecrement)

                Text(value)
                    .font(.caption)
            }
        }
    }

    /// Component for a `Preference` holding a `Language` value.
    @ViewBuilder func languageRow(
        title: String,
        preference: AnyPreference<Language?>,
        commit: @escaping () -> Void
    ) -> some View {
        pickerRow(
            title: title,
            value: Binding(
                get: { preference.value ?? preference.effectiveValue },
                set: { preference.set($0); commit() }
            ),
            values: languages,
            isActive: preference.isEffective,
            onClear: { preference.clear(); commit() },
            formatValue: { language in
                language?.localizedDescription() ?? "Original"
            }
        )
    }

    /// Component for a `Preference` holding a `Color` value.
    @ViewBuilder func colorRow(
        title: String,
        preference: AnyPreference<ReadiumNavigator.Color>,
        commit: @escaping () -> Void
    ) -> some View {
        colorRow(
            title: title,
            value: Binding(
                get: { (preference.value ?? preference.effectiveValue).color },
                set: {
                    preference.set(ReadiumNavigator.Color(color: $0))
                    commit()
                }
            ),
            isActive: preference.isEffective,
            onClear: { preference.clear(); commit() }
        )
    }

    /// Component for a `Preference` holding a `Color` value.
    @ViewBuilder func colorRow(
        title: String,
        value: Binding<SwiftUI.Color>,
        isActive: Bool,
        onClear: @escaping () -> Void
    ) -> some View {
        preferenceRow(
            isActive: isActive,
            onClear: onClear
        ) {
            ColorPicker(title,
                        selection: value,
                        supportsOpacity: false)
        }
    }

    /// Layout for a preference row.
    @ViewBuilder func preferenceRow<V: View>(
        isActive: Bool,
        onClear: @escaping () -> Void,
        content: @escaping () -> V
    ) -> some View {
        HStack {
            content()
                .foregroundColor(isActive ? nil : .gray)

            Button(action: onClear) {
                Image(systemName: "delete.left")
            }
            .buttonStyle(.plain)
        }
    }
}

extension Preference {
    /// Creates a SwiftUI binding to modify the preference's value.
    ///
    /// This is convenient when paired with a `Toggle` or `Picker`.
    func binding(onSet: @escaping () -> Void = {}) -> Binding<Value> {
        Binding(
            get: { value ?? effectiveValue },
            set: { set($0); onSet() }
        )
    }
}
