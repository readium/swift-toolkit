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
    }
    
    var body: some View {
        VStack {
            Text(label)
                .font(.headline)
            HStack {
                Spacer()
                ForEach(values, id: \.self) { value in
                    Button(action: {
                        model.commit { presentation, _ in
                            presentation.toggle(setting, value: value)
                        }
                    }) {
                        Text(value.rawValue)
                            .if(setting.effectiveValue == value) {
                                $0.underline()
                            }
                    }
                    .buttonStyle(SettingButtonStyle(setting: setting, value: value))
                    .if(!setting.isSupported(value: value)) {
                        $0.opacity(0.4)
                    }
                }
                Spacer()
            }
        }
    }
}


struct SettingButtonStyle<Value: Hashable>: ButtonStyle {
    let setting: PresentationController.Setting<Value>
    let value: Value?
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .frame(minWidth: 50)
            .background(Color.gray.opacity(0.1))
            .foregroundColor(setting.value == value ? .accentColor : .primary)
            .cornerRadius(16)
            .scaleEffect(configuration.isPressed ? 0.9: 1)
            .animation(.spring())
    }
}
