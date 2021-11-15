//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import SwiftUI
import R2Navigator

struct SettingsView: View {
    
    @ObservedObject var model: SettingsViewModel
    
    var body: some View {
        List {
            Toggle(isOn: $model.autoActivateOnChange) {
                Text("Auto activate settings")
            }
            
            if let overflow = model.settings.overflow {
                EnumSettingView(
                    model: model,
                    label: "Overflow",
                    setting: overflow,
                    values: [.paginated, .scrolled]
                )
            }
            if let readingProgression = model.settings.readingProgression {
                EnumSettingView(
                    model: model,
                    label: "Reading Progression",
                    setting: readingProgression,
                    values: [.ltr, .rtl, .ttb, .btt]
                )
            }
            if let pageSpacing = model.settings.pageSpacing {
                RangeSettingView(
                    model: model,
                    label: "Page Spacing",
                    setting: pageSpacing
                )
            }
        }
    }
}

struct RangeSettingView: View {
    
    let model: SettingsViewModel
    let label: String
    let setting: PresentationController.RangeSetting
    
    var body: some View {
        VStack {
            Spacer()
            Text(label)
                .font(.headline)
            HStack {
                Spacer()
                
                button("minus") {
                    model.commit { presentation, _ in
                        presentation.decrement(setting)
                    }
                }
                
                Text(setting.label(for: setting.value ?? setting.effectiveValue) ?? "")
                    .frame(minWidth: 80)
                    .if(setting.value != nil) {
                        $0.foregroundColor(.accentColor)
                    }
                
                button("plus") {
                    model.commit { presentation, _ in
                        presentation.increment(setting)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private func button(_ imageName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: imageName)
        }
            .buttonStyle(.plain)
            .padding(8)
    }
}

struct EnumSettingView<E: RawRepresentable & Hashable>: View where E.RawValue == String {
    
    let model: SettingsViewModel
    let label: String
    let setting: PresentationController.EnumSetting<E>
    let values: [E]
    
    var body: some View {
        VStack {
            Spacer()
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
}
