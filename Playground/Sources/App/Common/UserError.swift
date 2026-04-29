//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import OSLog
import SwiftUI

/// An error that should be displayed to the user.
///
/// It is similar to a `LocalizedError`, but the message is mandatory, and it
/// references a lower-level error.
struct UserError: LocalizedError {
    /// The human-readable message shown to the user.
    let message: String

    /// The underlying technical error.
    let cause: Error?

    /// Creates a `UserError` from any `Error`.
    init?(_ error: Error) {
        if let error = error as? UserErrorConvertible {
            guard let error = error.userError else {
                return nil
            }
            self = error
        } else {
            self.init(error.localizedDescription, cause: error)
        }
    }

    /// Creates a `UserError` with an explicit message and an optional cause.
    init(
        _ message: String,
        cause: Error? = nil
    ) {
        self.message = message
        self.cause = cause
    }

    /// Satisfies `LocalizedError` — routes `localizedDescription` to `message`.
    var errorDescription: String? {
        message
    }

    /// Logs debugging details about this error.
    func log(with logger: Logger = Logger()) {
        var details = ""
        dump(self, to: &details)
        logger.error("\(details)")
    }
}

/// Convenience protocol for an object (usually an ``Error``) that can be
/// converted into a ``UserError``.
protocol UserErrorConvertible {
    var userErrorMessage: String? { get }
    var userErrorCause: (any Error)? { get }
}

extension UserErrorConvertible {
    var userError: UserError? {
        guard let message = userErrorMessage else {
            return nil
        }
        return UserError(message, cause: userErrorCause)
    }
}

extension UserErrorConvertible where Self: Error {
    var userErrorCause: (any Error)? {
        self
    }
}

extension UserError: UserErrorConvertible {
    var userErrorMessage: String? {
        message
    }

    var userErrorCause: (any Error)? {
        cause
    }
}

extension String: UserErrorConvertible {
    var userErrorMessage: String? {
        self
    }

    var userErrorCause: (any Error)? {
        nil
    }
}

extension View {
    /// Presents an alert when the given `error` binding is set.
    func alert(error: Binding<UserError?>) -> some View {
        modifier(UserErrorAlertModifier(error: error))
    }
}

/// ViewModifier that presents a system alert whenever `error` is non-nil.
///
/// Clears the binding when the user dismisses the alert so it can be triggered
/// again by subsequent errors.
private struct UserErrorAlertModifier: ViewModifier {
    @Binding var error: UserError?

    func body(content: Self.Content) -> some View {
        content
            .alert(
                "Error",
                isPresented: Binding(
                    get: { error != nil },
                    set: { isPresented, _ in
                        if !isPresented {
                            error = nil
                        }
                    }
                ),
                presenting: error,
                actions: { _ in },
                message: { error in
                    Text(error.message)
                        .onAppear { error.log() }
                }
            )
    }
}
