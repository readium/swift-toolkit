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
        }
    }
}

struct SettingPicker<E: RawRepresentable & Hashable>: View where E.RawValue == String {
    
    let model: SettingsViewModel
    let label: String
    let setting: PresentationController.EnumSetting<E>
    let values: [E]
    private let wrappedValues: [Choice]
    
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
        self.wrappedValues = [.auto].appending(contentsOf: values.map { .value($0) })
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
            Picker(label,
                selection: Binding<Choice>(
                    get: { setting.value.map { .value($0) } ?? .auto },
                    set: { value in
                        model.commit { presentation, _ in
                            presentation.toggle(setting, value: value.value)
                        }
                    }
                )
            ) {
                ForEach(wrappedValues, id: \.self) {
                    if let value = $0.value {
                        Text(value.rawValue.capitalized)
                    } else {
                        Text("Auto").id($0)
                    }
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
}
