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
    case failure(LcpError)
    
    func get() throws -> T {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
    
    func map<V>(success: (T) -> V, failure: (LcpError) -> V) -> V {
        switch self {
        case .success(let value):
            return success(value)
        case .failure(let error):
            return failure(error)
        }
    }
    
    func map<V>(_ transform: (T) -> V) -> Result<V> {
        return map(
            success: { .success(transform($0)) },
            failure: { .failure($0) }
        )
    }
    
    func map<V>(_ transform: ((T, @escaping (Result<V>) -> Void) -> Void), _ completion: @escaping (Result<V>) -> Void) {
        map(success: { transform($0, completion) },
            failure: { completion(.failure($0)) }
        )
    }

    func completion(_ completion: (T?, LcpError?) -> Void) {
        map(success: { completion($0, nil) },
            failure: { completion(nil, $0) }
        )
    }
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
    
    static func failure(_ error: LcpError) -> DeferredResult {
        return DeferredResult { completion in
            completion(.failure(error))
        }
    }

    func resolve(_ completion: @escaping (Result<T>) -> Void) {
        assert(!resolved)
        resolved = true
        closure(completion)
    }
    
    func resolve(_ completion: @escaping (T?, LcpError?) -> Void) {
        resolve { $0.completion(completion) }
    }
    
    func map<V>(success: @escaping (T) -> V, failure: @escaping (LcpError) -> V) -> DeferredResult<V> {
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

}

/// Syntactic sugar.
func deferred<T>(_ closure: @escaping (@escaping (Result<T>) -> Void) -> Void) -> DeferredResult<T> {
    return DeferredResult(closure)
}
