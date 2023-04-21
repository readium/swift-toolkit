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
            publication: publication,
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
        model.playbackDidChange(info: info)
    }
}

class AudiobookViewModel: ObservableObject {
    private let publication: Publication
    private let navigator: AudioNavigator

    @Published var cover: UIImage?
    @Published var playback: MediaPlaybackInfo = .init()

    init(publication: Publication, navigator: AudioNavigator) {
        self.publication = publication
        self.navigator = navigator

        Task {
            cover = publication.cover
        }
    }

    func playbackDidChange(info: MediaPlaybackInfo) {
        playback = info
    }

    func playPause() {
        navigator.playPause()
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
                    .padding()
            }

            HStack {
                Spacer()

                IconButton(
                    systemName: model.playback.state != .paused
                        ? "pause.fill"
                        : "play.fill"
                ) {
                    model.playPause()
                }

                Spacer()
            }

            Spacer(minLength: 40)
        }
    }
}
