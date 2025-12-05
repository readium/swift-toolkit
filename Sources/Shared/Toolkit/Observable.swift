//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Holds an observable value.
/// You can either get the value directly with `value`, or subscribe to its updates with `observe`.
public class Observable<Value> {
    fileprivate var _value: Value {
        didSet {
            for observer in observers {
                observer(_value)
            }
        }
    }

    fileprivate lazy var lock: pthread_mutex_t = {
        var lock = pthread_mutex_t()
        pthread_mutex_init(&lock, nil)
        return lock
    }()

    public init(_ value: Value) {
        _value = value
    }

    public var value: Value {
        _value
    }

    private var observers = [(Value) -> Void]()

    public func observe(_ observer: @escaping (Value) -> Void) {
        observers.append(observer)
        observer(value)
    }

    /// Forwards the value to the given mutable observable.
    public func observe(_ observable: MutableObservable<Value>) {
        observe { value in
            observable.value = value
        }
    }
}

public class MutableObservable<Value>: Observable<Value> {
    override public var value: Value {
        get {
            _value
        }
        set {
            pthread_mutex_lock(&lock)
            _value = newValue
            pthread_mutex_unlock(&lock)
        }
    }
}
