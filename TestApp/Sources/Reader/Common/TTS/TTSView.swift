//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumNavigator
import SwiftUI

private typealias Config = PublicationSpeechSynthesizer.Configuration

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
                systemName: (viewModel.state.isPlaying) ? "pause.fill" : "play.fill",
                action: { viewModel.pauseOrResume() }
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
                        minHeight: 400, idealHeight: 400, maxHeight: nil,
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
        let settings = viewModel.settings
        NavigationView {
            Form {
                picker(
                    caption: "Language",
                    for: \.defaultLanguage,
                    choices: settings.availableLanguages,
                    choiceLabel: { $0?.localizedDescription() ?? "Default" }
                )

                picker(
                    caption: "Voice",
                    for: \.voiceIdentifier,
                    choices: [nil] + settings.availableVoiceIds,
                    choiceLabel: { id in
                        id.flatMap { viewModel.voiceWithIdentifier($0)?.name } ?? "Default"
                    }
                )

                stepper(
                    for: \.speed,
                    range: 0.5 ... 3.5,
                    step: 0.25,
                    label: { "Speed: \($0.formatted())×" }
                )

                stepper(
                    for: \.pitch,
                    range: 0.5 ... 2.0,
                    step: 0.25,
                    label: { "Pitch: \($0.formatted())" }
                )
            }
            .navigationTitle("Speech settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    private func picker<T: Hashable>(
        caption: String,
        for keyPath: WritableKeyPath<Config, T>,
        choices: [T],
        choiceLabel: @escaping (T) -> String
    ) -> some View {
        Picker(caption, selection: configBinding(for: keyPath)) {
            ForEach(choices, id: \.self) {
                Text(choiceLabel($0))
            }
        }
    }

    private func stepper(
        for keyPath: WritableKeyPath<Config, Double>,
        range: ClosedRange<Double>,
        step: Double,
        label: @escaping (Double) -> String
    ) -> some View {
        let value = configBinding(for: keyPath)
        return Stepper(value: value, in: range, step: step) {
            Text(label(value.wrappedValue))
        }
    }

    private func configBinding<T>(for keyPath: WritableKeyPath<Config, T>) -> Binding<T> {
        Binding(
            get: { viewModel.settings.config[keyPath: keyPath] },
            set: {
                var config = viewModel.settings.config
                config[keyPath: keyPath] = $0
                viewModel.setConfig(config)
            }
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
