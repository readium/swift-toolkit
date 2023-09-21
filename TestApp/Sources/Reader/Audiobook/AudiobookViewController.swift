//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import R2Navigator
import R2Shared
import SwiftUI
import UIKit

class AudiobookViewController: ReaderViewController<AudioNavigator>, AudioNavigatorDelegate {
    private let model: AudiobookViewModel

    init(
        publication: Publication,
        locator: Locator?,
        bookId: Book.Id,
        books: BookRepository,
        bookmarks: BookmarkRepository
    ) {
        let navigator = AudioNavigator(
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
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigator.pause()
    }

    // MARK: - AudioNavigatorDelegate

    func navigator(_ navigator: MediaNavigator, playbackDidChange info: MediaPlaybackInfo) {
        model.onPlaybackChanged(info: info)
    }
}

class AudiobookViewModel: ObservableObject {
    let navigator: AudioNavigator

    @Published var cover: UIImage?
    @Published var playback: MediaPlaybackInfo = .init()

    init(navigator: AudioNavigator) {
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
                        model.navigator.seek(relatively: -10)
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
                        model.navigator.seek(relatively: 30)
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
