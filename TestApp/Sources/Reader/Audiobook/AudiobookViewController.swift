//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import MediaPlayer
import R2Navigator
import R2Shared
import SwiftUI
import UIKit

class AudiobookViewController: ReaderViewController<_AudioNavigator>, _AudioNavigatorDelegate {
    private let model: AudiobookViewModel

    init(
        publication: Publication,
        locator: Locator?,
        bookId: Book.Id,
        books: BookRepository,
        bookmarks: BookmarkRepository
    ) {
        let navigator = _AudioNavigator(
            publication: publication,
            initialLocation: locator
        )

        model = AudiobookViewModel(
            navigator: navigator
        )

        super.init(
            navigator: navigator,
            publication: publication,
            bookId: bookId,
            books: books,
            bookmarks: bookmarks
        )

        navigator.delegate = self
    }

    private lazy var readerController =
        UIHostingController(rootView: AudiobookReader(model: model))

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white

        addChild(readerController)
        view.addSubview(readerController.view)
        readerController.view.frame = view.bounds
        readerController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        readerController.didMove(toParent: self)

        navigator.play()
        setupNowPlaying()
        setupCommandCenterControls()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        navigator.pause()
        clearNowPlaying()
    }

    // MARK: - AudioNavigatorDelegate

    func navigator(_ navigator: _MediaNavigator, playbackDidChange info: MediaPlaybackInfo) {
        model.onPlaybackChanged(info: info)

        updateNowPlaying(info: info)
        updateCommandCenterControls()
    }

    // MARK: - Command Center controls

    private func setupCommandCenterControls() {
        NowPlayingInfo.shared.media = .init(
            title: publication.metadata.title,
            artist: publication.metadata.authors.map(\.name).joined(separator: ", "),
            artwork: publication.cover
        )

        let rcc = MPRemoteCommandCenter.shared()

        func on(_ command: MPRemoteCommand, _ block: @escaping (_AudioNavigator, MPRemoteCommandEvent) -> Void) {
            command.addTarget { [weak self] event in
                guard let self = self else {
                    return .noActionableNowPlayingItem
                }
                block(self.navigator, event)
                return .success
            }
        }

        on(rcc.playCommand) { navigator, _ in
            navigator.play()
        }

        on(rcc.pauseCommand) { navigator, _ in
            navigator.pause()
        }

        on(rcc.togglePlayPauseCommand) { navigator, _ in
            navigator.playPause()
        }

        on(rcc.previousTrackCommand) { navigator, _ in
            navigator.goBackward()
        }

        on(rcc.nextTrackCommand) { navigator, _ in
            navigator.goForward()
        }

        rcc.skipBackwardCommand.preferredIntervals = [10]
        on(rcc.skipBackwardCommand) { navigator, _ in
            navigator.seek(by: -10)
        }

        rcc.skipForwardCommand.preferredIntervals = [30]
        on(rcc.skipForwardCommand) { navigator, _ in
            navigator.seek(by: +30)
        }

        on(rcc.changePlaybackPositionCommand) { navigator, event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return
            }
            navigator.seek(to: event.positionTime)
        }
    }

    private func updateCommandCenterControls() {
        let rcc = MPRemoteCommandCenter.shared()
        rcc.previousTrackCommand.isEnabled = navigator.canGoBackward
        rcc.nextTrackCommand.isEnabled = navigator.canGoForward
    }

    // MARK: - Now Playing metadata

    private func setupNowPlaying() {
        let nowPlaying = NowPlayingInfo.shared

        // Initial publication metadata.
        nowPlaying.media = NowPlayingInfo.Media(
            title: publication.metadata.title,
            artist: publication.metadata.authors.map(\.name).joined(separator: ", "),
            chapterCount: publication.readingOrder.count
        )

        // Update the artwork after the view model loaded it.
        model.$cover
            .sink { cover in
                nowPlaying.media?.artwork = cover
            }
            .store(in: &subscriptions)
    }

    private func updateNowPlaying(info: MediaPlaybackInfo) {
        let nowPlaying = NowPlayingInfo.shared

        nowPlaying.playback = NowPlayingInfo.Playback(
            duration: info.duration,
            elapsedTime: info.time,
            rate: navigator.rate
        )

        nowPlaying.media?.chapterNumber = info.resourceIndex
    }

    private func clearNowPlaying() {
        NowPlayingInfo.shared.clear()
    }
}

class AudiobookViewModel: ObservableObject {
    let navigator: _AudioNavigator

    @Published var cover: UIImage?
    @Published var playback: MediaPlaybackInfo = .init()

    init(navigator: _AudioNavigator) {
        self.navigator = navigator

        Task {
            cover = navigator.publication.cover
        }
    }

    func onPlaybackChanged(info: MediaPlaybackInfo) {
        playback = info
    }
}

struct AudiobookReader: View {
    @ObservedObject var model: AudiobookViewModel

    var body: some View {
        VStack {
            Spacer()

            if let cover = model.cover {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.bottom)
            }

            if model.playback.state == .loading {
                ProgressView()
                    .progressViewStyle(.circular)
            } else {
                if let duration = model.playback.duration, duration > 0 {
                    TimeSlider(
                        time: Binding(
                            get: { model.playback.time },
                            set: { model.navigator.seek(to: $0) }
                        ),
                        duration: duration
                    )
                }

                HStack(spacing: 16) {
                    Spacer()

                    // Skip backward by 10 seconds.
                    IconButton(systemName: "gobackward.10") {
                        model.navigator.seek(by: -10)
                    }

                    // Play the previous resource
                    IconButton(systemName: "backward.fill") {
                        model.navigator.goBackward()
                    }
                    .disabled(!model.navigator.canGoBackward)

                    // Toggle play-pause.
                    IconButton(
                        systemName: model.playback.state != .paused
                            ? "pause.fill"
                            : "play.fill"
                    ) {
                        model.navigator.playPause()
                    }

                    // Play the next resource.
                    IconButton(systemName: "forward.fill") {
                        model.navigator.goForward()
                    }
                    .disabled(!model.navigator.canGoForward)

                    // Skip forward by 30 seconds.
                    IconButton(systemName: "goforward.30") {
                        model.navigator.seek(by: 30)
                    }

                    Spacer()
                }
            }
        }
        .padding(40)
    }
}

struct TimeSlider: View {
    /// Current time in seconds.
    @Binding var time: Double

    /// Duration in seconds.
    let duration: Double

    /// When the user is dragging the slider, `isEditing` is true to prevent
    /// updating the slider value with `time` during playback.
    @State private var isEditing: Bool = false

    /// Current slider progress, computed either from the current `time` or
    /// from the thumb position while dragging.
    @State private var progress: Double = 0

    var body: some View {
        Slider(
            value: $progress,
            label: { EmptyView() },
            minimumValueLabel: { Text(formatTime(time)) },
            maximumValueLabel: { Text(formatTime(duration)) },
            onEditingChanged: { isEditing in
                self.isEditing = isEditing
                if !isEditing {
                    time = progress * duration
                }
            }
        )
        .onChange(of: time) { _ in
            if !isEditing {
                progress = time / duration
            }
        }
    }

    /// Formats the given `time` in seconds to a `[hh:]mm:ss` string.
    func formatTime(_ time: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        if time > 60 * 60 {
            formatter.allowedUnits.insert(.hour)
        }
        return formatter.string(from: time) ?? "00:00"
    }
}
