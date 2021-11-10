//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

public typealias PresentationFit = R2Shared.Presentation.Fit
public typealias PresentationOrientation = R2Shared.Presentation.Orientation
public typealias PresentationOverflow = R2Shared.Presentation.Overflow

public struct PresentationKey: Hashable {
    public let id: String
    
    public static let continuous = PresentationKey(id: "continuous")
    public static let fit = PresentationKey(id: "fit")
    public static let orientation = PresentationKey(id: "orientation")
    public static let overflow = PresentationKey(id: "overflow")
    public static let pageSpacing = PresentationKey(id: "pageSpacing")
    public static let readingProgression = PresentationKey(id: "readingProgression")
}

/// Holds a list of key-value pairs provided by the app to influence a Navigator's Presentation
/// Properties. The keys must be valid Presentation Keys.
public struct PresentationSettings: Hashable {
    public var settings: [PresentationKey: AnyHashable] = [:]
    
    public var continuous: Bool? {
        settings[.continuous] as? Bool
    }
    
    public var fit: R2Shared.Presentation.Fit? {
        (settings[.fit] as? String)
            .flatMap(R2Shared.Presentation.Fit.init(rawValue:))
    }
    
    public var orientation: R2Shared.Presentation.Orientation? {
        (settings[.orientation] as? String)
            .flatMap(R2Shared.Presentation.Orientation.init(rawValue:))
    }
    
    public var overflow: R2Shared.Presentation.Overflow? {
        (settings[.overflow] as? String)
            .flatMap(R2Shared.Presentation.Overflow.init(rawValue:))
    }
    
    public var pageSpacing: Double? {
        settings[.pageSpacing] as? Double
    }
    
    public var readingProgression: ReadingProgression? {
        (settings[.readingProgression] as? String)
            .flatMap(ReadingProgression.init(rawValue:))
    }
    
    /// Returns a copy of this object after overwriting any setting with the values from `other`.
    public func merging(_ other: PresentationSettings) -> PresentationSettings {
        PresentationSettings(settings: settings.merging(other.settings, uniquingKeysWith: { first, second in second }))
    }
}

/// Holds the current values for the Presentation Properties determining how a publication is
/// rendered by a Navigator. For example, "font size" or "playback rate".
public protocol Presentation {
    
    var properties: [PresentationKey: AnyHashable] { get }
    
    /// Returns a user-facing localized label for the given value, which can be used in the user
    /// interface.
    ///
    /// For example, with the "reading progression" property, the value ltr has for label "Left to
    /// right" in English.
    func label(for key: PresentationKey, value: AnyHashable) -> String
    
    /// Determines whether a given property will be active when the given settings are applied to the
    /// Navigator.
    ///
    /// For example, with an EPUB Navigator using Readium CSS, the property "letter spacing" requires
    /// to switch off the "publisher defaults" setting to be active.
    ///
    /// This is useful to determine whether to grey out a view in the user settings interface.
    func isPropertyActive(_ key: PresentationKey, for settings: PresentationSettings) -> Bool
    
    /// Modifies the given settings to make sure the property will be activated when applying them to
    /// the Navigator.
    ///
    /// For example, with an EPUB Navigator using Readium CSS, activating the "letter spacing"
    /// property means ensuring the "publisher defaults" setting is disabled.
    ///
    /// If the property cannot be activated, returns a user-facing localized error.
    func activateProperty(_ key: PresentationKey, in settings: PresentationSettings) throws -> PresentationSettings
    
    func stepCount(forRange key: PresentationKey) -> Int?
    
    func supportedValues(forString key: PresentationKey) -> [String]?
}

public extension Presentation {
    
    var continuous: TogglePresentationProperty? {
        toggleProperty(for: .continuous)
    }
    
    var fit: EnumPresentationProperty<PresentationFit>? {
        enumProperty(for: .fit)
    }
    
    func toggleProperty(for key: PresentationKey) -> TogglePresentationProperty? {
        guard let bool = properties[key] as? Bool else {
            return nil
        }
        return PresentationProperty(key: key, value: bool, presentation: self)
    }
    
    func enumProperty<E: RawRepresentable>(for key: PresentationKey) -> EnumPresentationProperty<E>? where E.RawValue == String {
        guard let string = properties[key] as? String else {
            return nil
        }
        let value = E(rawValue: string)!
        return PresentationProperty(key: key, value: value, unwrapValue: { $0.rawValue }, presentation: self)
    }
}

public struct PresentationProperty<Value> {
    public let key: PresentationKey
    public let value: Value
    
    private let unwrapValue: (Value) -> AnyHashable
    private let presentation: Presentation
    
    public init(
        key: PresentationKey,
        value: Value,
        unwrapValue: @escaping (Value) -> AnyHashable = { $0 as! AnyHashable },
        presentation: Presentation
    ) {
        self.key = key
        self.value = value
        self.unwrapValue = unwrapValue
        self.presentation = presentation
    }
    
    /// Returns a user-facing localized label for the current value, which can be used in the user
    /// interface.
    ///
    /// For example, with the "reading progression" property, the value ltr has for label "Left to
    /// right" in English.
    public var label: String {
        label(for: value)
    }
    
    /// Returns a user-facing localized label for the given value, which can be used in the user
    /// interface.
    ///
    /// For example, with the "reading progression" property, the value ltr has for label "Left to
    /// right" in English.
    public func label(for value: Value) -> String {
        presentation.label(for: key, value: unwrapValue(value))
    }
    
    /// Determines whether the property will be active when the given settings are applied to the
    /// Navigator.
    ///
    /// For example, with an EPUB Navigator using Readium CSS, the property "letter spacing" requires
    /// to switch off the "publisher defaults" setting to be active.
    ///
    /// This is useful to determine whether to grey out a view in the user settings interface.
    func isActive(for settings: PresentationSettings) -> Bool {
        presentation.isPropertyActive(key, for: settings)
    }
    
    /// Modifies the given settings to make sure the property will be activated when applying them to
    /// the Navigator.
    ///
    /// For example, with an EPUB Navigator using Readium CSS, activating the "letter spacing"
    /// property means ensuring the "publisher defaults" setting is disabled.
    ///
    /// If the property cannot be activated, returns a user-facing localized error.
    func activate(in settings: PresentationSettings) throws -> PresentationSettings {
        try presentation.activateProperty(key, in: settings)
    }
}

public typealias TogglePresentationProperty = PresentationProperty<Bool>
public extension TogglePresentationProperty {
    
    var stepCount: Int? {
        presentation.stepCount(forRange: key)
    }
}

public typealias StringPresentationProperty = PresentationProperty<String>
public extension StringPresentationProperty {
    
    var supportedValues: [String]? {
        presentation.supportedValues(forString: key)
    }
}

public typealias EnumPresentationProperty<E: RawRepresentable> = PresentationProperty<E>

public extension EnumPresentationProperty where Value.RawValue == String {
    
    var supportedValues: [Value]? {
        presentation.supportedValues(forString: key)?
            .compactMap { Value(rawValue: $0) }
    }
}
