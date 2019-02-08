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
    
    func map<V>(success: (T) -> V, failure: (LCPError) -> V) -> V {
        switch self {
        case .success(let value):
            return success(value)
        case .failure(let error):
            return failure(error)
        }
    }
    
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
    
    func map<V>(_ transform: ((T, @escaping (Result<V>) -> Void) -> Void), _ completion: @escaping (Result<V>) -> Void) {
        map(success: { transform($0, completion) },
            failure: { completion(.failure($0)) }
        )
    }

    func completion(_ completion: (T?, LCPError?) -> Void) {
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
    
    static func success<T>(_ value: T) -> DeferredResult<T> {
        return DeferredResult<T> { completion in
            completion(.success(value))
        }
    }
    
    static func failure(_ error: LCPError) -> DeferredResult {
        return DeferredResult { completion in
            completion(.failure(error))
        }
    }

    func resolve(_ completion: ((Result<T>) -> Void)? = nil) {
        assert(!resolved, "DeferredResult doesn't cache the closure's value. It must only be called once.")
        resolved = true
        closure(completion ?? { _ in })
    }
    
    func resolve(_ completion: @escaping (T?, LCPError?) -> Void) {
        resolve { $0.completion(completion) }
    }
    
    func map<V>(success: @escaping (T) -> V, failure: @escaping (LCPError) -> V) -> DeferredResult<V> {
        return DeferredResult<V> { completion in
            self.resolve { result in
                let mappedResult = result.map(success: success, failure: failure)
                completion(.success(mappedResult))
            }
        }
    }

    func map<V>(_ transform: @escaping (T) -> V) -> DeferredResult<V> {
        return DeferredResult<V> { completion in
            self.resolve { result in
                switch result {
                case .success(let value):
                    completion(.success(transform(value)))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func map<V>(_ transform: @escaping (T, @escaping (Result<V>) -> Void) -> Void) -> DeferredResult<V> {
        return DeferredResult<V> { completion in
            self.resolve { result in
                switch result {
                case .success(let value):
                    transform(value, completion)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func map<V>(_ transform: @escaping (T) throws -> V) -> DeferredResult<V> {
        return DeferredResult<V> { completion in
            self.resolve { result in
                switch result {
                case .success(let value):
                    do {
                        completion(.success(try transform(value)))
                    } catch {
                        completion(.failure(LCPError.wrap(error)))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func map<V>(_ transform: @escaping (T) -> DeferredResult<V>) -> DeferredResult<V> {
        return DeferredResult<V> { completion in
            self.resolve { result in
                switch result {
                case .success(let value):
                    transform(value).resolve(completion)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func `catch`(_ transform: @escaping(LCPError) throws -> T) -> DeferredResult<T> {
        return DeferredResult<T> { completion in
            self.resolve { result in
                switch result {
                case .success(let value):
                    completion(.success(value))
                case .failure(let error):
                    do {
                        completion(.success(try transform(error)))
                    } catch {
                        completion(.failure(LCPError.wrap(error)))
                    }
                }
            }
        }
    }

}
