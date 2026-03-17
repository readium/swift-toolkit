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
    let message: String
    let cause: Error?

    init(_ error: Error) {
        if let error = error as? UserErrorConvertible {
            self = error.userError
        } else {
            self.init(error.localizedDescription, cause: error)
        }
    }

    init(
        _ message: String,
        cause: Error? = nil
    ) {
        self.message = message
        self.cause = cause
    }

    init(
        cause: Error? = nil,
        message: () -> String
    ) {
        self.init(message(), cause: cause)
    }

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
    var message: String { get }
    var cause: (any Error)? { get }
}

extension UserErrorConvertible {
    var userError: UserError {
        UserError(message, cause: cause)
    }
}

extension UserErrorConvertible where Self: Error {
    var cause: Error? {
        self
    }
}

extension UserError: UserErrorConvertible {}

extension String: UserErrorConvertible {
    var message: String {
        self
    }

    var cause: (any Error)? {
        nil
    }
}

extension View {
    /// Presents an alert when the given `error` binding is set.
    func alert(error: Binding<UserError?>) -> some View {
        modifier(UserErrorAlertModifier(error: error))
    }
}

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
