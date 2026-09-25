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

    /// Called when the system interrupts the audio session, e.g. with a phone
    /// call.
    ///
    /// Pause the playback if the underlying engine doesn't pause on its own
    /// (`AVPlayer` does), and remember whether this interruption paused it.
    func audioSessionInterruptionDidBegin()

    /// Called when an audio interruption finishes.
    ///
    /// `shouldResume` is a hint from the system that it's appropriate to
    /// resume the playback without waiting for user input. Resume only if the
    /// interruption paused the playback, and the user didn't pause it in the
    /// meantime (e.g. with Siri).
    func audioSessionInterruptionDidEnd(shouldResume: Bool)
}

public extension AudioSessionUser {
    var audioConfiguration: AudioSession.Configuration {
        .init()
    }
}

/// Manages the app's audio session for Readium audio consumers.
@MainActor
public protocol AudioSessionManaging: Sendable {
    /// Starts a new audio session with the given `user`.
    ///
    /// Returns when the audio session is ready to play, so the `user` must
    /// await it before starting its engine.
    func start(with user: any AudioSessionUser, isPlaying: Bool) async

    /// Ends the audio session of the given `user`.
    ///
    /// Does nothing if another user started a session since.
    ///
    /// This may be called from the `user`'s `deinit`, so implementations
    /// must not retain the `user`.
    func end(with user: any AudioSessionUser)

    /// Indicates whether the `user` is playing.
    func user(_ user: any AudioSessionUser, didChangePlaying isPlaying: Bool)
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
    ///
    /// Returns when the audio session is ready to play.
    public func start(with user: any AudioSessionUser, isPlaying: Bool) async {
        let id = ObjectIdentifier(user)
        if self.user?.id != id {
            if let oldUser = self.user {
                end(forUserID: oldUser.id)
            }
            self.user = User(user)
            self.isPlaying = isPlaying
        }

        // The session of the same user may have been ended in the background,
        // or by an interruption.
        startSession(with: user.audioConfiguration)
        await waitForActivation()
    }

    /// Ends the audio session of the given `user`.
    public func end(with user: any AudioSessionUser) {
        end(forUserID: ObjectIdentifier(user))
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

        apply(.activate(config))
        isSessionStarted = true
    }

    private func endSession() {
        guard isSessionStarted else {
            return
        }

        apply(.deactivate)
        isSessionStarted = false
    }

    /// Last requested change of the `AVAudioSession` activation state.
    private var activationTask: Task<Void, Never>?

    /// Waits until the last requested activation change is applied, or
    /// skipped.
    private func waitForActivation() async {
        await activationTask?.value
    }

    /// Change of the `AVAudioSession` activation state.
    private enum ActivationChange: Sendable {
        /// Sets the category from the given configuration, then activates
        /// the session.
        case activate(Configuration)
        /// Deactivates the session.
        case deactivate
    }

    /// Applies the given `change` to the `AVAudioSession`.
    ///
    /// These are blocking operations which can hang the main thread, so they
    /// run in a concurrent context. Each change awaits the previous one, to
    /// be applied in the order of the calls.
    ///
    /// A change still waiting for its turn is skipped when a new one is
    /// requested, as only the last requested state matters. Otherwise, a
    /// pending deactivation could stop an engine which started playing in
    /// the meantime.
    private func apply(_ change: ActivationChange) {
        activationTask?.cancel()
        activationTask = Task { @concurrent [previous = activationTask] in
            await previous?.value
            guard !Task.isCancelled else {
                return
            }

            let session = AVAudioSession.sharedInstance()
            switch change {
            case let .activate(config):
                do {
                    try session.setCategory(config.category, mode: config.mode, policy: config.routeSharingPolicy, options: config.options)
                    try session.setActive(true)
                    Self.log(.info, "Started audio session with category: \(config.category), mode: \(config.mode), policy: \(config.routeSharingPolicy), options: \(config.options)")
                } catch {
                    Self.log(.error, "Failed to start the audio session: \(error)")
                }

            case .deactivate:
                do {
                    try session.setActive(false)
                    Self.log(.info, "Ended audio session")
                } catch {
                    Self.log(.error, "Failed to end the audio session: \(error)")
                }
            }
        }
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
            // The system deactivated the session. A pending activation would
            // fail during the interruption, so it is skipped.
            isSessionStarted = false
            activationTask?.cancel()

            // The app was suspended while the session was active in the
            // background. Nothing was playing, and no `.ended` will follow.
            if reason == .appWasSuspended {
                return
            }

            isInterrupted = true
            user?.user?.audioSessionInterruptionDidBegin()

        case .ended:
            isInterrupted = false

            user?.user?.audioSessionInterruptionDidEnd(shouldResume: options.contains(.shouldResume))

        @unknown default:
            break
        }
    }
}
