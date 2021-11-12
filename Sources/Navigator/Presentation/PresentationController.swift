//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Helper class which simplifies the modification of Presentation Settings and designing a user
/// settings interface.
public final class PresentationController {
    
    public typealias OnSettingsChanged = (PresentationValues) -> PresentationValues
    
    /// Requests the navigator to activate a non-active setting when its value is changed.
    private let autoActivateOnChange: Bool
    
    private let onSettingsChanged: OnSettingsChanged?
    
    public init(
        settings: PresentationValues? = nil,
        autoActivateOnChange: Bool = true,
        onSettingsChanged: OnSettingsChanged? = nil
    ) {
        self.autoActivateOnChange = autoActivateOnChange
        self.onSettingsChanged = onSettingsChanged
    }
    
    public final class Settings {
        public let userSettings: PresentationValues
        public let actualSettings: PresentationValues
        public let presentation: Presentation
        
        public init(
            userSettings: PresentationValues,
            actualSettings: PresentationValues,
            presentation: Presentation
        ) {
            self.presentation = presentation
            self.userSettings = userSettings
            self.actualSettings = actualSettings
        }
    
        var continuous: ToggleSetting? {
            self[.continuous]
        }
        
        var fit: EnumSetting<PresentationFit>? {
            self[.fit]
        }
        
        var pageSpacing: RangeSetting? {
            self[.pageSpacing]
        }
        
        subscript<V>(_ key: PresentationKey, unwrapValue: @escaping (V) -> AnyHashable = { $0 as! AnyHashable }) -> Setting<V>? {
            let effectiveValue: V? = presentation.values[key]
            let userValue: V? = userSettings[key]
            let isSupported = (effectiveValue != nil)
            let isActive = presentation.isActive(key, for: actualSettings)
            
            guard effectiveValue != nil || userValue != nil else {
                return nil
            }
            return Setting(
                key: key,
                value: userValue,
                effectiveValue: effectiveValue,
                isSupported: isSupported,
                isActive: isActive,
                constraints: presentation.constraints(for: key),
                labelForValue: { value in
                    self.presentation.label(for: key, value: unwrapValue(value))
                }
            )
        }
        
        /// Subscript for enum values.
        subscript<E: RawRepresentable>(_ key: PresentationKey) -> EnumSetting<E>? where E.RawValue == String {
            self[key] { $0.rawValue }
        }
    }
    
    /// Holds the current value and the metadata of a Presentation Setting of type `Value`.
    public class Setting<Value> {
        public let key: PresentationKey
        public let value: Value?
        public let effectiveValue: Value?
        public let isSupported: Bool
        public let isActive: Bool
        public let constraints: PresentationValueConstraints?
        private let labelForValue: (Value) -> String
        
        public init(
            key: PresentationKey,
            value: Value?,
            effectiveValue: Value?,
            isSupported: Bool,
            isActive: Bool,
            constraints: PresentationValueConstraints?,
            labelForValue: @escaping (Value) -> String
        ) {
            self.key = key
            self.value = value
            self.effectiveValue = effectiveValue
            self.isSupported = isSupported
            self.isActive = isActive
            self.constraints = constraints
            self.labelForValue = labelForValue
        }
        
        /// Returns a user-facing localized label for the current value, which can be used in the user
        /// interface.
        ///
        /// For example, with the "reading progression" property, the value ltr has for label "Left to
        /// right" in English.
        public var label: String? {
            value.map { labelForValue($0) }
        }
        
        /// Returns a user-facing localized label for the given value, which can be used in the user
        /// interface.
        ///
        /// For example, with the "reading progression" property, the value ltr has for label "Left to
        /// right" in English.
        public func label(for value: Value) -> String {
            labelForValue(value)
        }
    }

    public typealias ToggleSetting = Setting<Bool>
    public typealias RangeSetting = Setting<Double>
    public typealias StringSetting = Setting<String>
    public typealias EnumSetting<E: RawRepresentable> = Setting<E>
}

public extension PresentationController.RangeSetting {
    var stepCount: Int? {
        (constraints as? RangePresentationValueConstraints)?.stepCount
    }
}

public extension PresentationController.StringSetting {
    var supportedValues: [String]? {
        (constraints as? StringPresentationValueConstraints)?.supportedValues
    }
}

public extension PresentationController.EnumSetting where Value.RawValue == String {
    var supportedValues: [Value]? {
        (constraints as? StringPresentationValueConstraints)?
            .supportedValues?
            .compactMap { Value(rawValue: $0) }
    }
}
