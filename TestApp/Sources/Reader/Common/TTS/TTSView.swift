//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Navigator
import SwiftUI

struct TTSControls: View {
    @ObservedObject var viewModel: TTSViewModel
    @State private var showSettings = false

    var body: some View {
        HStack(
            alignment: .center,
            spacing: 16
        ) {

            IconButton(
                systemName: "backward.fill",
                size: .small,
                action: { viewModel.previous() }
            )

            IconButton(
                systemName: (viewModel.state == .playing) ? "pause.fill" : "play.fill",
                action: { viewModel.playPause() }
            )

            IconButton(
                systemName: "stop.fill",
                action: { viewModel.stop() }
            )

            IconButton(
                systemName: "forward.fill",
                size: .small,
                action: { viewModel.next() }
            )

            Spacer(minLength: 0)

            IconButton(
                systemName: "gearshape.fill",
                size: .small,
                action: { showSettings.toggle() }
            )
            .popover(isPresented: $showSettings) {
                TTSSettings(viewModel: viewModel)
                    .frame(
                        minWidth: 320, idealWidth: 400, maxWidth: nil,
                        minHeight: 300, idealHeight: 300, maxHeight: nil,
                        alignment: .top
                    )
            }
        }
        .padding(16)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .opacity(0.8)
        .cornerRadius(16)
    }
}

struct TTSSettings: View {
    @ObservedObject var viewModel: TTSViewModel

    var body: some View {
        NavigationView {
            Form {
                stepper(
                    caption: "Rate",
                    for: \.rate,
                    step: viewModel.defaultConfig.rate / 10
                )

                stepper(
                    caption: "Pitch",
                    for: \.pitch,
                    step: viewModel.defaultConfig.pitch / 4
                )

                picker(
                    caption: "Language",
                    for: \.defaultLanguage,
                    choices: viewModel.availableLanguages,
                    choiceLabel: { $0.localizedDescription() }
                )

                picker(
                    caption: "Voice",
                    for: \.voice,
                    choices: viewModel.availableVoices,
                    choiceLabel: { $0.localizedDescription() }
                )
            }
            .navigationTitle("Speech settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder func stepper(
        caption: String,
        for keyPath: WritableKeyPath<TTSConfiguration, Double>,
        step: Double
    ) -> some View {
        Stepper(
            value: configBinding(for: keyPath),
            in: 0.0...1.0,
            step: step
        ) {
            Text(caption)
            Text(String.localizedPercentage(viewModel.config[keyPath: keyPath])).font(.footnote)
        }
    }

    @ViewBuilder func picker<T: Hashable>(
        caption: String,
        for keyPath: WritableKeyPath<TTSConfiguration, T>,
        choices: [T],
        choiceLabel: @escaping (T) -> String
    ) -> some View {
        Picker(caption, selection: configBinding(for: keyPath)) {
            ForEach(choices, id: \.self) {
                Text(choiceLabel($0))
            }
        }
    }
    
    private func configBinding<T>(for keyPath: WritableKeyPath<TTSConfiguration, T>) -> Binding<T> {
        Binding(
            get: { viewModel.config[keyPath: keyPath] },
            set: { viewModel.config[keyPath: keyPath] = $0 }
        )
    }
}

private extension Optional where Wrapped == TTSVoice {
    func localizedDescription() -> String {
        guard case let .some(voice) = self else {
            return "Default"
        }
        var desc = voice.name
        if let region = voice.language.localizedRegion() {
            desc += " (\(region))"
        }
        return desc
    }
}
