//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// Helper class which simplifies the modification of Presentation Settings and designing a user
/// settings interface.
public final class PresentationController: Loggable {
    
    public typealias OnSettingsChanged = (PresentationValues) -> PresentationValues
    
    /// Requests the navigator to activate a non-active setting when its value is changed.
    private let autoActivateOnChange: Bool
    
    private let onSettingsChanged: OnSettingsChanged?
    
    public var settings: ObservableVariable<Settings> { _settings }
    private let _settings: MutableObservableVariable<Settings>
    
    private weak var navigator: PresentableNavigator?
    private var presentationSubscription: Cancellable?
    
    public init(
        navigator: PresentableNavigator,
        settings: PresentationValues? = nil,
        autoActivateOnChange: Bool = true,
        onSettingsChanged: OnSettingsChanged? = nil
    ) {
        self.navigator = navigator
        self.autoActivateOnChange = autoActivateOnChange
        self.onSettingsChanged = onSettingsChanged
        
        let userSettings = settings ?? PresentationValues()
        let actualSettings = onSettingsChanged?(userSettings) ?? userSettings
        _settings = MutableObservableVariable(Settings(
            userSettings: userSettings,
            actualSettings: actualSettings,
            presentation: NullPresentation()
        ))
       
        navigator.apply(presentationSettings: actualSettings) { _ in }
        
        navigator.presentation
            .subscribe { [weak self] presentation in
                self?._settings.set { $0.copy(presentation: presentation) }
            }
            .store(in: &presentationSubscription)
    }
    
    /// Applies the current set of settings to the Navigator.
    public func commit(changes: (PresentationController, Settings) -> Void = { _, _ in }, completion: @escaping () -> Void = {}) {
        changes(self, settings.get())
        
        navigator?.apply(
            presentationSettings: settings.get().actualSettings,
            completion: { _ in completion() }
        )
    }
    
    /// Clears all user settings to revert to the Navigator default values or the given ones.
    public func reset(_ settings: PresentationValues = PresentationValues()) {
        let actualSettings = onSettingsChanged?(settings) ?? settings
        
        _settings.set {
            $0.copy(
                userSettings: settings,
                actualSettings: actualSettings
            )
        }
    }
    
    /// Clears the given user setting to revert to the Navigator default value.
    public func reset<T>(_ setting: Setting<T>?) {
        set(setting, to: nil)
    }
    
    /// Changes the value of the given setting.
    public func set<T>(_ setting: Setting<T>?, to value: T?) {
        guard let setting = setting else {
            return
        }
        
        _settings.set { settings in
            var userSettings = settings.userSettings
            userSettings[setting.key] = value
            
            if (autoActivateOnChange) {
                do {
                    userSettings = try settings.presentation.activate(setting.key, in: userSettings)
                } catch {
                    self.log(.warning, error)
                }
            }
            
            return settings.copy(
                userSettings: userSettings,
                actualSettings: onSettingsChanged?(userSettings) ?? userSettings
            )
        }
    }
    
    /// Inverts the value of the given toggle setting.
    public func toggle(_ setting: ToggleSetting?) {
        guard let setting = setting else {
            return
        }
        set(setting, to: !(setting.value ?? setting.effectiveValue ?? false))
    }
    
    /// Inverts the value of the given setting. If the setting is already set to the given value, it is nulled out.
    public func toggle<T: Equatable>(_ setting: Setting<T>?, value: T) {
        guard let setting = setting else {
            return
        }
        if (setting.value == value) {
            reset(setting)
        } else {
            set(setting, to: value)
        }
    }
    
    /// Increments the value of the given range setting to the next effective step.
    public func increment(_ setting: RangeSetting?) {
        guard let setting = setting else {
            return
        }
        let step = setting.step
        let value = setting.value ?? setting.effectiveValue ?? 0.5
        
        set(setting, to: min(1.0, (value + step).rounded(toStep: step)))
    }
    
    /// Decrements the value of the given range setting to the previous effective step.
    public func decrement(_ setting: RangeSetting?) {
        guard let setting = setting else {
            return
        }
        let step = setting.step
        let value = setting.value ?? setting.effectiveValue ?? 0.5
        
        set(setting, to: max(0.0, (value - step).rounded(toStep: step)))
    }
    
    public struct Settings {
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
        
        public func copy(
            userSettings: PresentationValues? = nil,
            actualSettings: PresentationValues? = nil,
            presentation: Presentation? = nil
        ) -> Settings {
            Settings(
                userSettings: userSettings ?? self.userSettings,
                actualSettings: actualSettings ?? self.actualSettings,
                presentation: presentation ?? self.presentation
            )
        }
    
        public var continuous: ToggleSetting? { self[.continuous] }
        public var fit: EnumSetting<PresentationFit>? { self[.fit] }
        public var pageSpacing: RangeSetting? { self[.pageSpacing] }
        
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
    public struct Setting<Value> {
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
    
    var step: Double {
        guard let stepCount = stepCount, stepCount > 0 else {
            return 0.1
        }
        return 1.0 / Double(stepCount)
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

private extension Double {
    func rounded(toStep step: Double) -> Double {
        (self / step).rounded() * step
    }
}
