//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import Foundation
import UIKit

@available(*, deprecated, message: "Use `AudioSession` instead")
public typealias _AudioSession = AudioSession
@available(*, deprecated, message: "Use `AudioSessionUser` instead")
public typealias _AudioSessionUser = AudioSessionUser

/// An user of the `AudioSession`, for example a media player object.
public protocol AudioSessionUser: AnyObject {
    /// Audio session configuration to use for this user.
    var audioConfiguration: AudioSession.Configuration { get }

    /// Called when an audio interruption (e.g. phone call) finishes, to resume audio playback or
    /// recording.
    func play()
}

public extension AudioSessionUser {
    var audioConfiguration: AudioSession.Configuration { .init() }
}

/// Manages an activated `AVAudioSession`.
public final class AudioSession: Loggable {
    public struct Configuration: Equatable {
        let category: AVAudioSession.Category
        let mode: AVAudioSession.Mode
        let routeSharingPolicy: AVAudioSession.RouteSharingPolicy
        let options: AVAudioSession.CategoryOptions

        public init(
            category: AVAudioSession.Category = .playback,
            mode: AVAudioSession.Mode = .default,
            routeSharingPolicy: AVAudioSession.RouteSharingPolicy = .default,
            options: AVAudioSession.CategoryOptions = []
        ) {
            self.category = category
            self.mode = mode
            self.routeSharingPolicy = routeSharingPolicy
            self.options = options
        }
    }

    /// Shared `AudioSession` for this app.
    public static let shared = AudioSession()

    private init() {
        observeAppStateChanges()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Current user of the `AudioSession`.
    private weak var user: AudioSessionUser?

    /// Starts a new audio session with the given `user`.
    public func start(with user: AudioSessionUser, isPlaying: Bool) {
        guard self.user !== user else {
            return
        }

        if let oldUser = self.user {
            end(for: oldUser)
        }
        self.user = user
        self.isPlaying = false

        startSession(with: user.audioConfiguration)
    }

    /// Ends the current audio session.
    public func end(for user: AudioSessionUser) {
        guard self.user === user || self.user == nil else {
            return
        }

        self.user = nil
        isPlaying = false

        endSession()
    }

    /// Indicates whether the `user` is playing.
    private var isPlaying: Bool = false

    public func user(_ user: AudioSessionUser, didChangePlaying isPlaying: Bool) {
        guard self.user === user, self.isPlaying != isPlaying else {
            return
        }

        self.isPlaying = isPlaying

        if isPlaying {
            startSession(with: user.audioConfiguration)
        } else if UIApplication.shared.applicationState != .active {
            endSession()
        }
    }

    // MARK: App background state

    private func observeAppStateChanges() {
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    @objc private func appDidEnterBackground() {
        if !isPlaying {
            endSession()
        }
    }

    // MARK: Session management

    private var isSessionStarted = false

    private func startSession(with config: Configuration) {
        guard !isSessionStarted else {
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(config.category, mode: config.mode, policy: config.routeSharingPolicy, options: config.options)
            try audioSession.setActive(true)
        } catch {
            log(.error, "Failed to start the audio session: \(error)")
        }

        isSessionStarted = true

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            self?.handleAudioSessionInterruption(notification: notification)
        }
    }

    private func endSession() {
        guard isSessionStarted else {
            return
        }

        do {
            AVAudioSession.sharedInstance()
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            log(.error, "Failed to end the audio session: \(error)")
        }

        isSessionStarted = false
        interruptionObserver = nil
    }

    /// Whether the audio session is currently interrupted, e.g. by a phone call.
    public private(set) var isInterrupted: Bool = false

    /// The observer of audio session interruption notifications.
    private var interruptionObserver: Any?

    private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let rawInterruptionType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: rawInterruptionType)
        else {
            return
        }

        let options = (userInfo[AVAudioSessionInterruptionOptionKey] as? UInt)
            .map(AVAudioSession.InterruptionOptions.init(rawValue:))
            ?? []

        switch interruptionType {
        case .began:
            isInterrupted = true

        case .ended:
            isInterrupted = false

            // When an interruption ends, determine whether playback should resume automatically,
            // and reactivate the audio session if necessary.
            do {
                if let user = user {
                    try AVAudioSession.sharedInstance().setActive(true)

                    if options.contains(.shouldResume) {
                        user.play()
                    }
                }
            } catch {
                log(.error, "Cannot resume audio session after interruption: \(error)")
            }

        @unknown default:
            break
        }
    }
}
