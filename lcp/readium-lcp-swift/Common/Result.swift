//
//  Result.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 04.02.19.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

enum Result<T> {
    case success(T)
    case failure(LCPError)
    
    func get() throws -> T {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
    
    var error: LCPError? {
        return map(
            success: { _ in nil },
            failure: { $0 }
        )
    }
    
    /// Maps a result's value or error to another identical type.
    func map<V>(success: (T) -> V, failure: (LCPError) -> V) -> V {
        switch self {
        case .success(let value):
            return success(value)
        case .failure(let error):
            return failure(error)
        }
    }
    
    /// Transforms a result's value, or forwards its error.
    func map<V>(_ transform: (T) throws -> V) -> Result<V> {
        return map(
            success: {
                do {
                    return .success(try transform($0))
                } catch {
                    return .failure(LCPError.wrap(error))
                }
            },
            failure: { .failure($0) }
        )
    }
    
    /// Calls an asynchronous closure with the result's value and forwards the completion handler with the transformed result.
    func map<V>(_ transform: ((T, @escaping (Result<V>) -> Void) -> Void), _ completion: @escaping (Result<V>) -> Void) {
        map(success: { transform($0, completion) },
            failure: { completion(.failure($0)) }
        )
    }
    
    /// Attempts to recover a result's error.
    /// Throw another (or the same) error in the recover closure if it fails.
    func `catch`(_ recover: @escaping (LCPError) throws -> T) -> Result<T> {
        return map(
            success: { .success($0) },
            failure: {
                do {
                    return .success(try recover($0))
                } catch {
                    return .failure(LCPError.wrap(error))
                }
            }
        )
    }

    /// Calls the given classical completion closure with the result's value and error.
    func send(to completion: (T?, LCPError?) -> Void) {
        map(success: { completion($0, nil) },
            failure: { completion(nil, $0) }
        )
    }
    
}


/// Monad-like encapsulation of an asynchronous Result.
/// This is NOT a Promise implementation, because much more lightweight and not thread-safe. It's only meant to flatten in-place a group of Result completion-based calls into a monadic chain.
/// It works with regular functions taking completion closures, so not too invasive. Only the call site knows about DeferredResult and it doesn't leak throughout the codebase.
///
/// eg.
/// fetchFoo { result1 in
///     switch result1 {
///     case .success(let val1):
///         parseBar(val1) {
///             switch result2 {
///             case .success(let val2):
///                 processThing(val2, completion)
///             case .failure(let err):
///                 completion(.failure(err))
///         }
///     case .failure(let err):
///         completion(.failure(err))
/// }
///
/// becomes:
///
/// deferred { fetchFoo($0) }
///     .map { parseBar($0, $1) }
///     .map { processThing($0, $1) }
///     .map { val in val + 100 }  // Can also replace synchronously a Result value
///     .resolve(completion)
///

/// Syntactic sugar.
func deferred<T>(_ closure: @escaping (@escaping (Result<T>) -> Void) -> Void) -> DeferredResult<T> {
    return DeferredResult(closure)
}

final class DeferredResult<T> {
    
    private let closure: (@escaping (Result<T>) -> Void) -> Void
    private var resolved: Bool = false
    
    init(_ closure: @escaping (@escaping (Result<T>) -> Void) -> Void) {
        self.closure = closure
    }

    /// Resolves the result and send it back to the given completion closure.
    func resolve(_ completion: ((Result<T>) -> Void)? = nil) {
        assert(!resolved, "DeferredResult doesn't cache the closure's value. It must only be called once.")
        resolved = true
        closure(completion ?? { _ in })
    }
    
    /// Resolves the result and send it back to the given classical completion closure.
    func resolve(_ completion: @escaping (T?, LCPError?) -> Void) {
        resolve { $0.send(to: completion) }
    }
    
    /// Wraps the deferred result in another deferred task that will use the value of the wrapped result, or forward its error.
    private func wrap<V>(_ wrapper: @escaping (Result<T>, @escaping (Result<V>) -> Void) -> Void) -> DeferredResult<V> {
        return DeferredResult<V> { completion in
            self.resolve { result in
                wrapper(result, completion)
            }
        }
    }
    
    func map<V>(success: @escaping (T) -> V, failure: @escaping (LCPError) -> V) -> DeferredResult<V> {
        return wrap { result, completion in
            let mappedResult = result.map(success: success, failure: failure)
            completion(.success(mappedResult))
        }
    }

    func map<V>(_ transform: @escaping (T) throws -> V) -> DeferredResult<V> {
        return wrap { result, completion in
            completion(result.map(transform))
        }
    }
    
    func map<V>(_ transform: @escaping (T, @escaping (Result<V>) -> Void) -> Void) -> DeferredResult<V> {
        return wrap { result, completion in
            result.map(transform, completion)
        }
    }

    func `catch`(_ recover: @escaping (LCPError) throws -> T) -> DeferredResult<T> {
        return wrap { result, completion in
            completion(result.catch(recover))
        }
    }

}
