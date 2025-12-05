//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
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
            self = error.userError()
        } else {
            self.init("error".localized, cause: error)
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

    var errorDescription: String? { message }
}

/// Convenience protocol for an object (usually an ``Error``) that can be converted
/// into a ``UserError``.
protocol UserErrorConvertible {
    func userError() -> UserError
}

extension UserError: UserErrorConvertible {
    func userError() -> UserError {
        self
    }
}

extension UIViewController {
    /// Presents an alert describing the given `UserError`.
    func alert<T: UserErrorConvertible>(_ error: T) {
        let error = error.userError()

        var dumpDescription = ""
        dump(error, to: &dumpDescription)
        print(dumpDescription)

        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: error.message,
                message: dumpDescription,
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(
                title: "Close",
                style: .cancel
            ))

            self.present(alert, animated: true, completion: nil)
        }
    }
}

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    func localized(_ values: CVarArg...) -> String {
        localized(values)
    }

    func localized(_ values: [CVarArg]) -> String {
        var string = localized
        if !values.isEmpty {
            string = String(format: string, locale: Locale.current, arguments: values)
        }
        return string
    }
}
