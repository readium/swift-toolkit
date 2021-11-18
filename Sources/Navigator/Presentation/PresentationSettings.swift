//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// Helper class which simplifies the modification of Presentation Settings and designing a user
/// settings interface.
public final class PresentationSettings: Loggable {
    
    public typealias OnChanged = () -> Void
    public typealias OnAdjust = (PresentationValues) -> PresentationValues
    
    /// Requests the navigator to activate a non-active setting when its value is changed.
    public var autoActivateOnChange: Bool
    
    private let onChanged: OnChanged
    private let onAdjust: OnAdjust
    
    public var values: ObservableVariable<PresentationValues> { _values }
    private let _values: MutableObservableVariable<PresentationValues>
    
    private weak var navigator: PresentableNavigator?
    private var subscriptions: [R2Shared.Cancellable] = []
        
    private var adjustedValues: PresentationValues {
        onAdjust(values.get())
    }

    public init(
        navigator: PresentableNavigator,
        settings: PresentationValues? = nil,
        autoActivateOnChange: Bool = true,
        onAdjust: @escaping OnAdjust = { $0 },
        onChanged: @escaping OnChanged = {}
    ) {
        self.navigator = navigator
        self._values = MutableObservableVariable(settings ?? PresentationValues())
        self.autoActivateOnChange = autoActivateOnChange
        self.onAdjust = onAdjust
        self.onChanged = onChanged
        
        navigator.presentation
            .subscribe { [weak self] _ in
                self?.didChange()
            }
            .store(in: &subscriptions)
        
        values
            .subscribe(on: .main) { [weak self] _ in
                self?.didChange()
            }
            .store(in: &subscriptions)
    }
    
    private func didChange() {
        self.onChanged()
        
        if #available(iOS 13.0, *) {
            objectWillChange.send()
        }
    }
    
    /// Applies the current set of settings to the Navigator.
    public func commit(changes: (PresentationSettings) -> Void = { _ in }) {
        changes(self)
        navigator?.apply(presentationSettings: adjustedValues)
    }
    
    /// Clears all user settings to revert to the Navigator default values or the given ones.
    public func reset(_ settings: PresentationValues = PresentationValues()) {
        _values.set(settings)
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
        set(setting.key, to: value)
    }
    
    public func set<T: RawRepresentable>(_ setting: Setting<T>?, to value: T?) where T.RawValue == String {
        guard let setting = setting else {
            return
        }
        set(setting.key, to: value?.rawValue)
    }
    
    private func set<T>(_ key: PresentationKey, to value: T?) {
        _values.set { values in
            values[key] = value
        
            if autoActivateOnChange, let presentation = navigator?.presentation.get() {
                do {
                    values = try presentation.activate(key, in: values)
                } catch {
                    self.log(.warning, error)
                }
            }
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
    public func toggle<T: Equatable>(_ setting: Setting<T>?, value: T?) {
        guard let setting = setting else {
            return
        }
        if (setting.value == value) {
            reset(setting)
        } else {
            set(setting, to: value)
        }
    }
    
    /// Inverts the value of the given setting. If the setting is already set to the given value, it is nulled out.
    public func toggle<T: RawRepresentable & Equatable>(_ setting: Setting<T>?, value: T?) where T.RawValue == String {
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

    public var continuous: ToggleSetting? { self[.continuous] }
    public var fit: EnumSetting<PresentationFit>? { self[.fit] }
    public var overflow: EnumSetting<PresentationOverflow>? { self[.overflow] }
    public var pageSpacing: RangeSetting? { self[.pageSpacing] }
    public var readingProgression: EnumSetting<ReadingProgression>? { self[.readingProgression] }
    public var showScrollbar: ToggleSetting? { self[.showScrollbar] }
    public var spread: EnumSetting<PresentationSpread>? { self[.spread] }
    
    subscript<V>(_ key: PresentationKey) -> Setting<V>? {
        let presentation = navigator?.presentation.get()
        let effectiveValue: V? = presentation?.values[key]
        let value: V? = values.get()[key]
        let isSupported = (effectiveValue != nil)
        let isActive = presentation?.isActive(key, for: adjustedValues) ?? false
        
        guard effectiveValue != nil || value != nil else {
            return nil
        }
        return Setting(
            key: key,
            value: value,
            effectiveValue: effectiveValue,
            isSupported: isSupported,
            isActive: isActive,
            constraints: presentation?.constraints(for: key),
            labelForValue: { value in
                guard let value = value as? AnyHashable else {
                    return nil
                }
                return presentation?.label(for: key, value: value)
            }
        )
    }
    
    /// Subscript for enum values.
    subscript<E: RawRepresentable>(_ key: PresentationKey) -> EnumSetting<E>? where E.RawValue == String {
        let presentation = navigator?.presentation.get()
        let effectiveValue: E? = presentation?.values[key]
        let value: E? = values.get()[key]
        let isSupported = (effectiveValue != nil)
        let isActive = presentation?.isActive(key, for: adjustedValues) ?? false
        
        guard effectiveValue != nil || value != nil else {
            return nil
        }
        return Setting(
            key: key,
            value: value,
            effectiveValue: effectiveValue,
            isSupported: isSupported,
            isActive: isActive,
            constraints: presentation?.constraints(for: key),
            labelForValue: { value in
                presentation?.label(for: key, value: value.rawValue)
            }
        )
    }
    
    /// Holds the current value and the metadata of a Presentation Setting of type `Value`.
    public struct Setting<Value> {
        public let key: PresentationKey
        public let value: Value?
        public let effectiveValue: Value?
        public let isSupported: Bool
        public let isActive: Bool
        public let constraints: PresentationValueConstraints?
        private let labelForValue: (Value) -> String?
        
        public init(
            key: PresentationKey,
            value: Value?,
            effectiveValue: Value?,
            isSupported: Bool,
            isActive: Bool,
            constraints: PresentationValueConstraints?,
            labelForValue: @escaping (Value) -> String?
        ) {
            self.key = key
            self.value = value
            self.effectiveValue = effectiveValue
            self.isSupported = isSupported
            self.isActive = isActive
            self.constraints = constraints
            self.labelForValue = labelForValue
        }
        
        /// Returns a user-facing localized label for the given value, which can be used in the user
        /// interface.
        ///
        /// For example, with the "reading progression" property, the value ltr has for label "Left to
        /// right" in English.
        public func label(for value: Value?) -> String? {
            guard let value = value else {
                return nil
            }
            return labelForValue(value)
        }
    }

    public typealias ToggleSetting = Setting<Bool>
    public typealias RangeSetting = Setting<Double>
    public typealias StringSetting = Setting<String>
    public typealias EnumSetting<E: RawRepresentable & Equatable> = Setting<E>
}

public extension PresentationSettings.RangeSetting {
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

public extension PresentationSettings.StringSetting {
    var supportedValues: [String]? {
        (constraints as? StringPresentationValueConstraints)?.supportedValues
    }
    
    func isSupported(value: String?) -> Bool {
        guard let value = value else {
            return true
        }
        return supportedValues?.contains(value) ?? true
    }
}

public extension PresentationSettings.EnumSetting where Value.RawValue == String {
    var supportedValues: [Value]? {
        (constraints as? EnumPresentationValueConstraints<Value>)?
            .supportedValues
    }
    
    func isSupported(value: Value?) -> Bool {
        guard let value = value else {
            return true
        }
        return supportedValues?.contains(value) ?? true
    }
}

private extension Double {
    func rounded(toStep step: Double) -> Double {
        (self / step).rounded() * step
    }
}

#if canImport(Combine)
import Combine

@available(iOS 13.0, *)
extension PresentationSettings: ObservableObject {}
#endif
