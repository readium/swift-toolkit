//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

/// An ``LCPAuthenticating`` implementation which can be used to observe
/// authentication requests.
///
/// Pair an ``LCPObservableAuthentication``  with an ``LCPDialog`` to implement
/// the LCP authentication in SwiftUI.
@MainActor
public final class LCPObservableAuthentication: LCPAuthenticating, ObservableObject {
    /// Represents an on-going LCP authentication request.
    ///
    /// You must call the `submit()` or `cancel()` API to conclude the request.
    @MainActor
    public final class Request: Identifiable {
        /// LCP License requested to be unlocked.
        public let license: LCPAuthenticatedLicense

        /// Reason for this authentication request.
        public let reason: LCPAuthenticationReason

        /// Sender given to the component requesting the authentication.
        ///
        /// For example, this is the `sender` you provided to the
        /// `PublicationOpener.open()` API.
        ///
        /// Readium does not use this internally. You can pass any object to
        /// help you determine how to present the LCP authentication dialog.
        public let sender: Any?

        private var continuation: CheckedContinuation<String?, Never>?

        init(
            license: LCPAuthenticatedLicense,
            reason: LCPAuthenticationReason,
            sender: Any?,
            continuation: CheckedContinuation<String?, Never>
        ) {
            self.license = license
            self.reason = reason
            self.sender = sender
            self.continuation = continuation
        }

        /// Terminates this authentication request by providing the given
        /// `passphrase`.
        public func submit(_ passphrase: String) {
            continuation?.resume(returning: passphrase)
            continuation = nil
        }

        /// Terminates this authentication request by cancelling it.
        public func cancel() {
            continuation?.resume(returning: nil)
            continuation = nil
        }
    }

    /// The current authentication request.
    ///
    /// Setting it to `nil` automatically cancels the previous request.
    @Published public var request: Request? {
        didSet { oldValue?.cancel() }
    }

    private var continuation: CheckedContinuation<String?, Never>?

    public init() {}

    public func retrievePassphrase(
        for license: LCPAuthenticatedLicense,
        reason: LCPAuthenticationReason,
        allowUserInteraction: Bool,
        sender: Any?
    ) async -> String? {
        guard allowUserInteraction else {
            return nil
        }

        continuation?.resume(returning: nil)

        return await withCheckedContinuation {
            self.request = Request(
                license: license,
                reason: reason,
                sender: sender,
                continuation: $0
            )
        }
    }
}
