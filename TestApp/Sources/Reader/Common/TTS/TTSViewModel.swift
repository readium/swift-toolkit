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

    enum State {
        case stopped, paused, playing
    }

    @Published private(set) var state: State = .stopped
    @Published var config: TTSConfiguration

    private let tts: TTSController
    private let navigator: Navigator
    private let publication: Publication

    private let playingRangeLocatorSubject = PassthroughSubject<Locator, Never>()
    private var subscriptions: Set<AnyCancellable> = []

    init?(navigator: Navigator, publication: Publication) {
        guard TTSController.canPlay(publication) else {
            return nil
        }
        self.tts = TTSController(publication: publication)
        self.config = tts.config
        self.navigator = navigator
        self.publication = publication

        tts.delegate = self

        $config
            .sink { [unowned self] in
                tts.config = $0
            }
            .store(in: &subscriptions)

        var isMoving = false
        playingRangeLocatorSubject
            .throttle(for: 1, scheduler: RunLoop.main, latest: true)
            .sink { locator in
                guard !isMoving else {
                    return
                }
                isMoving = navigator.go(to: locator) {
                    isMoving = false
                }
            }
            .store(in: &subscriptions)
    }

    var defaultConfig: TTSConfiguration { tts.defaultConfig }

    var availableVoices: [TTSVoice?] {
        [nil] + tts.availableVoices
            .filter { $0.language.removingRegion() == config.defaultLanguage }
    }

    lazy var availableLanguages: [Language] =
        tts.availableVoices
            .map { $0.language.removingRegion() }
            .removingDuplicates()
            .sorted { $0.localizedDescription() < $1.localizedDescription() }

    @objc func play() {
        navigator.findLocationOfFirstVisibleContent { [self] locator in
            tts.play(from: locator ?? navigator.currentLocation)
        }
    }

    @objc func playPause() {
        tts.playPause()
    }

    @objc func stop() {
        state = .stopped
        highlight(nil)
        tts.pause()
    }

    @objc func previous() {
        tts.previous()
    }

    @objc func next() {
        tts.next()
    }

    private func highlight(_ utterance: TTSUtterance?) {
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
    public func ttsController(_ ttsController: TTSController, playingDidChange isPlaying: Bool) {
        if isPlaying {
            state = .playing
        } else if state != .stopped {
            state = .paused
        }
    }

    public func ttsController(_ ttsController: TTSController, didReceiveError error: Error) {
        log(.error, error)
    }

    public func ttsController(_ ttsController: TTSController, willStartSpeaking utterance: TTSUtterance) {
        highlight(utterance)
    }

    public func ttsController(_ ttsController: TTSController, willSpeakRangeAt locator: Locator, of utterance: TTSUtterance) {
        playingRangeLocatorSubject.send(locator)
    }
}
