//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import SwiftUI
import R2Navigator
import R2Shared

final class UserPreferencesViewModel<
    S: ConfigurableSettings,
    P: ConfigurablePreferences,
    E: PreferencesEditor
>: ObservableObject where E.Preferences == P {

    @Published private(set) var editor: E?

    private let bookId: Book.Id
    private let configurable: AnyConfigurable<S, P, E>
    private let store: AnyUserPreferencesStore<P>
    private var subscriptions = Set<AnyCancellable>()

    init<C: Configurable, ST: UserPreferencesStore>(
        bookId: Book.Id, configurable: C, store: ST
    ) where C.Settings == S, C.Preferences == P, C.Editor == E, ST.Preferences == P {
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
            if let editor = editor {
                try! await store.savePreferences(editor.preferences, of: bookId)
            }
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

    var body: some View {
        if let editor = model.editor {
            userPreferences(editor: editor, commit: model.commit)
        }
    }

    @ViewBuilder func userPreferences<E: PreferencesEditor>(editor: E, commit: @escaping () -> Void) -> some View {
        NavigationView {
            List {
                switch editor {
                case let editor as PDFPreferencesEditor:
                    fixedUserPreferences(
                        commit: commit,
                        offsetFirstPage: editor.offsetFirstPage,
                        pageSpacing: editor.pageSpacing,
                        readingProgression: editor.readingProgression,
                        scroll: editor.scroll,
                        scrollAxis: editor.scrollAxis,
                        spread: editor.spread,
                        visibleScrollbar: editor.visibleScrollbar
                    )

                default:
                    Group {}
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
    @ViewBuilder func fixedUserPreferences(
        commit: @escaping () -> Void,
        backgroundColor: AnyEnumPreference<R2Navigator.Color>? = nil,
        fit: AnyEnumPreference<R2Navigator.Fit>? = nil,
        language: AnyEnumPreference<Language?>? = nil,
        offsetFirstPage: AnyPreference<Bool>? = nil,
        pageSpacing: AnyRangePreference<Double>? = nil,
        readingProgression: AnyEnumPreference<R2Navigator.ReadingProgression>? = nil,
        scroll: AnyPreference<Bool>? = nil,
        scrollAxis: AnyEnumPreference<R2Navigator.Axis>? = nil,
        spread: AnyEnumPreference<R2Navigator.Spread>? = nil,
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
    @ViewBuilder func pickerRow<V: RawRepresentable & Hashable>(
        title: String,
        preference: AnyEnumPreference<V>,
        commit: @escaping () -> Void,
        formatValue: @escaping (V) -> String
    ) -> some View where V.RawValue: Hashable {
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
    @ViewBuilder func pickerRow<V: RawRepresentable & Hashable>(
        title: String,
        value: Binding<V>,
        values: [V],
        isActive: Bool,
        onClear: @escaping () -> Void,
        formatValue: @escaping (V) -> String
    ) -> some View where V.RawValue: Hashable {
        preferenceRow(
            isActive: isActive,
            onClear: onClear
        ) {
            Picker(title, selection: value) {
                ForEach(values, id: \.rawValue) {
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
                    onDecrement: onDecrement
                )

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
    }

    /// Component for a `Preference` holding a `Color` value.
    @ViewBuilder func colorRow(
        title: String,
        preference: AnyPreference<R2Navigator.Color>,
        commit: @escaping () -> Void
    ) -> some View {
        colorRow(
            title: title,
            value: Binding(
                get: { (preference.value ?? preference.effectiveValue).color },
                set: {
                    preference.set(R2Navigator.Color(color: $0))
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
                selection: value
            )
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
                .disabled(!isActive)
                .foregroundColor(isActive ? nil : .gray)

            Button(action: onClear) {
                Image(systemName: "delete.left")
            }
            .buttonStyle(.plain)
        }
    }
}
