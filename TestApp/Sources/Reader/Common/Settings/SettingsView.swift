//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import SwiftUI
import R2Navigator

struct SettingsView: View {
    
    @ObservedObject var settings: PresentationSettings
    @State var autoCommit = true
    
    var body: some View {
        List {
            HStack {
                button("Reset") {
                    settings.reset()
                    if (autoCommit) {
                        settings.commit()
                    }
                }
                
                button("Commit") {
                    settings.commit()
                }
            }
                
            Toggle(isOn: $settings.autoActivateOnChange) {
                Text("Auto activate settings")
            }
            
            Toggle(isOn: $autoCommit) {
                Text("Auto commit changes")
            }
            
            if let overflow = settings.overflow {
                EnumSettingView(
                    label: "Overflow",
                    settings: settings,
                    setting: overflow,
                    values: [.paginated, .scrolled],
                    autoCommit: $autoCommit
                )
            }
            if let readingProgression = settings.readingProgression {
                EnumSettingView(
                    label: "Reading Progression",
                    settings: settings,
                    setting: readingProgression,
                    values: [.ltr, .rtl, .ttb, .btt],
                    autoCommit: $autoCommit
                )
            }
            if let spread = settings.spread {
                EnumSettingView(
                    label: "Spread",
                    settings: settings,
                    setting: spread,
                    values: [.none, .both, .landscape],
                    autoCommit: $autoCommit
                )
            }
            if let pageSpacing = settings.pageSpacing {
                RangeSettingView(
                    label: "Page Spacing",
                    settings: settings,
                    setting: pageSpacing,
                    autoCommit: $autoCommit
                )
            }
        }
    }
    
    private func button(_ label: String, action: @escaping () -> Void) -> some View {
        Button(
            action: action,
            label: { Text(label) }
        ).buttonStyle(.borderless)
    }
}

struct RangeSettingView: View {
    
    let label: String
    let settings: PresentationSettings
    let setting: PresentationSettings.RangeSetting
    @Binding var autoCommit: Bool
    
    var body: some View {
        VStack {
            Spacer()
            Text(label)
                .font(.headline)
            HStack {
                Spacer()
                
                button("minus") {
                    settings.decrement(setting)
                    if (autoCommit) { settings.commit() }
                }
                
                Text(setting.label(for: setting.value ?? setting.effectiveValue) ?? "")
                    .frame(minWidth: 80)
                    .if(setting.value != nil) {
                        $0.foregroundColor(.accentColor)
                    }
                
                button("plus") {
                    settings.increment(setting)
                    if (autoCommit) { settings.commit() }
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
    
    let label: String
    let settings: PresentationSettings
    let setting: PresentationSettings.EnumSetting<E>
    let values: [E]
    @Binding var autoCommit: Bool
    
    var body: some View {
        VStack {
            Spacer()
            Text(label)
                .font(.headline)
            HStack {
                Spacer()
                ForEach(values, id: \.self) { value in
                    Button(action: {
                        settings.toggle(setting, value: value)
                        if (autoCommit) { settings.commit() }
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
        let setting: PresentationSettings.Setting<Value>
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
