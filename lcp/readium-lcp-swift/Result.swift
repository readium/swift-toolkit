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
import PromiseKit

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
    
    func map<V>(_ transform: (T) -> V) -> Result<V> {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func map<V>(_ transform: ((T, @escaping (Result<V>) -> Void) -> Void), _ completion: @escaping (Result<V>) -> Void) {
        switch self {
        case .success(let value):
            transform(value, completion)
        case .failure(let error):
            completion(.failure(error))
        }
    }
    
    func completion(_ completion: (T?, LcpError?) -> Void) {
        var value: T?
        var error: LcpError?
        switch self {
        case .success(let v):
            value = v
        case .failure(let err):
            error = err
        }
        completion(value, error)
    }
}

struct AsyncResult<T> {
    
    private let closure: (@escaping (Result<T>) -> Void) -> Void
    
    init(_ closure: @escaping (@escaping (Result<T>) -> Void) -> Void) {
        self.closure = closure
    }
    
    static func success<T>(_ value: T) -> AsyncResult<T> {
        return AsyncResult<T> { completion in
            completion(.success(value))
        }
    }
    
    static func failure(_ error: LcpError) -> AsyncResult {
        return AsyncResult { completion in
            completion(.failure(error))
        }
    }

    func resolve(_ completion: @escaping (Result<T>) -> Void) {
        closure(completion)
    }
    
    func resolve(_ completion: @escaping (T?, LcpError?) -> Void) {
        resolve { $0.completion(completion) }
    }

    func map<V>(_ transform: @escaping (T) -> V) -> AsyncResult<V> {
        return AsyncResult<V> { completion in
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
    
    func map<V>(_ transform: @escaping (T) -> AsyncResult<V>) -> AsyncResult<V> {
        return AsyncResult<V> { completion in
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
    
    func failure(_ handler: @escaping (LcpError) -> Void) -> AsyncResult {
        return AsyncResult { completion in
            self.resolve { result in
                switch result {
                case .success(let value):
                    completion(.success(value))
                case .failure(let error):
                    handler(error)
                    completion(.failure(error))
                }
            }
        }
    }
    
}

/// Wraps a result-based completion block with PromisesKit
func wrap<T>(_ body: (@escaping (Result<T>) -> Void) throws -> Void) -> Promise<T> {
    return Promise { fulfill, reject in
        try body { result in
            switch result {
            case .success(let obj):
                fulfill(obj)
            case .failure(let error):
                reject(error)
            }
        }
    }
}
