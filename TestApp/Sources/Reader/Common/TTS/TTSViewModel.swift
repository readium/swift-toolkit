//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Navigator
import R2Shared

final class TTSViewModel: ObservableObject, Loggable {

    @Published private(set) var state: TTSController.State = .stopped

    private let navigator: Navigator
    private let publication: Publication
    private var ttsController: TTSController!

    init?(navigator: Navigator, publication: Publication) {
        guard TTSController.canSpeak(publication) else {
            return nil
        }
        self.navigator = navigator
        self.publication = publication
        self.ttsController = TTSController(publication: publication, delegate: self)
    }

    @objc func start() {
        guard case .stopped = state else {
            return
        }

        navigator.findLocationOfFirstVisibleContent { [self] locator in
            ttsController.play(from: locator ?? navigator.currentLocation)
        }
    }
}

extension TTSViewModel: TTSControllerDelegate {

    func ttsController(_ ttsController: TTSController, stateDidChange state: TTSController.State) {
        self.state = state
    }

    func ttsController(_ ttsController: TTSController, didStartSpeaking utterance: TTSController.Utterance) {
        log(.warning, "START SPEAKING \(utterance.text)")
        navigator.go(to: utterance.locator)
        (navigator as? DecorableNavigator)?.apply(decorations: [
            Decoration(id: "tts", locator: utterance.locator, style: .highlight(tint: .red))
        ], in: "tts")
    }
}