# Audiobooks

The **`AudioNavigator`** plays the audio publications: Readium Audiobooks (`.audiobook`, `.lcpa`), Zipped Audio Books (`.zab`), and standalone audio files such as an M4B or MP3. This guide explains how to play an audiobook, and how Readium reads the metadata embedded in audio files.

> [!IMPORTANT]
> The `AudioNavigator` is chromeless and does not provide any user interface. You are responsible for the playback controls, the progress bar, the table of contents, etc.

## Playing an audiobook

Create an `AudioNavigator` from a `Publication` conforming to the `audiobook` profile, then start the playback.

```swift
guard publication.conforms(to: .audiobook) else {
    return
}

let navigator = AudioNavigator(
    publication: publication,
    initialLocation: lastReadLocation
)

navigator.play()
```

The `AudioNavigator` implements the `Navigator` interface. See the [Navigator guide](Navigator.md) to navigate in the publication, for example to a link of the table of contents, and to save the last read location.

### Observing the playback

You are responsible for the playback controls. Implement an `AudioNavigatorDelegate` to update them when the playback changes.

```swift
// The Navigator does not retain its delegate, keep a reference to it.
let delegate = MyAudioNavigatorDelegate()
navigator.delegate = delegate

@MainActor class MyAudioNavigatorDelegate: AudioNavigatorDelegate {

    func navigator(_ navigator: AudioNavigator, playbackDidChange info: MediaPlaybackInfo) {
        // Show a pause button while playing or loading, a play button otherwise.
        updatePlayPauseButton(isPlaying: info.state.playsWhenReady)
        updateProgress(time: info.time, duration: info.duration)

        if info.state == .ended {
            didReachEndOfPublication()
        }
    }
}
```

The `state` of the playback is one of:

| State      | Description                                                                        |
|------------|------------------------------------------------------------------------------------|
| `paused`  | The playback is paused, `play()` resumes it.                                       |
| `loading` | The playback is requested, but the player is buffering or completing a seek.       |
| `playing` | The player is playing.                                                             |
| `ended`   | The playback reached the end of the publication, `play()` restarts from the start. |

> [!NOTE]
> `playbackDidChange` may be called several times while the playback is ended. Compare with the previous state if your code must run only once.

### Controlling the playback

* `play()`, `pause()` and `playPause()` control the playback.
* `seek(to:)` moves to a time in the current resource, and `seek(by:)` skips forward or backward, moving over to the adjacent resources when needed.
* `stop()` stops the playback and ends the audio session, for example when the user closes the player.

By default, the Navigator plays the next resource when it reaches the end of the current one. To hold the playback at the end of a resource instead, return `false` from `navigator(_:shouldPlayNextResource:)`. The playback is then `.paused`, and `play()` moves on to the next resource.

## Metadata of audio files

Audio files embed their own metadata as tags (MP4 atoms and ID3 frames). When you open a ZIP or folder of audio files, or a standalone M4B or MP3 file, there is no manifest to describe the publication, so Readium reads these tags to build the `Publication`:

* The **metadata**, following the [Readium audio metadata rules](https://github.com/readium/architecture/blob/master/streamer/parser/audio-metadata.md).
* The **table of contents**, from the chapters embedded in each file. Without any chapter, the titles of the files make the table of contents when at least two files have one.
* The **cover**, from the first file holding one in reading order.

Each link of the `readingOrder` holds the title, the duration and the bitrate of its audio file.

### Opening a container without reading its audio files

Reading the tags opens every audio file of a container (e.g. ZIP file or folder). To open a large container faster, or reduce the number of requests sent when opening a remote container, create an `AudioParser` with `readsContainerEntriesMetadata` set to `false` and give it to the `DefaultPublicationParser`. The publication then has no metadata, table of contents or cover. A standalone audio file is always read.

```swift
let publicationOpener = PublicationOpener(
    parser: DefaultPublicationParser(
        httpClient: httpClient,
        assetRetriever: assetRetriever,
        ...,
        additionalParsers: [
            AudioParser(
                assetRetriever: assetRetriever,
                readsContainerEntriesMetadata: false
            ),
        ]
    )
)
```

See the [Opening a publication guide](../Open%20Publication.md) for more information on the `PublicationOpener`.

### Customizing the metadata

To change the metadata of the audio files, or to read them from another source, implement an `AudioMetadataReader`. It returns the `AudioMetadata` of one audio file. The `AudioParser` calls it for each file and builds the `Publication` from the results.

```swift
final class MyMetadataReader: AudioMetadataReader {
    private let defaultReader = DefaultAudioMetadataReader()

    func read(_ request: AudioMetadataRequest) async -> Result<AudioMetadata, AudioMetadataReadError> {
        await defaultReader.read(request).map { metadata in
            var metadata = metadata
            metadata.narrators = metadata.narrators.map(normalizeName)
            return metadata
        }
    }
}

let parser = AudioParser(
    assetRetriever: assetRetriever,
    metadataReader: MyMetadataReader()
)
```

The error returned by the reader decides what happens to the audio file:

| Error                   | Result                                                   |
|-------------------------|----------------------------------------------------------|
| `.resourceNotSupported` | The file is kept in the reading order, without metadata. |
| `.reading(.decoding)`   | Same, and an `AudioMetadataWarning` is logged.           |
| Any other `.reading`    | Opening the publication fails with this error.           |

> [!TIP]
> Skip the extraction of the cover when `request.includesCover` is `false`: the parser already found one in a previous file.
