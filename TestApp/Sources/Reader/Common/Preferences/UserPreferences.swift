//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import ReadiumNavigator
import ReadiumShared
import SwiftUI

@MainActor
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
            .sink { [weak self] prefs in
                // The publisher delivers on the main queue.
                MainActor.assumeIsolated {
                    self?.editor = configurable.editor(of: prefs)
                }
            }
            .store(in: &subscriptions)

        preferences
            // First one is dropped to avoid refreshing the navigator when
            // opening the user preferences screen.
            .dropFirst()
            .sink { prefs in
                MainActor.assumeIsolated {
                    configurable.submitPreferences(prefs)
                }
            }
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

    func userPreferences<PE: PreferencesEditor>(editor: PE, commit: @escaping () -> Void) -> some View {
        NavigationView {
            List {
                switch editor {
                case let editor as PDFPreferencesEditor:
                    fixedLayoutUserPreferences(
                        commit: commit,
                        fit: editor.fit,
                        offsetFirstPage: editor.offsetFirstPage,
                        pageSpacing: editor.pageSpacing,
                        readingProgression: editor.readingProgression,
                        scroll: editor.scroll,
                        scrollAxis: editor.scrollAxis,
                        spread: editor.spread,
                        visibleScrollbar: editor.visibleScrollbar
                    )

                case let editor as EPUBPreferencesEditor:
                    switch editor.defaultLayout {
                    case .reflowable:
                        reflowableUserPreferences(
                            commit: commit,
                            backgroundColor: editor.backgroundColor,
                            columnCount: editor.columnCount,
                            fontFamily: editor.fontFamily,
                            fontSize: editor.fontSize,
                            fontWeight: editor.fontWeight,
                            hyphens: editor.hyphens,
                            blendImages: editor.blendImages,
                            darkenImages: editor.darkenImages,
                            invertImages: editor.invertImages,
                            invertGaiji: editor.invertGaiji,
                            language: editor.language,
                            letterSpacing: editor.letterSpacing,
                            ligatures: editor.ligatures,
                            lineHeight: editor.lineHeight,
                            linkColor: editor.linkColor,
                            maximalLineLength: editor.maximalLineLength,
                            minimalLineLength: editor.minimalLineLength,
                            noRuby: editor.noRuby,
                            optimalLineLength: editor.optimalLineLength,
                            pageMargins: editor.pageMargins,
                            paragraphIndent: editor.paragraphIndent,
                            paragraphSpacing: editor.paragraphSpacing,
                            readingProgression: editor.readingProgression,
                            scroll: editor.scroll,
                            textAlign: editor.textAlign,
                            textColor: editor.textColor,
                            textNormalization: editor.textNormalization,
                            verticalText: editor.verticalText,
                            visitedColor: editor.visitedColor,
                            wordSpacing: editor.wordSpacing
                        )
                    case .fixed:
                        fixedLayoutUserPreferences(
                            commit: commit,
                            backgroundColor: editor.backgroundColor,
                            fit: editor.fit,
                            language: editor.language,
                            nullableOffsetFirstPage: editor.offsetFirstPage,
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
        nullableOffsetFirstPage: AnyPreference<Bool?>? = nil,
        pageSpacing: AnyRangePreference<Double>? = nil,
        readingProgression: AnyEnumPreference<ReadiumNavigator.ReadingProgression>? = nil,
        scroll: AnyPreference<Bool>? = nil,
        scrollAxis: AnyEnumPreference<ReadiumNavigator.Axis>? = nil,
        spread: AnyEnumPreference<ReadiumNavigator.Spread>? = nil,
        visibleScrollbar: AnyPreference<Bool>? = nil
    ) -> some View {
        NonEmptySection {
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

                if let offsetFirstPage = offsetFirstPage {
                    toggleRow(
                        title: "Offset first page",
                        preference: offsetFirstPage,
                        commit: commit
                    )
                }

                if let nullableOffsetFirstPage = nullableOffsetFirstPage {
                    nullableBoolPickerRow(
                        title: "Offset first page",
                        preference: nullableOffsetFirstPage,
                        commit: commit
                    )
                }
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
                        case .auto: return "Auto"
                        case .page: return "Page"
                        case .width: return "Width"
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
        columnCount: AnyEnumPreference<Int?>? = nil,
        fontFamily: AnyPreference<FontFamily?>? = nil,
        fontSize: AnyRangePreference<Double>? = nil,
        fontWeight: AnyRangePreference<Double>? = nil,
        hyphens: AnyPreference<Bool>? = nil,
        blendImages: AnyPreference<Bool>? = nil,
        darkenImages: AnyRangePreference<Double>? = nil,
        invertImages: AnyPreference<Bool>? = nil,
        invertGaiji: AnyPreference<Bool>? = nil,
        language: AnyPreference<Language?>? = nil,
        letterSpacing: AnyRangePreference<Double>? = nil,
        ligatures: AnyPreference<Bool>? = nil,
        lineHeight: AnyRangePreference<Double>? = nil,
        linkColor: AnyPreference<ReadiumNavigator.Color>? = nil,
        maximalLineLength: AnyOptionalRangePreference<Double>? = nil,
        minimalLineLength: AnyOptionalRangePreference<Double>? = nil,
        noRuby: AnyPreference<Bool>? = nil,
        optimalLineLength: AnyRangePreference<Double>? = nil,
        pageMargins: AnyRangePreference<Double>? = nil,
        paragraphIndent: AnyRangePreference<Double>? = nil,
        paragraphSpacing: AnyRangePreference<Double>? = nil,
        readingProgression: AnyEnumPreference<ReadiumNavigator.ReadingProgression>? = nil,
        scroll: AnyPreference<Bool>? = nil,
        textAlign: AnyEnumPreference<ReadiumNavigator.TextAlignment?>? = nil,
        textColor: AnyPreference<ReadiumNavigator.Color>? = nil,
        textNormalization: AnyPreference<Bool>? = nil,
        verticalText: AnyPreference<Bool>? = nil,
        visitedColor: AnyPreference<ReadiumNavigator.Color>? = nil,
        wordSpacing: AnyRangePreference<Double>? = nil
    ) -> some View {
        NonEmptySection {
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

            if let noRuby = noRuby {
                toggleRow(
                    title: "Hide ruby annotations",
                    preference: noRuby,
                    commit: commit
                )
            }
        }

        NonEmptySection {
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
                        v.map { String($0) } ?? "Auto"
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

            if let optimalLineLength = optimalLineLength {
                stepperRow(
                    title: "Optimal line length",
                    preference: optimalLineLength,
                    commit: commit
                )
            }

            if let minimalLineLength = minimalLineLength {
                optionalStepperRow(
                    title: "Minimal line length",
                    preference: minimalLineLength,
                    commit: commit
                )
            }

            if let maximalLineLength = maximalLineLength {
                optionalStepperRow(
                    title: "Maximal line length",
                    preference: maximalLineLength,
                    commit: commit
                )
            }
        }

        NonEmptySection {
            if
                let textColor = textColor,
                let backgroundColor = backgroundColor,
                let linkColor = linkColor,
                let visitedColor = visitedColor
            {
                themeRow(
                    title: "Theme",
                    textColor: textColor,
                    backgroundColor: backgroundColor,
                    linkColor: linkColor,
                    visitedColor: visitedColor,
                    commit: commit
                )
            }

            if let blendImages = blendImages {
                toggleRow(
                    title: "Blend Images",
                    preference: blendImages,
                    commit: commit
                )
            }

            if let darkenImages = darkenImages {
                stepperRow(
                    title: "Darken Images",
                    preference: darkenImages,
                    commit: commit
                )
            }

            if let invertImages = invertImages {
                toggleRow(
                    title: "Invert Images",
                    preference: invertImages,
                    commit: commit
                )
            }

            if let invertGaiji = invertGaiji {
                toggleRow(
                    title: "Invert Gaiji",
                    preference: invertGaiji,
                    commit: commit
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

            if let linkColor = linkColor {
                colorRow(
                    title: "Link color",
                    preference: linkColor,
                    commit: commit
                )
            }

            if let visitedColor = visitedColor {
                colorRow(
                    title: "Visited link color",
                    preference: visitedColor,
                    commit: commit
                )
            }
        }

        NonEmptySection {
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

        NonEmptySection {
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

    /// User preferences screen for an audiobook.
    func audioUserPreferences(
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
    func toggleRow(
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
    func toggleRow(
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

    /// Component for a nullable boolean `Preference` displayed in a `Picker` view
    /// with three options: Auto, Yes, No.
    func nullableBoolPickerRow(
        title: String,
        preference: AnyPreference<Bool?>,
        commit: @escaping () -> Void
    ) -> some View {
        preferenceRow(
            isActive: preference.isEffective,
            onClear: { preference.clear(); commit() }
        ) {
            Picker(title, selection: Binding(
                get: { preference.value ?? preference.effectiveValue },
                set: { preference.set($0); commit() }
            )) {
                Text("Auto").tag(nil as Bool?)
                Text("Yes").tag(true as Bool?)
                Text("No").tag(false as Bool?)
            }
        }
    }

    /// Component for an `EnumPreference` displayed in a `Picker` view.
    func pickerRow<V: Hashable>(
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
    func pickerRow<V: Hashable>(
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
    func stepperRow<V: Comparable>(
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
    func stepperRow(
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
            HStack(spacing: 4) {
                Stepper(title,
                        onIncrement: onIncrement,
                        onDecrement: onDecrement)

                stepperValue(value)
            }
        }
    }

    /// Value displayed next to a `Stepper`, with a minimum width so that the
    /// controls don't move when the value changes.
    func stepperValue(_ value: String) -> some View {
        Text(value)
            .font(.caption)
            .monospacedDigit()
            .frame(minWidth: 40, alignment: .trailing)
    }

    /// Component for an `OptionalRangePreference` with a `Toggle` to enable
    /// it, and a `Stepper` to modify its value.
    func optionalStepperRow<V: Comparable>(
        title: String,
        preference: AnyOptionalRangePreference<V>,
        commit: @escaping () -> Void
    ) -> some View {
        let value = preference.value ?? preference.effectiveValue

        return preferenceRow(
            isActive: preference.isEffective,
            onClear: { preference.clear(); commit() }
        ) {
            HStack(spacing: 4) {
                Text(title)

                Spacer()

                Toggle(title, isOn: Binding(
                    get: { value != nil },
                    set: { isEnabled in
                        preference.set(isEnabled ? preference.defaultValue : nil)
                        commit()
                    }
                ))
                .labelsHidden()

                Stepper(title,
                        onIncrement: { preference.increment(); commit() },
                        onDecrement: { preference.decrement(); commit() })
                    .labelsHidden()
                    .disabled(value == nil)

                stepperValue(preference.format(value: value ?? preference.defaultValue))
                    .foregroundColor(value == nil ? .gray : nil)
            }
        }
    }

    /// Component for a `Preference` holding a `Language` value.
    func languageRow(
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

    /// Component to select a `ReaderTheme`, which sets the color preferences
    /// together.
    ///
    /// The selected theme is not stored: it is the one matching the current
    /// color preferences, or "Custom" when there is none.
    func themeRow(
        title: String,
        textColor: AnyPreference<ReadiumNavigator.Color>,
        backgroundColor: AnyPreference<ReadiumNavigator.Color>,
        linkColor: AnyPreference<ReadiumNavigator.Color>,
        visitedColor: AnyPreference<ReadiumNavigator.Color>,
        commit: @escaping () -> Void
    ) -> some View {
        let apply: (ReaderTheme) -> Void = { theme in
            textColor.set(theme.textColor)
            backgroundColor.set(theme.backgroundColor)
            linkColor.set(theme.linkColor)
            visitedColor.set(theme.visitedColor)
            commit()
        }

        let selection = ReaderTheme.all.first { theme in
            textColor.value == theme.textColor
                && backgroundColor.value == theme.backgroundColor
                && linkColor.value == theme.linkColor
                && visitedColor.value == theme.visitedColor
        }

        // "Custom" is offered only when the colors match no theme.
        var themes: [ReaderTheme?] = ReaderTheme.all
        if selection == nil {
            themes.append(nil)
        }

        return pickerRow(
            title: title,
            value: Binding(
                get: { selection },
                set: { theme in
                    // `nil` is the "Custom" theme, which can't be selected.
                    if let theme = theme {
                        apply(theme)
                    }
                }
            ),
            values: themes,
            isActive: textColor.isEffective
                || backgroundColor.isEffective
                || linkColor.isEffective
                || visitedColor.isEffective,
            onClear: { apply(.light) },
            formatValue: { $0?.name ?? "Custom" }
        )
    }

    /// Component for a `Preference` holding a `Color` value.
    func colorRow(
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
    func colorRow(
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
    func preferenceRow<V: View>(
        isActive: Bool,
        onClear: @escaping () -> Void,
        content: @escaping () -> V
    ) -> some View {
        HStack(spacing: 8) {
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

/// A theme offered by the Test App.
///
/// The Readium toolkit has no themes: a theme is only a set of color
/// preferences applied together. `nil` keeps the color of the publication.
struct ReaderTheme: Hashable {
    typealias Color = ReadiumNavigator.Color

    var name: String
    var textColor: Color?
    var backgroundColor: Color?
    var linkColor: Color?
    var visitedColor: Color?

    static let light = ReaderTheme(name: "Light")

    static let sepia = ReaderTheme(
        name: "Sepia",
        textColor: Color(rawValue: 0x121212),
        backgroundColor: Color(rawValue: 0xFAF4E8)
    )

    static let dark = ReaderTheme(
        name: "Dark",
        textColor: Color(rawValue: 0xFEFEFE),
        backgroundColor: Color(rawValue: 0x000000),
        linkColor: Color(rawValue: 0x63CAFF),
        visitedColor: Color(rawValue: 0x0099E5)
    )

    static let all: [ReaderTheme] = [.light, .sepia, .dark]
}

/// A `Section` which is not rendered when its content is empty, for example
/// when none of its optional preference rows are available.
struct NonEmptySection<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Group(subviews: content) { subviews in
            if !subviews.isEmpty {
                Section { subviews }
            }
        }
    }
}
