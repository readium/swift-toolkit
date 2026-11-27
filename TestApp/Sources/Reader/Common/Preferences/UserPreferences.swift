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

/// Edits the `UserSettings` of a book, saves them in the store and submits
/// their preferences to the navigator.
@MainActor
final class UserPreferencesViewModel<Settings: UserSettings>: ObservableObject {
    typealias Navigator = AnyConfigurable<Settings.NavigatorSettings, Settings.Preferences>

    @Published private(set) var settings: Settings

    let publication: Publication
    private let bookId: Book.Id
    private let navigator: Navigator
    private let store: UserSettingsStore<Settings>
    private var subscriptions = Set<AnyCancellable>()

    init(
        bookId: Book.Id,
        publication: Publication,
        navigator: Navigator,
        settings: Settings,
        store: UserSettingsStore<Settings>
    ) {
        self.bookId = bookId
        self.publication = publication
        self.navigator = navigator
        self.settings = settings
        self.store = store

        let settings = store.settingsPublisher(for: bookId)
            .receive(on: DispatchQueue.main)

        settings
            .sink { [weak self] settings in
                // The publisher delivers on the main queue.
                MainActor.assumeIsolated {
                    self?.settings = settings
                }
            }
            .store(in: &subscriptions)

        settings
            // First one is dropped to avoid refreshing the navigator when
            // opening the user preferences screen.
            .dropFirst()
            .sink { settings in
                MainActor.assumeIsolated {
                    navigator.submitPreferences(settings.preferences())
                }
            }
            .store(in: &subscriptions)
    }

    /// Settings the navigator applies with the current user settings, to
    /// tell which ones are applicable.
    var navigatorSettings: Settings.NavigatorSettings {
        navigator.settings(for: settings.preferences())
    }

    /// Returns a binding modifying one of the user settings.
    func binding<Value>(_ keyPath: WritableKeyPath<Settings, Value>) -> Binding<Value> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { value in self.update { $0[keyPath: keyPath] = value } }
        )
    }

    /// Modifies the user settings and saves them.
    func update(_ change: (inout Settings) -> Void) {
        var settings = settings
        change(&settings)
        guard settings != self.settings else {
            return
        }
        self.settings = settings

        Task {
            try! await store.saveSettings(settings, of: bookId)
        }
    }

    /// Clears every user setting.
    func reset() {
        update { $0 = .empty }
    }
}

struct UserPreferences<Settings: UserSettings>: View {
    @ObservedObject var model: UserPreferencesViewModel<Settings>
    var onClose: () -> Void

    var body: some View {
        NavigationView {
            List {
                switch model {
                case let model as UserPreferencesViewModel<EPUBUserSettings>:
                    if model.publication.metadata.layout == .fixed {
                        EPUBFixedLayoutPreferences(model: model)
                    } else {
                        EPUBReflowablePreferences(model: model)
                    }
                case let model as UserPreferencesViewModel<PDFUserSettings>:
                    PDFPreferencesForm(model: model)
                case let model as UserPreferencesViewModel<AudioUserSettings>:
                    AudioPreferencesForm(model: model)
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
                    Button("Reset", action: model.reset)
                }
            }
        }
    }
}

// MARK: - EPUB

/// User preferences of a publication with adjustable fonts and dimensions,
/// such as a reflowable EPUB or an HTML document.
private struct EPUBReflowablePreferences: View {
    @ObservedObject var model: UserPreferencesViewModel<EPUBUserSettings>

    var body: some View {
        // Resolved once per update, as it is used by every row.
        let settings = model.navigatorSettings

        Section {
            languageRow(
                value: model.binding(\.book.language),
                isActive: settings.isApplicable(\.language)
            )

            readingProgressionRow(
                value: model.binding(\.book.readingProgression).rawRepresentable(),
                placeholder: settings.readingProgression,
                isActive: settings.isApplicable(\.readingProgression)
            )

            toggleRow(
                "Vertical text",
                value: model.binding(\.book.verticalText),
                placeholder: settings.verticalText,
                isActive: settings.isApplicable(\.verticalText)
            )

            toggleRow(
                "Hide ruby annotations",
                value: model.binding(\.shared.noRuby),
                placeholder: settings.noRuby,
                isActive: settings.isApplicable(\.noRuby)
            )
        }

        Section {
            toggleRow(
                "Scroll",
                value: model.binding(\.shared.scroll),
                placeholder: settings.scroll,
                isActive: settings.isApplicable(\.scroll)
            )

            pickerRow(
                "Columns",
                value: model.binding(\.shared.columnCount),
                values: [nil, 1, 2],
                isActive: settings.isApplicable(\.columnCount),
                format: { $0.map { String($0) } ?? "Auto" }
            )

            stepperRow(
                "Page margins",
                value: model.binding(\.shared.pageMargins),
                spec: .pageMargins,
                placeholder: settings.pageMargins,
                isActive: settings.isApplicable(\.pageMargins)
            )

            stepperRow(
                "Optimal line length",
                subtitle: "Chooses the number of columns. Applied when paginated with automatic columns.",
                value: model.binding(\.shared.optimalLineLength),
                spec: .lineLength,
                placeholder: settings.optimalLineLength,
                isActive: settings.isApplicable(\.optimalLineLength)
            )

            optionalStepperRow(
                "Minimal line length",
                subtitle: "Removes columns when the lines would be shorter. Applied when paginated with a fix number of columns (2 or more).",
                value: model.binding(\.shared.minimalLineLength),
                spec: .lineLength,
                isActive: settings.isApplicable(\.minimalLineLength)
            )

            // No toggle: the default `EPUBDefaults.maximalLineLength` is not
            // `nil`, so disabling it would fall back on the default.
            stepperRow(
                "Maximal line length",
                subtitle: "Limits the length of the lines. Applied when scrolled and paginated.",
                value: model.binding(\.shared.maximalLineLength),
                spec: .lineLength,
                placeholder: settings.maximalLineLength,
                isActive: settings.isApplicable(\.maximalLineLength)
            )
        }

        Section {
            themeRow(
                value: model.binding(\.shared.theme),
                isActive: settings.isApplicable(\.textColor)
                    || settings.isApplicable(\.backgroundColor)
                    || settings.isApplicable(\.linkColor)
                    || settings.isApplicable(\.visitedColor)
            )

            toggleRow(
                "Blend images",
                value: model.binding(\.shared.blendImages),
                placeholder: settings.blendImages,
                isActive: settings.isApplicable(\.blendImages)
            )

            stepperRow(
                "Darken images",
                value: model.binding(\.shared.darkenImages),
                spec: .darkenImages,
                placeholder: settings.darkenImages,
                isActive: settings.isApplicable(\.darkenImages)
            )

            toggleRow(
                "Invert images",
                value: model.binding(\.shared.invertImages),
                placeholder: settings.invertImages,
                isActive: settings.isApplicable(\.invertImages)
            )

            toggleRow(
                "Invert gaiji",
                value: model.binding(\.shared.invertGaiji),
                placeholder: settings.invertGaiji,
                isActive: settings.isApplicable(\.invertGaiji)
            )

            colorRow(
                "Text color",
                value: model.binding(\.shared.theme).color(\.textColor),
                placeholder: .startingText,
                isActive: settings.isApplicable(\.textColor)
            )

            colorRow(
                "Background color",
                value: model.binding(\.shared.theme).color(\.backgroundColor),
                placeholder: .startingBackground,
                isActive: settings.isApplicable(\.backgroundColor)
            )

            colorRow(
                "Link color",
                value: model.binding(\.shared.theme).color(\.linkColor),
                placeholder: .startingLink,
                isActive: settings.isApplicable(\.linkColor)
            )

            colorRow(
                "Visited link color",
                value: model.binding(\.shared.theme).color(\.visitedColor),
                placeholder: .startingVisited,
                isActive: settings.isApplicable(\.visitedColor)
            )
        }

        Section {
            pickerRow(
                "Typeface",
                value: model.binding(\.shared.fontFamily).rawRepresentable(),
                values: [nil, .sansSerif, .literata] as [FontFamily?],
                isActive: settings.isApplicable(\.fontFamily),
                format: { ff in
                    switch ff {
                    case nil: return "Original"
                    case .sansSerif: return "Sans serif"
                    case let ff?: return ff.rawValue
                    }
                }
            )

            stepperRow(
                "Font size",
                value: model.binding(\.shared.fontSize),
                spec: .fontSize,
                placeholder: settings.fontSize,
                isActive: settings.isApplicable(\.fontSize)
            )

            stepperRow(
                "Font weight",
                value: model.binding(\.shared.fontWeight),
                spec: .fontWeight,
                placeholder: settings.fontWeight,
                isActive: settings.isApplicable(\.fontWeight)
            )

            stepperRow(
                "Font width",
                value: model.binding(\.shared.fontWidth),
                spec: .fontWidth,
                placeholder: settings.fontWidth,
                isActive: settings.isApplicable(\.fontWidth)
            )

            toggleRow(
                "Text normalization",
                value: model.binding(\.shared.textNormalization),
                placeholder: settings.textNormalization,
                isActive: settings.isApplicable(\.textNormalization)
            )
        }

        Section {
            pickerRow(
                "Text alignment",
                value: model.binding(\.shared.textAlign).rawRepresentable(),
                values: [nil, .start, .left, .right, .justify] as [ReadiumNavigator.TextAlignment?],
                isActive: settings.isApplicable(\.textAlign),
                format: { v in
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

            stepperRow(
                "Line height",
                value: model.binding(\.shared.lineHeight),
                spec: .lineHeight,
                placeholder: settings.lineHeight,
                isActive: settings.isApplicable(\.lineHeight)
            )

            stepperRow(
                "Paragraph indent",
                value: model.binding(\.shared.paragraphIndent),
                spec: .paragraphIndent,
                placeholder: settings.paragraphIndent,
                isActive: settings.isApplicable(\.paragraphIndent)
            )

            stepperRow(
                "Paragraph spacing",
                value: model.binding(\.shared.paragraphSpacing),
                spec: .paragraphSpacing,
                placeholder: settings.paragraphSpacing,
                isActive: settings.isApplicable(\.paragraphSpacing)
            )

            stepperRow(
                "Word spacing",
                value: model.binding(\.shared.wordSpacing),
                spec: .wordSpacing,
                placeholder: settings.wordSpacing,
                isActive: settings.isApplicable(\.wordSpacing)
            )

            stepperRow(
                "Letter spacing",
                value: model.binding(\.shared.letterSpacing),
                spec: .letterSpacing,
                placeholder: settings.letterSpacing,
                isActive: settings.isApplicable(\.letterSpacing)
            )

            toggleRow(
                "Hyphens",
                value: model.binding(\.shared.hyphens),
                // Readium CSS hyphenates the justified text.
                placeholder: settings.hyphens ?? (settings.textAlign == .justify),
                isActive: settings.isApplicable(\.hyphens)
            )

            toggleRow(
                "Ligatures",
                value: model.binding(\.shared.ligatures),
                placeholder: settings.ligatures ?? true,
                isActive: settings.isApplicable(\.ligatures)
            )
        }
    }
}

/// User preferences of a fixed-layout EPUB.
private struct EPUBFixedLayoutPreferences: View {
    @ObservedObject var model: UserPreferencesViewModel<EPUBUserSettings>

    var body: some View {
        let settings = model.navigatorSettings

        Section {
            languageRow(
                value: model.binding(\.book.language),
                isActive: settings.isApplicable(\.language)
            )

            readingProgressionRow(
                value: model.binding(\.book.readingProgression).rawRepresentable(),
                placeholder: settings.readingProgression,
                isActive: settings.isApplicable(\.readingProgression)
            )
        }

        Section {
            colorRow(
                "Background color",
                value: model.binding(\.shared.theme).color(\.backgroundColor),
                placeholder: .startingBackground,
                isActive: settings.isApplicable(\.backgroundColor)
            )
        }

        Section {
            spreadRow(
                value: model.binding(\.book.spread).rawRepresentable(),
                placeholder: settings.spread,
                isActive: settings.isApplicable(\.spread)
            )

            pickerRow(
                "Offset first page",
                value: model.binding(\.book.offsetFirstPage),
                values: [nil, true, false],
                isActive: settings.isApplicable(\.offsetFirstPage),
                format: { v in
                    switch v {
                    case nil: return "Auto"
                    case true?: return "Yes"
                    case false?: return "No"
                    }
                }
            )
        }

        Section {
            fitRow(
                value: model.binding(\.shared.fit).rawRepresentable(),
                placeholder: settings.fit,
                isActive: settings.isApplicable(\.fit)
            )
        }
    }
}

// MARK: - PDF

private struct PDFPreferencesForm: View {
    @ObservedObject var model: UserPreferencesViewModel<PDFUserSettings>

    var body: some View {
        let settings = model.navigatorSettings

        Section {
            readingProgressionRow(
                value: model.binding(\.book.readingProgression).rawRepresentable(),
                placeholder: settings.readingProgression,
                isActive: settings.isApplicable(\.readingProgression)
            )
        }

        Section {
            toggleRow(
                "Scroll",
                value: model.binding(\.shared.scroll),
                placeholder: settings.scroll,
                isActive: settings.isApplicable(\.scroll)
            )

            pickerRow(
                "Scroll axis",
                value: model.binding(\.shared.scrollAxis).rawRepresentable().or(settings.scrollAxis),
                values: [.horizontal, .vertical],
                isActive: settings.isApplicable(\.scrollAxis),
                onClear: { model.update { $0.shared.scrollAxis = nil } },
                format: { v in
                    switch v {
                    case .horizontal: return "Horizontal"
                    case .vertical: return "Vertical"
                    }
                }
            )

            toggleRow(
                "Visible scrollbar",
                value: model.binding(\.shared.visibleScrollbar),
                placeholder: settings.visibleScrollbar,
                isActive: settings.isApplicable(\.visibleScrollbar)
            )
        }

        Section {
            spreadRow(
                value: model.binding(\.shared.spread).rawRepresentable(),
                placeholder: settings.spread,
                isActive: settings.isApplicable(\.spread)
            )

            toggleRow(
                "Offset first page",
                value: model.binding(\.book.offsetFirstPage),
                placeholder: settings.offsetFirstPage,
                isActive: settings.isApplicable(\.offsetFirstPage)
            )
        }

        Section {
            fitRow(
                value: model.binding(\.shared.fit).rawRepresentable(),
                placeholder: settings.fit,
                isActive: settings.isApplicable(\.fit)
            )
        }

        Section {
            stepperRow(
                "Page spacing",
                value: model.binding(\.shared.pageSpacing),
                spec: .pageSpacing,
                placeholder: settings.pageSpacing,
                isActive: settings.isApplicable(\.pageSpacing)
            )
        }
    }
}

// MARK: - Audio

/// User preferences of an audiobook.
private struct AudioPreferencesForm: View {
    @ObservedObject var model: UserPreferencesViewModel<AudioUserSettings>

    var body: some View {
        let settings = model.navigatorSettings

        Section {
            stepperRow(
                "Volume",
                value: model.binding(\.shared.volume),
                spec: .volume,
                placeholder: settings.volume,
                isActive: settings.isApplicable(\.volume)
            )

            stepperRow(
                "Speed",
                value: model.binding(\.shared.speed),
                spec: .speed,
                placeholder: settings.speed,
                isActive: settings.isApplicable(\.speed)
            )
        }
    }
}

// MARK: - Rows

/// Range, step and starting value of a numeric preference offered by the
/// Test App, as suggested in the documentation of the `Preferences`
/// properties.
struct StepperSpec {
    let range: ClosedRange<Double>
    let step: Double
    /// Value displayed and stepped from when the preference is unset and the
    /// navigator settings have no value.
    let start: Double
    var format: (Double) -> String = { $0.formatted(.percent.precision(.fractionLength(0))) }

    func increment(_ value: Double) -> Double {
        adjusted(value + step)
    }

    func decrement(_ value: Double) -> Double {
        adjusted(value - step)
    }

    /// Removes the residue of the floating-point additions, and keeps the
    /// value in the range.
    private func adjusted(_ value: Double) -> Double {
        min(max((value * 100_000).rounded() / 100_000, range.lowerBound), range.upperBound)
    }

    private static let decimal: (Double) -> String = { $0.formatted(.number.precision(.fractionLength(0 ... 5))) }

    static let darkenImages = StepperSpec(range: 0.0 ... 1.0, step: 0.1, start: 0.0)
    static let fontSize = StepperSpec(range: 0.1 ... 5.0, step: 0.1, start: 1.0)
    static let fontWeight = StepperSpec(range: 0.0 ... 2.5, step: 0.25, start: 1.0)
    static let fontWidth = StepperSpec(range: 0.5 ... 2.5, step: 0.1, start: 1.0)
    static let lineHeight = StepperSpec(range: 1.0 ... 2.0, step: 0.1, start: 1.5, format: decimal)
    static let lineLength = StepperSpec(range: 0.5 ... 2.0, step: 0.1, start: 1.0)
    static let pageMargins = StepperSpec(range: 0.0 ... 4.0, step: 0.3, start: 1.0, format: decimal)
    static let paragraphIndent = StepperSpec(range: 0.0 ... 3.0, step: 0.2, start: 0.0)
    static let paragraphSpacing = StepperSpec(range: 0.0 ... 2.0, step: 0.1, start: 0.0)
    static let wordSpacing = StepperSpec(range: 0.0 ... 1.0, step: 0.1, start: 0.0)
    static let letterSpacing = StepperSpec(range: 0.0 ... 0.5, step: 0.05, start: 0.0)

    static let pageSpacing = StepperSpec(range: 0 ... 200, step: 4, start: 0, format: { String(format: "%.1f pt", $0) })

    static let volume = StepperSpec(range: 0.0 ... 1.0, step: 0.1, start: 1.0)
    static let speed = StepperSpec(range: 0.1 ... 6.0, step: 0.1, start: 1.0)
}

/// Colors a color picker starts from when the color is unset, as the actual
/// color then comes from the publication.
private extension ReadiumNavigator.Color {
    static let startingText = ReadiumNavigator.Color(rawValue: 0x121212)
    static let startingBackground = ReadiumNavigator.Color(rawValue: 0xFFFFFF)
    static let startingLink = ReadiumNavigator.Color(rawValue: 0x0000EE)
    static let startingVisited = ReadiumNavigator.Color(rawValue: 0x551A8B)
}

private let languages: [Language?] = [nil] + Language.all
    .map(\.primaryLanguage)
    .removingDuplicates()
    .sorted { l1, l2 in l1.localizedDescription() <= l2.localizedDescription() }

/// Layout for a preference row, greyed out when the preference doesn't
/// apply, with a button to clear its value.
private func preferenceRow<V: View>(
    isActive: Bool,
    subtitle: String? = nil,
    onClear: @escaping () -> Void,
    @ViewBuilder content: () -> V
) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 8) {
            content()
                .foregroundColor(isActive ? nil : .gray)

            Button(action: onClear) {
                Image(systemName: "delete.left")
            }
            .buttonStyle(.plain)
        }

        if let subtitle {
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// Row for a boolean preference switchable with a `Toggle`.
///
/// - Parameter placeholder: Value displayed when the preference is unset.
private func toggleRow(
    _ title: String,
    value: Binding<Bool?>,
    placeholder: Bool,
    isActive: Bool
) -> some View {
    preferenceRow(isActive: isActive, onClear: { value.wrappedValue = nil }) {
        Toggle(title, isOn: value.or(placeholder))
    }
}

/// Row for a preference picked among `values`.
private func pickerRow<V: Hashable>(
    _ title: String,
    value: Binding<V>,
    values: [V],
    isActive: Bool,
    onClear: @escaping () -> Void,
    format: @escaping (V) -> String
) -> some View {
    preferenceRow(isActive: isActive, onClear: onClear) {
        Picker(title, selection: value) {
            ForEach(values, id: \.self) {
                Text(format($0)).tag($0)
            }
        }
    }
}

/// Row for a preference picked among `values`, where `nil` is one of the
/// values (e.g. "Auto").
private func pickerRow<V: Hashable>(
    _ title: String,
    value: Binding<V?>,
    values: [V?],
    isActive: Bool,
    format: @escaping (V?) -> String
) -> some View {
    pickerRow(
        title,
        value: value,
        values: values,
        isActive: isActive,
        onClear: { value.wrappedValue = nil },
        format: format
    )
}

private func readingProgressionRow(
    value: Binding<ReadiumNavigator.ReadingProgression?>,
    placeholder: ReadiumNavigator.ReadingProgression,
    isActive: Bool
) -> some View {
    pickerRow(
        "Reading progression",
        value: value.or(placeholder),
        values: [.ltr, .rtl],
        isActive: isActive,
        onClear: { value.wrappedValue = nil },
        format: { v in
            switch v {
            case .ltr: return "LTR"
            case .rtl: return "RTL"
            }
        }
    )
}

private func spreadRow(
    value: Binding<Spread?>,
    placeholder: Spread,
    isActive: Bool
) -> some View {
    pickerRow(
        "Spread",
        value: value.or(placeholder),
        values: [.auto, .never, .always],
        isActive: isActive,
        onClear: { value.wrappedValue = nil },
        format: { v in
            switch v {
            case .auto: return "Auto"
            case .never: return "Never"
            case .always: return "Always"
            }
        }
    )
}

private func fitRow(
    value: Binding<Fit?>,
    placeholder: Fit,
    isActive: Bool
) -> some View {
    pickerRow(
        "Fit",
        value: value.or(placeholder),
        values: [.auto, .page, .width],
        isActive: isActive,
        onClear: { value.wrappedValue = nil },
        format: { v in
            switch v {
            case .auto: return "Auto"
            case .page: return "Page"
            case .width: return "Width"
            }
        }
    )
}

/// Row for the language of the publication, stored as a BCP 47 tag.
private func languageRow(value: Binding<String?>, isActive: Bool) -> some View {
    pickerRow(
        "Language",
        value: Binding(
            get: { value.wrappedValue.map { Language($0) } },
            set: { value.wrappedValue = $0?.tag }
        ),
        values: languages,
        isActive: isActive,
        format: { $0?.localizedDescription() ?? "Original" }
    )
}

/// Row for a numeric preference modified with a `Stepper`.
///
/// - Parameter placeholder: Value displayed and stepped from when the
///   preference is unset, `spec.start` by default.
private func stepperRow(
    _ title: String,
    subtitle: String? = nil,
    value: Binding<Double?>,
    spec: StepperSpec,
    placeholder: Double? = nil,
    isActive: Bool
) -> some View {
    let current = value.wrappedValue ?? placeholder ?? spec.start

    return preferenceRow(
        isActive: isActive,
        subtitle: subtitle,
        onClear: { value.wrappedValue = nil }
    ) {
        HStack(spacing: 4) {
            Stepper(
                title,
                onIncrement: { value.wrappedValue = spec.increment(current) },
                onDecrement: { value.wrappedValue = spec.decrement(current) }
            )

            stepperValue(spec.format(current))
        }
    }
}

/// Row for an optional numeric preference, with a `Toggle` to enable it and
/// a `Stepper` to modify its value.
private func optionalStepperRow(
    _ title: String,
    subtitle: String? = nil,
    value: Binding<Double?>,
    spec: StepperSpec,
    isActive: Bool
) -> some View {
    let current = value.wrappedValue

    return preferenceRow(
        isActive: isActive,
        subtitle: subtitle,
        onClear: { value.wrappedValue = nil }
    ) {
        HStack(spacing: 4) {
            // Wraps instead of truncating next to the toggle and stepper.
            Text(title)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Toggle(title, isOn: Binding(
                get: { current != nil },
                set: { value.wrappedValue = $0 ? spec.start : nil }
            ))
            .labelsHidden()

            Stepper(
                title,
                onIncrement: { value.wrappedValue = spec.increment(current ?? spec.start) },
                onDecrement: { value.wrappedValue = spec.decrement(current ?? spec.start) }
            )
            .labelsHidden()
            .disabled(current == nil)

            stepperValue(spec.format(current ?? spec.start))
                .foregroundColor(current == nil ? .gray : nil)
        }
    }
}

/// Value displayed next to a `Stepper`, with a minimum width so that the
/// controls don't move when the value changes.
private func stepperValue(_ value: String) -> some View {
    Text(value)
        .font(.caption)
        .monospacedDigit()
        .frame(minWidth: 40, alignment: .trailing)
}

/// Row selecting the `Theme`, which sets the color preferences together.
///
/// "Custom" is offered only when the colors were edited one by one.
private func themeRow(value: Binding<EPUBUserSettings.Theme>, isActive: Bool) -> some View {
    var themes: [EPUBUserSettings.Theme] = [.publisher, .sepia, .dark]
    if case .custom = value.wrappedValue {
        themes.append(value.wrappedValue)
    }

    return pickerRow(
        "Theme",
        value: value,
        values: themes,
        isActive: isActive,
        onClear: { value.wrappedValue = .publisher },
        format: { $0.readerTheme.name }
    )
}

/// Row for a color preference.
///
/// - Parameter placeholder: Color the picker starts from when the preference
///   is unset.
private func colorRow(
    _ title: String,
    value: Binding<ReadiumNavigator.Color?>,
    placeholder: ReadiumNavigator.Color,
    isActive: Bool
) -> some View {
    preferenceRow(isActive: isActive, onClear: { value.wrappedValue = nil }) {
        ColorPicker(
            title,
            selection: Binding(
                get: { (value.wrappedValue ?? placeholder).color },
                set: { value.wrappedValue = ReadiumNavigator.Color(color: $0) }
            ),
            supportsOpacity: false
        )
    }
}

private extension Binding {
    /// Reads `placeholder` when the optional value is `nil`.
    func or<Wrapped>(_ placeholder: Wrapped) -> Binding<Wrapped> where Value == Wrapped? {
        Binding<Wrapped>(
            get: { wrappedValue ?? placeholder },
            set: { wrappedValue = $0 }
        )
    }

    /// Converts an optional raw value, as stored in the `UserSettings`.
    func rawRepresentable<R: RawRepresentable>() -> Binding<R?> where Value == R.RawValue? {
        Binding<R?>(
            get: { wrappedValue.flatMap { R(rawValue: $0) } },
            set: { wrappedValue = $0?.rawValue }
        )
    }
}

private extension Binding where Value == EPUBUserSettings.Theme {
    /// Binding to one of the colors of the theme. Changing a color switches
    /// to a custom theme.
    func color(_ keyPath: WritableKeyPath<ReaderTheme, ReadiumNavigator.Color?>) -> Binding<ReadiumNavigator.Color?> {
        Binding<ReadiumNavigator.Color?>(
            get: { wrappedValue.readerTheme[keyPath: keyPath] },
            set: { color in
                var colors = wrappedValue.readerTheme
                colors[keyPath: keyPath] = color
                let text = colors.textColor?.rawValue
                let background = colors.backgroundColor?.rawValue
                let link = colors.linkColor?.rawValue
                let visited = colors.visitedColor?.rawValue
                if text == nil, background == nil, link == nil, visited == nil {
                    wrappedValue = .publisher
                } else {
                    wrappedValue = .custom(text: text, background: background, link: link, visited: visited)
                }
            }
        )
    }
}

/// A theme offered by the Test App.
///
/// The Readium toolkit has no themes: a theme is only a set of color
/// preferences applied together. `nil` keeps the color of the publication.
nonisolated struct ReaderTheme: Hashable {
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
}
