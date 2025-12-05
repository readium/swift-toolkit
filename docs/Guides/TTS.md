# Text-to-speech

> [!NOTE]
> TTS is not yet implemented for all formats.

Text-to-speech can be used to read aloud a publication using a synthetic voice. The Readium toolkit ships with a TTS implementation based on the native [Apple Speech Synthesis](https://developer.apple.com/documentation/avfoundation/speech_synthesis), but it is opened for extension if you want to use a different TTS engine.

## Glossary

* **engine** – a TTS engine takes an utterance and transforms it into audio using a synthetic voice
* **tokenizer** - algorithm splitting the publication text content into individual utterances, usually by sentences
* **utterance** - a single piece of text played by a TTS engine, such as a sentence
* **voice** – a synthetic voice is used by a TTS engine to speak a text using rules pertaining to the voice's language and region

## Reading a publication aloud

To read a publication, you need to create an instance of `PublicationSpeechSynthesizer`. It orchestrates the rendition of a publication by iterating through its content, splitting it into individual utterances using a `ContentTokenizer`, then using a `TTSEngine` to read them aloud. Not all publications can be read using TTS, therefore the constructor returns an optional object. You can also check whether a publication can be played beforehand using `PublicationSpeechSynthesizer.canSpeak(publication:)`.

```swift
let synthesizer = PublicationSpeechSynthesizer(
    publication: publication,
    config: PublicationSpeechSynthesizer.Configuration(
        defaultLanguage: Language("fr")
    )
)
```

Then, begin the playback from a given starting `Locator`. When missing, the playback will start from the beginning of the publication.

```swift
synthesizer.start()
```

You should now hear the TTS engine speak the utterances from the beginning. `PublicationSpeechSynthesizer` provides the APIs necessary to control the playback from the app:

* `stop()` - stops the playback ; requires start to be called again
* `pause()` - interrupts the playback temporarily
* `resume()` - resumes the playback where it was paused
* `pauseOrResume()` - toggles the pause
* `previous()` - skips to the previous utterance
* `next()` - skips to the next utterance

Look at `TTSView.swift` in the Test App for an example of a view calling these APIs.

## Observing the playback state

The `PublicationSpeechSynthesizer` should be the single source of truth to represent the playback state in your user interface. You can observe the state with `PublicationSpeechSynthesizerDelegate.publicationSpeechSynthesizer(_:stateDidChange:)` to keep your user interface synchronized with the playback. The possible states are:

* `.stopped` when idle and waiting for a call to `start()`.
* `.paused(Utterance)` when interrupted while playing the associated utterance.
* `.playing(Utterance, range: Locator?)` when speaking the associated utterance. This state is updated repeatedly while the utterance is spoken, updating the `range` value with the portion of utterance being played (usually the current word).

When pairing the `PublicationSpeechSynthesizer` with a `Navigator`, you can use the `utterance.locator` and `range` properties to highlight spoken utterances and turn pages automatically.

## Configuring the TTS

> [!WARNING]
> The way the synthesizer is configured is expected to change with the introduction of the new Settings API. Expect some breaking changes when updating.

The `PublicationSpeechSynthesizer` offers some options to configure the TTS engine. Note that the support of each configuration option depends on the TTS engine used.

Update the configuration by setting it directly. The configuration is not applied right away but for the next utterance.

```swift
synthesizer.config.defaultLanguage = Language("fr")
```

### Default language

The language used by the synthesizer is important, as it determines which TTS voices are used and the rules to tokenize the publication text content.

By default, `PublicationSpeechSynthesizer` will use any language explicitly set on a text element (e.g. with `lang="fr"` in HTML) and fall back on the global language declared in the publication manifest. You can override the fallback language with `Configuration.defaultLanguage` which is useful when the publication language is incorrect or missing.

### Voice

The `voice` setting can be used to change the synthetic voice used by the engine. To get the available list, use `synthesizer.availableVoices`.

To restore a user-selected voice, persist the unique voice identifier returned by `voice.identifier`.

Users do not expect to see all available voices at all time, as they depend on the selected language. You can group the voices by their language and filter them by the selected language using the following snippet.

```swift
let voicesByLanguage: [Language: [TTSVoice]] =
    Dictionary(grouping: synthesizer.availableVoices, by: \.language)
```

## Synchronizing the TTS with a Navigator

While `PublicationSpeechSynthesizer` is completely independent from `Navigator` and can be used to play a publication in the background, most apps prefer to render the publication while it is being read aloud. The `Locator` core model is used as a means to synchronize the synthesizer with the navigator.

### Starting the TTS from the visible page

`PublicationSpeechSynthesizer.start()` takes a starting `Locator` for parameter. You can use it to begin the playback from the currently visible page in a `VisualNavigator` using `firstVisibleElementLocator()`.

```swift
navigator.firstVisibleElementLocator { start in
    synthesizer.start(from: start)
}
```

### Highlighting the currently spoken utterance

If you want to highlight or underline the current utterance on the page, you can apply a `Decoration` on the utterance locator with a `DecorableNavigator`.

```swift
extension TTSViewModel: PublicationSpeechSynthesizerDelegate {

    public func publicationSpeechSynthesizer(_ synthesizer: PublicationSpeechSynthesizer, stateDidChange synthesizerState: PublicationSpeechSynthesizer.State) {
        let playingUtterance: Locator?

        switch synthesizerState {
        case .stopped:
            playingUtterance = nil
        case let .playing(utterance, range: _):
            playingUtterance = utterance
        case let .paused(utterance):
            playingUtterance = utterance
        }

        var decorations: [Decoration] = []
        if let locator = playingUtterance.locator {
            decorations.append(Decoration(
                id: "tts-utterance",
                locator: locator,
                style: .highlight(tint: .red)
            ))
        }
        navigator.apply(decorations: decorations, in: "tts")
    }
}
```

### Turning pages automatically

You can use the same technique as described above to automatically synchronize the `Navigator` with the played utterance, using `navigator.go(to: utterance.locator)`.

However, this will not turn pages mid-utterance, which can be annoying when speaking a long sentence spanning two pages. To address this, you can use the `range` associated value of the `.playing` state instead. It is updated regularly while speaking each word of an utterance. Note that jumping to the `range` locator for every word can severely impact performances. To alleviate this, you can throttle the observer.

```swift
extension TTSViewModel: PublicationSpeechSynthesizerDelegate {

    public func publicationSpeechSynthesizer(_ synthesizer: PublicationSpeechSynthesizer, stateDidChange synthesizerState: PublicationSpeechSynthesizer.State) {
        switch synthesizerState {
        case .stopped, .paused:
            break
        case let .playing(_, range: range):
            // TODO: You should use throttling here, for example with Combine:
            // https://developer.apple.com/documentation/combine/fail/throttle(for:scheduler:latest:)
            navigator.go(to: range)
        }
    }
}
```

## Using a custom utterance tokenizer

By default, the `PublicationSpeechSynthesizer` will split the publication text into sentences to create the utterances. You can customize this for finer or coarser utterances using a different tokenizer.

For example, this will speak the content word-by-word:

```swift
let synthesizer = PublicationSpeechSynthesizer(
    publication: publication,
    tokenizerFactory: { language in
        makeTextContentTokenizer(
            defaultLanguage: language,
            textTokenizerFactory: { language in
                makeDefaultTextTokenizer(unit: .word, language: language)
            }
        )
    }
)
```

For completely custom tokenizing or to improve the existing tokenizers, you can implement your own `ContentTokenizer`.

## Using a custom TTS engine

`PublicationSpeechSynthesizer` can be used with any TTS engine, provided they implement the `TTSEngine` interface. Take a look at `AVTTSEngine` for an example implementation.

```swift
let synthesizer = PublicationSpeechSynthesizer(
    publication: publication,
    engineFactory: { MyCustomEngine() }
)
```

