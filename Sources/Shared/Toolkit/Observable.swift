//
//  Observable.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 26.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// Holds an observable value.
/// You can either get the value directly with `value`, or subscribe to its updates with `observe`.
public class Observable<T> {
    
    fileprivate var _value: T {
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
    
    public init(_ value: T) {
        self._value = value
    }
    
    public var value: T {
        return _value
    }
    
    private var observers = [(T) -> Void]()
    
    public func observe(_ observer: @escaping (T) -> Void) {
        observers.append(observer)
        observer(value)
    }
    
    /// Forwards the value to the given mutable observable.
    public func observe(_ observable: MutableObservable<T>) {
        observe { value in
            observable.value = value
        }
    }

}


public class MutableObservable<T>: Observable<T> {
    
    public override var value: T {
        get {
            return _value
        }
        set {
            pthread_mutex_lock(&lock)
            _value = newValue
            pthread_mutex_unlock(&lock)
        }
    }

}
