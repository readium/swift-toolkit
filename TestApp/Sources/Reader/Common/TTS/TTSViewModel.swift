//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import MediaPlayer
import ReadiumNavigator
import ReadiumShared

@MainActor
final class TTSViewModel: ObservableObject, Loggable {
    struct State: Equatable {
        /// Whether the TTS was enabled by the user.
        var showControls: Bool = false
        /// Whether the TTS is currently speaking.
        var isPlaying: Bool = false
    }

    struct Settings: Equatable {
        /// Currently selected user preferences.
        let config: PublicationSpeechSynthesizer.Configuration
        /// Languages supported by the synthesizer.
        let availableLanguages: [Language]
        /// Voices supported by the synthesizer, for the selected language.
        let availableVoiceIds: [String]

        @MainActor
        init(synthesizer: PublicationSpeechSynthesizer) {
            let voicesByLanguage: [Language: [TTSVoice]] =
                Dictionary(grouping: synthesizer.availableVoices, by: \.language)

            config = synthesizer.config
            availableLanguages = voicesByLanguage.keys.sorted { $0.localizedDescription() < $1.localizedDescription() }
            availableVoiceIds = synthesizer.config.defaultLanguage
                .flatMap { voicesByLanguage[$0]?.map(\.identifier) }
                ?? []
        }
    }

    @Published private(set) var state: State = .init()
    @Published private(set) var settings: Settings

    private let publication: Publication
    private let navigator: Navigator
    private let synthesizer: PublicationSpeechSynthesizer

    @Published private var playingUtteranceParts: [PublicationSpeechSynthesizer.Utterance.Part]?
    private let playingWordRangeSubject = PassthroughSubject<Locator, Never>()

    private var isMoving = false

    private var subscriptions: Set<AnyCancellable> = []

    init?(navigator: Navigator, publication: Publication) {
        guard let synthesizer = PublicationSpeechSynthesizer(publication: publication) else {
            return nil
        }
        self.synthesizer = synthesizer
        settings = Settings(synthesizer: synthesizer)
        self.navigator = navigator
        self.publication = publication

        synthesizer.delegate = self

        // Highlight the currently spoken utterance, with one decoration per
        // part: a fixed-layout sentence spanning several lines or pages keeps
        // a highlight on each of them.
        if let navigator = navigator as? DecorableNavigator {
            $playingUtteranceParts
                .removeDuplicates()
                .sink { parts in
                    let decorations: [Decoration] = (parts ?? []).enumerated()
                        .map { index, part in
                            Decoration(
                                id: "tts-utterance-\(index)",
                                locator: part.locator,
                                style: .highlight(tint: .red)
                            )
                        }
                    navigator.apply(decorations: decorations, in: "tts")
                }
                .store(in: &subscriptions)
        }

        // Navigate to the currently spoken utterance word.
        // This will automatically turn pages when needed.
        playingWordRangeSubject
            .removeDuplicates()
            //  Improve performances by throttling the moves to maximum one per second.
            .throttle(for: 1, scheduler: RunLoop.main, latest: true)
            .drop(while: { [weak self] _ in self?.isMoving ?? true })
            .sink { [weak self] locator in
                guard let self = self else {
                    return
                }

                isMoving = true
                Task {
                    await navigator.go(to: locator)
                    self.isMoving = false
                }
            }
            .store(in: &subscriptions)
    }

    func setConfig(_ config: PublicationSpeechSynthesizer.Configuration) {
        synthesizer.config = config
        settings = Settings(synthesizer: synthesizer)
    }

    func voiceWithIdentifier(_ id: String) -> TTSVoice? {
        synthesizer.voiceWithIdentifier(id)
    }

    @objc func start() {
        if let navigator = navigator as? VisualNavigator {
            Task {
                // Gets the locator of the element at the top of the page.
                if let locator = await navigator.firstVisibleElementLocator() {
                    synthesizer.start(from: locator)
                }
            }
        } else {
            synthesizer.start(from: navigator.currentLocation)
        }

        setupNowPlaying()
    }

    @objc func stop() {
        synthesizer.stop()
    }

    @objc func pauseOrResume() {
        synthesizer.pauseOrResume()
    }

    @objc func pause() {
        synthesizer.pause()
    }

    @objc func previous() {
        synthesizer.previous()
    }

    @objc func next() {
        synthesizer.next()
    }

    // MARK: - Now Playing

    // This will display the publication in the Control Center and support
    // external controls.

    private func setupNowPlaying() {
        Task {
            NowPlayingInfo.shared.media = await .init(
                title: publication.metadata.title ?? "",
                artist: publication.metadata.authors.map(\.name).joined(separator: ", "),
                artwork: try? publication.cover().get()
            )
        }

        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.pauseOrResume()
            return .success
        }
    }

    private func clearNowPlaying() {
        NowPlayingInfo.shared.clear()
    }
}

extension TTSViewModel: PublicationSpeechSynthesizerDelegate {
    func publicationSpeechSynthesizer(_ synthesizer: PublicationSpeechSynthesizer, stateDidChange synthesizerState: PublicationSpeechSynthesizer.State) {
        switch synthesizerState {
        case .stopped:
            state.showControls = false
            state.isPlaying = false
            playingUtteranceParts = nil
            clearNowPlaying()

        case let .playing(utterance, range: wordRange):
            state.showControls = true
            state.isPlaying = true
            playingUtteranceParts = utterance.parts
            if let wordRange = wordRange {
                playingWordRangeSubject.send(wordRange)
            }

        case let .paused(utterance):
            state.showControls = true
            state.isPlaying = false
            playingUtteranceParts = utterance.parts
        }
    }

    func publicationSpeechSynthesizer(_ synthesizer: PublicationSpeechSynthesizer, utterance: PublicationSpeechSynthesizer.Utterance, didFailWithError error: PublicationSpeechSynthesizer.Error) {
        // FIXME:
        log(.error, error)
    }
}
