//
//  Copyright 2021 Readium Foundation. All rights reserved.
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
                        minHeight: 150, idealHeight: 150, maxHeight: nil,
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
        List {
            Section(header: Text("Speech settings")) {
                ConfigStepper(
                    caption: "Rate",
                    for: \.rate,
                    step: viewModel.defaultRate / 10
                )

                ConfigStepper(
                    caption: "Pitch",
                    for: \.pitch,
                    step: viewModel.defaultPitch / 4
                )
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder func ConfigStepper(
        caption: String,
        for keyPath: WritableKeyPath<TTSController.Configuration, Double>,
        step: Double
    ) -> some View {
        Stepper(
            value: Binding(
                get: { viewModel.config[keyPath: keyPath] },
                set: { viewModel.config[keyPath: keyPath] = $0 }
            ),
            in: 0.0...1.0,
            step: step
        ) {
            Text(caption)
            Text(String.localizedPercentage(viewModel.config[keyPath: keyPath])).font(.footnote)
        }
    }
}
