//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import Foundation
import UIKit

/// An user of the `AudioSession`, for example a media player object.
@MainActor
public protocol AudioSessionUser: AnyObject {
    /// Audio session configuration to use for this user.
    var audioConfiguration: AudioSession.Configuration { get }

    /// Resumes audio playback or recording.
    ///
    /// The default implementation of `audioSessionInterruptionDidEnd(shouldResume:)`
    /// calls it when the system allows resuming after an interruption.
    func play()

    /// Called when the system interrupts the audio session, e.g. with a phone
    /// call.
    ///
    /// Pause the playback if the underlying engine doesn't pause on its own,
    /// and remember whether this interruption paused it.
    func audioSessionInterruptionDidBegin()

    /// Called when an audio interruption finishes.
    ///
    /// `shouldResume` is a hint from the system that it's appropriate to
    /// resume the playback without waiting for user input. Resume only if the
    /// interruption paused the playback.
    func audioSessionInterruptionDidEnd(shouldResume: Bool)
}

public extension AudioSessionUser {
    var audioConfiguration: AudioSession.Configuration {
        .init()
    }

    func audioSessionInterruptionDidBegin() {}

    func audioSessionInterruptionDidEnd(shouldResume: Bool) {
        if shouldResume {
            play()
        }
    }
}

/// Manages the app's audio session for Readium audio consumers.
@MainActor
public protocol AudioSessionManaging: Sendable {
    /// Starts a new audio session with the given `user`.
    ///
    /// The returned opaque token can be used to end the session for the same
    /// user.
    @discardableResult
    func start(with user: any AudioSessionUser, isPlaying: Bool) -> AudioSessionToken

    /// Ends the current audio session.
    func end(with token: AudioSessionToken)

    /// Indicates whether the `user` is playing.
    func user(_ user: any AudioSessionUser, didChangePlaying isPlaying: Bool)
}

/// Opaque token identifying an audio session user.
public struct AudioSessionToken: Sendable, Equatable {
    public let id: ObjectIdentifier

    public init(id: ObjectIdentifier) {
        self.id = id
    }
}

/// Manages an activated `AVAudioSession`.
@MainActor
public final class AudioSession: AudioSessionManaging, Sendable, Loggable {
    public struct Configuration: Sendable, Equatable {
        public let category: AVAudioSession.Category
        public let mode: AVAudioSession.Mode
        public let routeSharingPolicy: AVAudioSession.RouteSharingPolicy
        public let options: AVAudioSession.CategoryOptions

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
    public nonisolated static let shared = AudioSession()

    private nonisolated init() {
        Task {
            await observeAppStateChanges()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    fileprivate struct User {
        let id: ObjectIdentifier
        private(set) weak var user: (any AudioSessionUser)?

        init(_ user: any AudioSessionUser) {
            id = ObjectIdentifier(user)
            self.user = user
        }
    }

    /// Current user of the `AudioSession`.
    private var user: User?

    /// Starts a new audio session with the given `user`.
    @discardableResult
    public func start(with user: any AudioSessionUser, isPlaying: Bool) -> AudioSessionToken {
        let id = ObjectIdentifier(user)
        let token = AudioSessionToken(id: id)
        guard self.user?.id != id else {
            return token
        }

        if let oldUser = self.user {
            end(forUserID: oldUser.id)
        }
        self.user = User(user)
        self.isPlaying = isPlaying

        startSession(with: user.audioConfiguration)
        return token
    }

    /// Ends the current audio session.
    public nonisolated func end(with token: AudioSessionToken) {
        Task {
            await end(forUserID: token.id)
        }
    }

    private func end(forUserID id: ObjectIdentifier) {
        guard user?.id == id else {
            return
        }

        user = nil
        isPlaying = false

        endSession()
    }

    /// Indicates whether the `user` is playing.
    private var isPlaying: Bool = false

    public func user(_ user: any AudioSessionUser, didChangePlaying isPlaying: Bool) {
        let id = ObjectIdentifier(user)
        guard self.user?.id == id, self.isPlaying != isPlaying else {
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

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard
                let userInfo = notification.userInfo,
                let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: rawType)
            else {
                return
            }
            let rawReason = userInfo[AVAudioSessionInterruptionReasonKey] as? UInt
            let rawOptions = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt

            // The hooks must run synchronously, before any engine delegate
            // callback following the notification.
            MainActor.assumeIsolated {
                self?.handleAudioSessionInterruption(
                    type: type,
                    reason: rawReason.flatMap(AVAudioSession.InterruptionReason.init(rawValue:)),
                    options: rawOptions.map(AVAudioSession.InterruptionOptions.init(rawValue:)) ?? []
                )
            }
        }
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
            log(.info, "Started audio session with category: \(config.category), mode: \(config.mode), policy: \(config.routeSharingPolicy), options: \(config.options)")
        } catch {
            log(.error, "Failed to start the audio session: \(error)")
        }

        isSessionStarted = true
    }

    private func endSession() {
        guard isSessionStarted else {
            return
        }

        do {
            try AVAudioSession.sharedInstance().setActive(false)
            log(.info, "Ended audio session")
        } catch {
            log(.error, "Failed to end the audio session: \(error)")
        }

        isSessionStarted = false
    }

    /// Whether the audio session is currently interrupted, e.g. by a phone call.
    public private(set) var isInterrupted: Bool = false

    /// The observer of audio session interruption notifications.
    private var interruptionObserver: Any?

    private func handleAudioSessionInterruption(
        type: AVAudioSession.InterruptionType,
        reason: AVAudioSession.InterruptionReason?,
        options: AVAudioSession.InterruptionOptions
    ) {
        switch type {
        case .began:
            // The system deactivated the session.
            isSessionStarted = false

            // The app was suspended while the session was active in the
            // background. Nothing was playing, and no `.ended` will follow.
            if reason == .appWasSuspended {
                return
            }

            isInterrupted = true
            user?.user?.audioSessionInterruptionDidBegin()

        case .ended:
            isInterrupted = false

            guard let user = user?.user else {
                return
            }

            let shouldResume = options.contains(.shouldResume)
            if shouldResume {
                // We reactivate the session before knowing whether the user
                // will resume. The Readium engines reactivate it on their own
                // when they resume, but custom users relying on the default
                // `play()` hook might not report `didChangePlaying`. The
                // trade-off is briefly holding the session when nothing
                // resumes.
                startSession(with: user.audioConfiguration)
            }
            user.audioSessionInterruptionDidEnd(shouldResume: shouldResume)

        @unknown default:
            break
        }
    }
}
