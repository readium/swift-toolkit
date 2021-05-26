//
//  AudioSession.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 27/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import AVFoundation
import Foundation

/// An user of the `AudioSession`, for example a media player object.
@available(iOS 10.0, *)
public protocol _AudioSessionUser: AnyObject {
    
    /// Audio session configuration to use for this user.
    var audioConfiguration: _AudioSession.Configuration { get }
    
    /// Called when an audio interruption (e.g. phone call) finishes, to resume audio playback or
    /// recording.
    func play()

}

@available(iOS 10.0, *)
public extension _AudioSessionUser {
    
    var audioConfiguration: _AudioSession.Configuration { .init() }
    
}

/// Manages an activated `AVAudioSession`.
/// 
/// **WARNING:** This API is experimental and may change or be removed in a future release without
/// notice. Use with caution.
@available(iOS 10.0, *)
public final class _AudioSession: Loggable {
    
    public struct Configuration {
        let category: AVAudioSession.Category
        let mode: AVAudioSession.Mode
        let options: AVAudioSession.CategoryOptions
        
        public init(category: AVAudioSession.Category = .playback, mode: AVAudioSession.Mode = .default, options: AVAudioSession.CategoryOptions = []) {
            self.category = category
            self.mode = mode
            self.options = options
        }
    }

    /// Shared `AudioSession` for this app.
    public static let shared = _AudioSession()
    
    private init() {}
    
    /// Current user of the `AudioSession`.
    private weak var user: _AudioSessionUser?

    /// Starts a new audio session with the given `user`.
    public func start(with user: _AudioSessionUser) {
        guard self.user !== user else {
            return
        }
        
        if let oldUser = self.user {
            end(for: oldUser)
        }
        self.user = user

        let audioSession = AVAudioSession.sharedInstance()
        do {
            let config = user.audioConfiguration
            try audioSession.setCategory(config.category, mode: config.mode, options: config.options)
            try audioSession.setActive(true)
        } catch {
            log(.error, "Failed to start the audio session: \(error)")
        }
        
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: audioSession,
            queue: .main)
        { [weak self] notification in
            self?.handleAudioSessionInterruption(notification: notification)
        }
    }
    
    /// Ends the current audio session.
    public func end(for user: _AudioSessionUser) {
        guard self.user === user || self.user == nil else {
            return
        }
        
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            log(.error, "Failed to end the audio session: \(error)")
        }
        
        interruptionObserver = nil
        self.user = nil
    }

    
    // MARK: Interruption
    
    /// Whether the audio session is currently interrupted, e.g. by a phone call.
    public private(set) var isInterrupted: Bool = false
    
    /// The observer of audio session interruption notifications.
    private var interruptionObserver: Any?
    
    private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
            let rawInterruptionType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let interruptionType = AVAudioSession.InterruptionType(rawValue: rawInterruptionType) else
        {
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
