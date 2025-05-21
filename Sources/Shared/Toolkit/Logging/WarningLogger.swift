//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Interface to be implemented by third-party apps if they want to observe warnings raised,
/// for example, during the parsing of a `Publication`.
public protocol WarningLogger {
    /// Notifies that a warning occurred.
    func log(_ warning: Warning)
}

/// Represents a non-fatal warning message that can be raised by a Readium library.
///
/// For example, while parsing an EPUB we, might want to report issues in the publication without
/// failing the whole parsing.
public protocol Warning {
    /// Tag used to group similar warnings together.
    /// For example `json`, `metadata`, etc.
    var tag: String { get }

    /// Localized user-facing message describing the issue.
    var message: String { get }

    /// Indicates the severity level of this warning.
    var severity: WarningSeverityLevel { get }
}

/// Indicates how the user experience might be affected by a warning.
public enum WarningSeverityLevel {
    /// The user probably won't notice the issue.
    case minor
    /// The user experience might be affected, but it shouldn't prevent the user from enjoying the
    /// publication.
    case moderate
    /// The user experience will most likely be disturbed, for example with rendering issues.
    case major
}

/// Warning raised when parsing a model object from its JSON representation fails.
public struct JSONWarning: Warning {
    /// Type of the model object to be parsed.
    public let modelType: Any.Type
    /// Details about the failure.
    public let reason: String
    /// Source JSON object.
    public let source: Any?
    public let severity: WarningSeverityLevel
    public var tag: String { "json" }

    public var message: String {
        "JSON \(modelType): \(reason)"
    }
}

extension WarningLogger {
    func log(_ reason: String, model: Any.Type, source: Any? = nil, severity: WarningSeverityLevel = .major) {
        log(JSONWarning(modelType: model, reason: reason, source: source, severity: severity))
    }
}

/// Implementation of a `WarningLogger` which accumulates the warnings in a list, to be used as a
/// convenience by reading apps.
public final class ListWarningLogger: WarningLogger {
    /// The list of accumulated `Warning`s.
    private(set) var warnings: [Warning] = []

    public func log(_ warning: Warning) {
        warnings.append(warning)
    }
}

/// Default implementation for any `Loggable` conforming to `WarningLogger`.
public extension WarningLogger where Self: Loggable {
    func log(_ warning: Warning) {
        let level: SeverityLevel = {
            switch warning.severity {
            case .minor:
                return .info
            case .moderate:
                return .warning
            case .major:
                return .error
            }
        }()
        log(level, warning.message)
    }
}
