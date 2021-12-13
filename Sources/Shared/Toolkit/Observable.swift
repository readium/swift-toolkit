//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation


/// Represents an observable stream of value.
///
/// This lightweight implementation of reactive programming will ease the transition to Combine
/// when bumping the minimum deployment target to iOS 13. If your app already uses Combine,
/// you can convert an `Observable` to a publisher with `publisher()`.
///
/// This "abstract" class needs to be overriden to actually send values.
public class Observable<Value> {
    
    public typealias Observer = (Value) -> Void
    
    /// Subscribes a new `observer` to be called when emitting new values.
    ///
    /// The observer will be called on the `queue` when given, or synchronously otherwise.
    ///
    /// - Returns: A `Cancellable` object which will automatically remove the subscription when deallocated.
    public func subscribe(on queue: DispatchQueue? = nil, observer: @escaping Observer) -> Cancellable {
        lock.lock()
        defer { lock.unlock() }
        
        lastObserverId += 1
        let id = lastObserverId
        observers[id] = (observer, queue)
        
        return CancellableObject { [weak self] in
            self?.lock.lock()
            defer { self?.lock.unlock() }
            self?.observers.removeValue(forKey: id)
        }.cancelOnDeinit()
    }
    
    private var lastObserverId: Int = -1
    private var observers: [Int: (Observer, DispatchQueue?)] = [:]
    
    fileprivate let lock = NSRecursiveLock()
    
    /// Broadcasts a new value to the observers.
    /// To be called from subclasses.
    fileprivate func emit(_ value: Value) {
        for (_, (observer, queue)) in observers {
            if let queue = queue {
                queue.async {
                    observer(value)
                }
            } else {
                observer(value)
            }
        }
    }
    
    // MARK: Map
    
    /// Returns a new `Observable` object which transforms every emitted upstream values.
    public func map<NewValue>(_ transform: @escaping (Value) -> NewValue) -> Observable<NewValue> {
        MapObservable(observable: self, transform: transform)
    }
    
    // MARK: Bindings
    
    /// Updates the given keypath when the observable emits a new value.
    public func assign<T>(to keyPath: ReferenceWritableKeyPath<T, Value>, on object: T) -> Cancellable {
        subscribe { value in
            object[keyPath: keyPath] = value
        }
    }

    /// Updates the given mutable `variable` when the observable emits a new value.
    public func assign(to variable: MutableObservableVariable<Value>) -> Cancellable {
        subscribe { value in
            variable.set(value)
        }
    }
    
    // MARK: Deprecated
    
    /// This is to keep backward compatibility with observe() which was not
    /// returning any `Cancellable`.
    private var subscriptions: [Cancellable] = []
    
    @available(*, deprecated, renamed: "subscribe")
    public func observe(_ observer: @escaping (Value) -> Void) {
        subscribe(observer: observer)
            .store(in: &subscriptions)
    }
    
    /// Forwards the value to the given mutable observable.
    @available(*, deprecated, renamed: "bind")
    public func observe(_ observable: MutableObservable<Value>) {
        observe { value in
            observable.value = value
        }
    }
}

/// Represents a read-only value whose changes can be observed.
///
/// For a mutable version, see `MutableObservableVariable`.
public class ObservableVariable<Value>: Observable<Value> {
    
    /// Returns the current value.
    public func get() -> Value { _value }
    
    public init(_ value: Value) {
        self._value = value
    }
    
    fileprivate var _value: Value {
        didSet { emit(_value) }
    }
    
    public override func subscribe(on queue: DispatchQueue? = nil, observer: @escaping Observer) -> Cancellable {
        // Sends the current value to the observer.
        observer(get())
        return super.subscribe(on: queue, observer: observer)
    }
    
    @available(*, deprecated, renamed: "get")
    public var value: Value { self.get() }
}

@available(*, deprecated, renamed: "MutableObservableVariable")
public typealias MutableObservable = MutableObservableVariable

/// Represents a mutable value whose changes can be observed.
public class MutableObservableVariable<Value>: ObservableVariable<Value> {
    
    /// Updates the current value.
    public func set(_ value: Value) {
        lock.lock()
        defer { lock.unlock() }
        _value = value
    }
    
    /// Updates the current value after transforming the current one.
    @discardableResult
    public func set(_ transform: (inout Value) -> Void) -> Value {
        lock.lock()
        defer { lock.unlock() }
        transform(&_value)
        return _value
    }
    
    public override var value: Value {
        @available(*, deprecated, renamed: "get")
        get { _value }
        @available(*, deprecated, renamed: "set")
        set { set(newValue) }
    }
}

/// Transforms the value emitted by a wrapped observable.
private class MapObservable<OldValue, NewValue>: Observable<NewValue> {
    
    private let transform: (OldValue) -> NewValue
    private var subscription: Cancellable? = nil
    
    init(observable: Observable<OldValue>, transform: @escaping (OldValue) -> NewValue) {
        self.transform = transform
        super.init()
        
        subscription = observable.subscribe { [weak self] value in
            self?.emit(transform(value))
        }
    }
}
