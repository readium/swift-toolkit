//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@preconcurrency import ReadiumShared

/// Coordinates audio playback of a publication by pulling ``PlaybackItem``s
/// from a ``GuidedNavigationCursor`` and routing them to the active ``Narrator``.
@MainActor
public final class AudioNavigator {
    /// Event callbacks for the navigator.
    public weak var delegate: (any AudioNavigatorDelegate)?

    /// The last activated ``PlaybackItem`` — the ground truth for the current
    /// playback position.
    public private(set) var currentItem: PlaybackItem?

    private let publication: Publication
    private let cursor: GuidedNavigationCursor
    private let narrator: AudioNarrator

    public init(publication: Publication, audioClipPlayer: any AudioClipPlayer) {
        self.publication = publication
        cursor = GuidedNavigationCursor(publication: publication)
        narrator = AudioNarrator(publication: publication, player: audioClipPlayer)
        narrator.delegate = self
    }

    // MARK: - Playback control

    public func play() {
        print("[AudioNavigator] play() called")
        Task {
            guard let item = await cursor.next() else {
                print("[AudioNavigator] play() — cursor returned nil, nothing to play")
                return
            }
            print("[AudioNavigator] play() — got first item from cursor: \(item)")
            narrator.play(from: item)
        }
    }

    public func pause() {
        narrator.pause()
    }

    public func resume() {
        narrator.resume()
    }

    public func stop() {
        narrator.stop()
    }

    /// Stops playback, seeks forward one item past `currentItem`, and resumes.
    public func goForward() async {
        narrator.stop()
        if let current = currentItem, case .audio(let ref) = current.content {
            await cursor.seek(to: ref)
            // Seek positions the cursor before `current`; advance past it.
            _ = await cursor.next()
        }
        guard let item = await cursor.next() else { return }
        narrator.play(from: item)
    }

    /// Stops playback, seeks back to `currentItem`, and resumes.
    public func goBackward() async {
        narrator.stop()
        if let current = currentItem, case .audio(let ref) = current.content {
            await cursor.seek(to: ref)
        }
        guard let item = await cursor.next() else { return }
        narrator.play(from: item)
    }
}

// MARK: - NarratorDelegate

extension AudioNavigator: NarratorDelegate {
    public func narrator(_ narrator: any Narrator, nextItemAfter item: PlaybackItem?) async -> PlaybackItem? {
        while true {
            guard let next = await cursor.next() else {
                print("[AudioNavigator] nextItemAfter — cursor exhausted")
                return nil
            }
            if case .audio = next.content {
                print("[AudioNavigator] nextItemAfter — returning audio item: \(next)")
                return next
            }
            print("[AudioNavigator] nextItemAfter — skipping non-audio item: \(next)")
        }
    }

    public func narrator(_ narrator: any Narrator, didActivateItem item: PlaybackItem) {
        currentItem = item
        print("[AudioNavigator] didActivateItem: \(item)")
        delegate?.audioNavigator(self, didActivateItem: item)
    }

    public func narratorDidFinish(_ narrator: any Narrator) {
        delegate?.audioNavigatorDidFinish(self)
    }

    public func narrator(_ narrator: any Narrator, didFailWithError error: Error) {
        delegate?.audioNavigator(self, didFailWithError: error)
    }
}

// MARK: - AudioNavigatorDelegate

@MainActor public protocol AudioNavigatorDelegate: AnyObject {
    func audioNavigator(_ navigator: AudioNavigator, didActivateItem item: PlaybackItem)
    func audioNavigatorDidFinish(_ navigator: AudioNavigator)
    func audioNavigator(_ navigator: AudioNavigator, didFailWithError error: Error)
}
