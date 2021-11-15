//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import SwiftUI
import R2Navigator

struct FixedSettingsView: View {
    
    @ObservedObject var model: SettingsViewModel
    
    var body: some View {
        List {
            if let overflow = model.settings.overflow {
                SettingPicker(
                    model: model,
                    label: "Overflow",
                    setting: overflow,
                    values: [.paginated, .scrolled]
                )
            }
            if let readingProgression = model.settings.readingProgression {
                SettingPicker(
                    model: model,
                    label: "Reading progression",
                    setting: readingProgression,
                    values: [.ltr, .rtl, .ttb, .btt]
                )
            }
        }
    }
}

struct SettingPicker<E: RawRepresentable & Hashable>: View where E.RawValue == String {
    
    let model: SettingsViewModel
    let label: String
    let setting: PresentationController.EnumSetting<E>
    let values: [E]
    private let choices: [Choice]
    
    init(
        model: SettingsViewModel,
        label: String,
        setting: PresentationController.EnumSetting<E>,
        values: [E]
    ) {
        self.model = model
        self.label = label
        self.setting = setting
        self.values = values
        self.choices = [.auto].appending(contentsOf: values
            .filter { setting.supportedValues?.contains($0) ?? true }
            .map { .value($0) }
        )
    }
    
    // The Binding used with the Picker doesn't seem to handle nil values, so we
    // wrap the value in an additional enum to represent the `auto` option.
    private enum Choice: Hashable {
        case auto
        case value(E)
        
        var value: E? {
            switch self {
            case .auto:
                return nil
            case .value(let value):
                return value
            }
        }
    }
    
    var body: some View {
        VStack {
            Text(label)
            HStack {
                ForEach(choices, id: \.self) { value in
                    Button(action: {
                        model.commit { presentation, _ in
                            presentation.toggle(setting, value: value.value)
                        }
                    }) {
                        if let value = value.value {
                            Text(value.rawValue.capitalized)
                        } else {
                            Text("Auto")
                        }
                    }.buttonStyle(SettingButtonStyle(setting: setting, value: value.value))
                }
            }
        }
    }
}


struct SettingButtonStyle<Value: Hashable>: ButtonStyle {
    let setting: PresentationController.Setting<Value>
    let value: Value?
    
    var isEnabled: Bool {
        guard let value = value else {
            return true
        }
        return setting.constraints?.validate(value: value) ?? true
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .scaleEffect(configuration.isPressed ? 0.95: 1)
            .foregroundColor(setting.value == value ? .red : .primary)
            .disabled(!isEnabled)
            .animation(.spring())
    }
}
