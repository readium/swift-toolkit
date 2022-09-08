//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

public protocol PublicationSpeechSynthesizerDelegate: AnyObject {
    /// Called when the synthesizer's state is updated.
    func publicationSpeechSynthesizer(_ synthesizer: PublicationSpeechSynthesizer, stateDidChange state: PublicationSpeechSynthesizer.State)

    /// Called when an `error` occurs while speaking `utterance`.
    func publicationSpeechSynthesizer(_ synthesizer: PublicationSpeechSynthesizer, utterance: PublicationSpeechSynthesizer.Utterance, didFailWithError error: PublicationSpeechSynthesizer.Error)
}

/// `PublicationSpeechSynthesizer` orchestrates the rendition of a `Publication` by iterating through its content,
/// splitting it into individual utterances using a `ContentTokenizer`, then using a `TTSEngine` to read them aloud.
public class PublicationSpeechSynthesizer: Loggable {
    public typealias EngineFactory = () -> TTSEngine
    public typealias TokenizerFactory = (_ defaultLanguage: Language?) -> ContentTokenizer

    /// Returns whether the `publication` can be played with a `PublicationSpeechSynthesizer`.
    public static func canSpeak(publication: Publication) -> Bool {
        publication.content() != nil
    }

    public enum Error: Swift.Error {
        /// Underlying `TTSEngine` error.
        case engine(TTSError)
    }

    /// User configuration for the text-to-speech engine.
    public struct Configuration: Equatable {
        /// Language overriding the publication one.
        public var defaultLanguage: Language?
        /// Identifier for the voice used to speak the utterances.
        public var voiceIdentifier: String?

        public init(defaultLanguage: Language? = nil, voiceIdentifier: String? = nil) {
            self.defaultLanguage = defaultLanguage
            self.voiceIdentifier = voiceIdentifier
        }
    }

    /// An utterance is an arbitrary text (e.g. sentence) extracted from the publication, that can be synthesized by
    /// the TTS engine.
    public struct Utterance {
        /// Text to be spoken.
        public let text: String
        /// Locator to the utterance in the publication.
        public let locator: Locator
        /// Language of this utterance, if it dffers from the default publication language.
        public let language: Language?
    }

    /// Represents a state of the `PublicationSpeechSynthesizer`.
    public enum State {
        /// The synthesizer is completely stopped and must be (re)started from a given locator.
        case stopped

        /// The synthesizer is paused at the given utterance.
        case paused(Utterance)

        /// The TTS engine is synthesizing the associated utterance.
        /// `range` will be regularly updated while the utterance is being played.
        case playing(Utterance, range: Locator?)
    }

    /// Current state of the `PublicationSpeechSynthesizer`.
    public private(set) var state: State = .stopped {
        didSet {
            delegate?.publicationSpeechSynthesizer(self, stateDidChange: state)
        }
    }

    /// Current configuration of the `PublicationSpeechSynthesizer`.
    ///
    /// Changes are not immediate, they will be applied for the next utterance.
    public var config: Configuration

    public weak var delegate: PublicationSpeechSynthesizerDelegate?

    private let publication: Publication
    private let engineFactory: EngineFactory
    private let tokenizerFactory: TokenizerFactory

    /// Creates a `PublicationSpeechSynthesizer` using the given `TTSEngine` factory.
    ///
    /// Returns null if the publication cannot be synthesized.
    ///
    /// - Parameters:
    ///   - publication: Publication which will be iterated through and synthesized.
    ///   - config: Initial TTS configuration.
    ///   - engineFactory: Factory to create an instance of `TtsEngine`. Defaults to `AVTTSEngine`.
    ///   - tokenizerFactory: Factory to create a `ContentTokenizer` which will be used to
    ///     split each `ContentElement` item into smaller chunks. Splits by sentences by default.
    ///   - delegate: Optional delegate.
    public init?(
        publication: Publication,
        config: Configuration = Configuration(),
        engineFactory: @escaping EngineFactory = { AVTTSEngine() },
        tokenizerFactory: @escaping TokenizerFactory = defaultTokenizerFactory,
        delegate: PublicationSpeechSynthesizerDelegate? = nil
    ) {
        guard Self.canSpeak(publication: publication) else {
            return nil
        }

        self.publication = publication
        self.config = config
        self.engineFactory = engineFactory
        self.tokenizerFactory = tokenizerFactory
        self.delegate = delegate
    }

    /// The default content tokenizer will split the `Content.Element` items into individual sentences.
    public static let defaultTokenizerFactory: TokenizerFactory = { defaultLanguage in
        makeTextContentTokenizer(
            defaultLanguage: defaultLanguage,
            contextSnippetLength: 50,
            textTokenizerFactory: { language in
                makeDefaultTextTokenizer(unit: .sentence, language: language)
            }
        )
    }

    private var currentTask: Cancellable? = nil

    private lazy var engine: TTSEngine = engineFactory()

    /// List of synthesizer voices supported by the TTS engine.
    public var availableVoices: [TTSVoice] {
        engine.availableVoices
    }

    /// Returns the first voice with the given `identifier` supported by the TTS `engine`.
    ///
    /// This can be used to restore the user selected voice after storing it in the user defaults.
    public func voiceWithIdentifier(_ identifier: String) -> TTSVoice? {
        let voice = lastUsedVoice.takeIf { $0.identifier == identifier }
            ?? engine.voiceWithIdentifier(identifier)

        lastUsedVoice = voice
        return voice
    }

    /// Cache for the last requested voice, for performance.
    private var lastUsedVoice: TTSVoice? = nil

    /// (Re)starts the synthesizer from the given locator or the beginning of the publication.
    public func start(from startLocator: Locator? = nil) {
        currentTask?.cancel()
        publicationIterator = publication.content(from: startLocator)?.iterator()
        playNextUtterance(.forward)
    }

    /// Stops the synthesizer.
    ///
    /// Use `start()` to restart it.
    public func stop() {
        currentTask?.cancel()
        state = .stopped
        publicationIterator = nil
    }

    /// Interrupts a played utterance.
    ///
    /// Use `resume()` to restart the playback from the same utterance.
    public func pause() {
        currentTask?.cancel()
        if case let .playing(utterance, range: _) = state {
            state = .paused(utterance)
        }
    }

    /// Resumes an utterance interrupted with `pause()`.
    public func resume() {
        currentTask?.cancel()
        if case let .paused(utterance) = state {
            play(utterance)
        }
    }

    /// Pauses or resumes the playback of the current utterance.
    public func pauseOrResume() {
        switch state {
        case .stopped: return
        case .playing: pause()
        case .paused: resume()
        }
    }

    /// Skips to the previous utterance.
    public func previous() {
        currentTask?.cancel()
        playNextUtterance(.backward)
    }

    /// Skips to the next utterance.
    public func next() {
        currentTask?.cancel()
        playNextUtterance(.forward)
    }

    /// `Content.Iterator` used to iterate through the `publication`.
    private var publicationIterator: ContentIterator? = nil {
        didSet {
            utterances = CursorList()
        }
    }

    /// Utterances for the current publication `ContentElement` item.
    private var utterances: CursorList<Utterance> = CursorList()

    /// Plays the next utterance in the given `direction`.
    private func playNextUtterance(_ direction: Direction) {
        guard let utterance = nextUtterance(direction) else {
            state = .stopped
            return
        }
        play(utterance)
    }

    /// Plays the given `utterance` with the TTS `engine`.
    private func play(_ utterance: Utterance) {
        state = .playing(utterance, range: nil)

        currentTask = engine.speak(
            TTSUtterance(
                text: utterance.text,
                delay: 0,
                voiceOrLanguage: voiceOrLanguage(for: utterance)
            ),
            onSpeakRange: { [unowned self] range in
                state = .playing(
                    utterance,
                    range: utterance.locator.copy(
                        text: { $0 = utterance.locator.text[range] }
                    )
                )
            },
            completion: { [unowned self] result in
                switch result {
                case .success:
                    playNextUtterance(.forward)
                case .failure(let error):
                    state = .paused(utterance)
                    delegate?.publicationSpeechSynthesizer(self, utterance: utterance, didFailWithError: .engine(error))
                }
            }
        )
    }

    /// Returns the user selected voice if it's compatible with the utterance language. Otherwise, falls back on
    /// the languages.
    private func voiceOrLanguage(for utterance: Utterance) -> Either<TTSVoice, Language> {
        if let voice = config.voiceIdentifier
            .flatMap({ id in self.voiceWithIdentifier(id) })
            .takeIf({ voice in utterance.language == nil || utterance.language?.removingRegion() == voice.language.removingRegion() })
        {
            return .left(voice)
        } else {
            return .right(utterance.language
                ?? config.defaultLanguage
                ?? publication.metadata.language
                ?? Language.current
            )
        }
    }

    /// Gets the next utterance in the given `direction`, or null when reaching the beginning or the end.
    private func nextUtterance(_ direction: Direction) -> Utterance? {
        guard let utterance = utterances.next(direction) else {
            if loadNextUtterances(direction) {
                return nextUtterance(direction)
            }
            return nil
        }
        return utterance
    }

    /// Loads the utterances for the next publication `ContentElement` item in the given `direction`.
    private func loadNextUtterances(_ direction: Direction) -> Bool {
        do {
            guard let content = try publicationIterator?.next(direction) else {
                return false
            }

            let nextUtterances = try tokenize(content)
                .flatMap { utterances(for: $0) }

            if nextUtterances.isEmpty {
                return loadNextUtterances(direction)
            }

            utterances = CursorList(
                list: nextUtterances,
                startIndex: {
                    switch direction {
                    case .forward: return 0
                    case .backward: return nextUtterances.count - 1
                    }
                }()
            )

            return true

        } catch {
            log(.error, error)
            return false
        }
    }

    /// Splits a publication `ContentElement` item into smaller chunks using the provided tokenizer.
    ///
    /// This is used to split a paragraph into sentences, for example.
    func tokenize(_ element: ContentElement) throws -> [ContentElement] {
        let tokenizer = tokenizerFactory(config.defaultLanguage ?? publication.metadata.language)
        return try tokenizer(element)
    }

    /// Splits a publication `ContentElement` item into the utterances to be spoken.
    private func utterances(for element: ContentElement) -> [Utterance] {
        func utterance(text: String, locator: Locator, language: Language? = nil) -> Utterance? {
            guard text.contains(where: { $0.isLetter || $0.isNumber }) else {
                return nil
            }

            return Utterance(
                text: text,
                locator: locator,
                language: language
                    // If the language is the same as the one declared globally in the publication,
                    // we omit it. This way, the app can customize the default language used in the
                    // configuration.
                    .takeIf { $0 != publication.metadata.language }
            )
        }

        switch element {
        case let element as TextContentElement:
            return element.segments
                .compactMap { segment in
                    utterance(text: segment.text, locator: segment.locator, language: segment.language)
                }

        case let element as TextualContentElement:
            guard let text = element.text.takeIf({ !$0.isEmpty }) else {
                return []
            }
            return Array(ofNotNil: utterance(text: text, locator: element.locator))

        default:
            return []
        }
    }
}

private enum Direction {
    case forward, backward
}

private extension CursorList {
    mutating func next(_ direction: Direction) -> Element? {
        switch direction {
        case .forward:
            return next()
        case .backward:
            return previous()
        }
    }
}

private extension ContentIterator {
    func next(_ direction: Direction) throws -> ContentElement? {
        switch direction {
        case .forward:
            return try next()
        case .backward:
            return try previous()
        }
    }
}
