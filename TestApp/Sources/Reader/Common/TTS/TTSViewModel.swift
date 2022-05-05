//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import R2Navigator
import R2Shared

final class TTSViewModel: ObservableObject, Loggable {

    @Published private(set) var state: TTSController.State = .stopped

    @Published var config: TTSController.Configuration = TTSController.Configuration()

    private let navigator: Navigator
    private let publication: Publication
    private var ttsController: TTSController!
    private var subscriptions: Set<AnyCancellable> = []

    init?(navigator: Navigator, publication: Publication) {
        guard TTSController.canSpeak(publication) else {
            return nil
        }
        self.navigator = navigator
        self.publication = publication
        self.ttsController = TTSController(publication: publication, config: config, delegate: self)

        $config
            .sink { [unowned self] in
                ttsController.config = $0
            }
            .store(in: &subscriptions)
    }

    @objc func play() {
        guard state == .stopped else {
            return
        }

        navigator.findLocationOfFirstVisibleContent { [self] locator in
            ttsController.play(from: locator ?? navigator.currentLocation)
        }
    }

    @objc func playPause() {
        ttsController.playPause()
    }

    @objc func stop() {
        ttsController.stop()
    }

    private func highlight(_ utterance: TTSController.Utterance?) {
        guard let navigator = navigator as? DecorableNavigator else {
            return
        }

        var decorations: [Decoration] = []
        if let utterance = utterance {
            decorations.append(Decoration(
                id: "tts",
                locator: utterance.locator,
                style: .highlight(tint: .red)
            ))
        }

        navigator.apply(decorations: decorations, in: "tts")
    }
}

extension TTSViewModel: TTSControllerDelegate {

    func ttsController(_ ttsController: TTSController, stateDidChange state: TTSController.State) {
        self.state = state

        if state == .stopped {
            highlight(nil)
        }
    }

    func ttsController(_ ttsController: TTSController, didStartSpeaking utterance: TTSController.Utterance) {
        navigator.go(to: utterance.locator)
        highlight(utterance)
    }
}