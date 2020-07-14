//
//  Deferred.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 10.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Continuation monad implementation to manipulate asynchronous values easily, with error
/// forwarding.
///
/// This is NOT a Promise implementation, because state-less, simpler and not thread-safe. It's a
/// purely syntactic tool meant to flatten a sequence of closure-based asynchronous calls into a
/// monadic chain.
///
/// For example:
///
///     fetchFoo { status, error1 in
///         guard var status = val1 else {
///             completion(nil, error1)
///             return
///         }
///         status = "\(status + 100)"
///         parseBar(status) { object, error2 in
///             guard let object = object else {
///                 completion(nil, error2)
///                 return
///             }
///             do {
///                 let result = try processThing(object)
///                 completion(result, nil)
///             } catch {
///                 completion(nil, error)
///             }
///         }
///     }
///
/// becomes (if the async functions return Deferred objects):
///
///     fetchFoo()
///         .map { status in "\(status + 100)" }  // Transforms the value synchronously with map
///         .flatMap(parseBar)  // Transforms using an async function with flatMap, if it returns a Deferred
///         .map(processThing)  // Thrown errors are automatically forwarded
///         .resolve(completion)  // If you don't call resolve nothing is executed, unlike Promises which are eager.
///
/// To keep things simple, almost every closure allows Error to be thrown. Deferred will
/// automatically catch and forward them. You can then recover from the error using `catch`, or
/// process it in `resolve`.
public final class Deferred<Success, Failure: Error> {
    
    /// Traditional completion closure signature, with a `Result` object.
    public typealias Completion = (Result<Success, Failure>) -> Void
    public typealias NewCompletion<NewSuccess, NewFailure: Error> = (Result<NewSuccess, NewFailure>) -> Void

    private let closure: (@escaping Completion) -> Void
    
    /// Dispatch queue on which the `closure` will be (asynchronously) executed. If `nil`, it will
    /// be executed synchronously on the caller of `resolve`.
    private let queue: DispatchQueue?
    
    /// Indicates whether the `Deferred` was resolved. It can only be resolved once.
    private var resolved: Bool = false

    public init(on queue: DispatchQueue? = nil, _ closure: @escaping (@escaping Completion) -> Void) {
        self.closure = closure
        self.queue = queue
    }

    /// Shortcut to build a Deferred from a success value.
    ///
    /// Can be useful to return early a value in a `.flatMap` or `deferred { ... }` construct.
    public class func success(_ value: Success) -> Self {
        return Self { $0(.success(value)) }
    }

    /// Shortcut to build a Deferred from an error.
    ///
    /// Can be useful to return early a value in a `.flatMap` or `deferred { ... }` construct.
    public class func failure(_ error: Failure) -> Self {
        return Self { $0(.failure(error)) }
    }

    /// Fires the deferred closure to resolve its value and forward it to the given traditional
    /// completion closure.
    ///
    /// To keep things simple, this can only be called once since the value is not cached.
    /// The completion block is systematically dispatched asynchronously on the given queue (default
    /// is the main thread), to avoid temporal coupling at the calling site.
    public func resolve(on completionQueue: DispatchQueue = .main, _ completion: Completion? = nil) {
        assert(!resolved, "Deferred doesn't cache the closure's value. It must only be called once.")
        resolved = true
        
        let completionOnQueue: Completion = { result in
            guard let completion = completion else {
                return
            }
            completionQueue.async {
                completion(result)
            }
        }
        
        if let queue = self.queue {
            queue.async { self.closure(completionOnQueue) }
        } else {
            closure(completionOnQueue)
        }
    }

    /// Transforms the value synchronously.
    ///
    ///     .map { user in
    ///        "Hello, \(user.name)"
    ///     }
    public func map<NewSuccess>(_ transform: @escaping (Success) -> NewSuccess) -> Deferred<NewSuccess, Failure> {
        return map(
            success: { val, compl in compl(.success(transform(val))) },
            failure: { err, compl in compl(.failure(err)) }
        )
    }

    /// Transforms the value synchronously, catching any error.
    public func mapCatching<NewSuccess>(_ transform: @escaping (Success) throws -> NewSuccess) -> Deferred<NewSuccess, Error> {
        return map(
            success: { val, compl in
                do {
                    compl(.success(try transform(val)))
                } catch {
                    compl(.failure(error))
                }
            },
            failure: { err, compl in compl(.failure(err)) }
        )
    }

    /// Transforms the value asynchronously, through a nested Deferred.
    ///
    ///     func asyncOperation(value: Int) -> Deferred<String>
    ///
    ///     .flatMap { val in
    ///        asyncOperation(val)
    ///     }
    public func flatMap<NewSuccess>(_ transform: @escaping (Success) -> Deferred<NewSuccess, Failure>) -> Deferred<NewSuccess, Failure> {
        return map(
            success: { val, compl in transform(val).resolve(compl) },
            failure: { err, compl in compl(.failure(err)) }
        )
    }
    
    /// Transforms the value through a traditional completion-based asynchronous function.
    ///
    ///     func traditionalAsync(value: Int, _ completion: @escaping (Result<String, Error>) -> Void) throws { ... }
    ///
    ///     .asyncMap { val, completion in
    ///        traditionalAsync(value: val, completion)
    ///     }
    public func asyncMap<NewSuccess>(_ transform: @escaping (Success, @escaping NewCompletion<NewSuccess, Failure>) -> Void) -> Deferred<NewSuccess, Failure> {
        return map(
            success: { val, compl in transform(val, compl) },
            failure: { err, compl in compl(.failure(err)) }
        )
    }
    
    /// Transforms the value through a traditional completion-based asynchronous function, which may
    /// throw an error.
    ///
    ///     func traditionalAsync(value: Int, _ completion: @escaping (Result<String, Error>) -> Void) throws { ... }
    ///
    ///     .asyncMap { val, completion in
    ///        guard let val = val else {
    ///           throw Error.x
    ///        }
    ///        traditionalAsync(value: val, completion)
    ///     }
    public func asyncMapCatching<NewSuccess>(_ transform: @escaping (Success, @escaping NewCompletion<NewSuccess, Error>) throws -> Void) -> Deferred<NewSuccess, Error> {
        return map(
            success: { val, compl in
                do {
                    try transform(val, compl)
                } catch {
                    compl(.failure(error))
                }
            },
            failure: { err, compl in compl(.failure(err)) }
        )
    }

    /// Attempts to recover from an error occured previously.
    /// You can either return an alternate success value, or throw again another (or the same) error
    /// to forward it.
    ///
    ///     .catch { error in
    ///        if case Error.network = error {
    ///           return fetch()
    ///        }
    ///        throw error
    ///     }
    public func `catch`(_ recover: @escaping (Failure) -> Result<Success, Failure>) -> Deferred<Success, Failure> {
        return map(
            success: { val, compl in compl(.success(val)) },
            failure: { err, compl in compl(recover(err)) }
        )
    }

    /// Same as `catch`, but attempts to recover asynchronously, by returning a new Deferred object.
    public func flatCatch(_ recover: @escaping (Failure) -> Deferred<Success, Failure>) -> Deferred<Success, Failure> {
        return map(
            success: { val, compl in compl(.success(val)) },
            failure: { err, compl in recover(err).resolve(compl) }
        )
    }
    
    /// Returns a new `Deferred`, mapping any failure value using the given transformation.
    public func mapError<NewFailure>(_ transform: @escaping (Failure) -> NewFailure) -> Deferred<Success, NewFailure> {
        return map(
            success: { val, compl in compl(.success(val)) },
            failure: { err, compl in compl(.failure(transform(err))) }
        )
    }
    
    /// Transforms (potentially) asynchronously the resolved value or error.
    /// The transformation is wrapped in another Deferred to be able to chain the transformations.
    ///
    /// All other mapping functions are based on this one.
    /// To add new mapping functions, first figure out the typed signature and then the
    /// implementation should flow naturally from available values, thanks to the type checker.
    private func map<NewSuccess, NewFailure>(
        success: @escaping (Success, @escaping NewCompletion<NewSuccess, NewFailure>) -> Void,
        failure: @escaping (Failure, @escaping NewCompletion<NewSuccess, NewFailure>) -> Void
    ) -> Deferred<NewSuccess, NewFailure> {
        return Deferred<NewSuccess, NewFailure> { completion in
            self.resolve { result in
                switch result {
                case .success(let value):
                    success(value, completion)
                case .failure(let error):
                    failure(error, completion)
                }
            }
        }
    }

}

extension Deferred where Success == Void {
    
    public func resolveWithError(on queue: DispatchQueue = .main, _ completion: @escaping ((Failure?) -> Void)) {
        resolve(on: queue, { result in
            switch result {
            case .success(_):
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        })
    }
    
}

/// Constructs a Deferred from a closure taking a traditional completion block to return its
/// result.
///
///     func traditionalAsync(_ completion: @escaping (Result<String, Error>) -> Void) { ... }
///
///     deferred { completion in
///         traditionalAsync(completion)
///     }
public func deferred<Success, Failure: Error>(on queue: DispatchQueue? = nil, _ closure: @escaping (@escaping Deferred<Success, Failure>.Completion) -> Void) -> Deferred<Success, Failure> {
    return Deferred(on: queue, closure)
}

/// Constructs a Deferred from a closure taking a traditional completion block to return its
/// result.
///
/// Any thrown error is caught and wrapped in a result.
public func deferred<Success>(on queue: DispatchQueue? = nil, catching closure: @escaping (@escaping Deferred<Success, Error>.Completion) throws -> Void) -> Deferred<Success, Error> {
    return Deferred(on: queue) { completion in
        do {
            try closure(completion)
        } catch {
            completion(.failure(error))
        }
    }
}

/// Constructs a Deferred by wrapping another Deferred.
///
/// This is useful for example when returning a Deferred in a function that performs some
/// synchronous check before using another Deferred. Since we want the check to be performed
/// when the Deferred is resolved (and not synchronously, when the function is called), we must
/// wrap the full body of the function in a Deferred.
///
///     func fetchStatus(for id: String?) -> Deferred<Data> {
///         return deferred {
///             if let status = self.cachedStatus {
///                 return .success(status)  // shortcut for: return Deferred.success(status)
///             }
///             let url = self.statusURL(for: id)
///             return Network.fetch(url)  // Network.fetch returns a Deferred
///                 .map { response in
///                     return response.data
///                 }
///         }
///     }
public func deferred<Success, Failure>(on queue: DispatchQueue? = nil, _ closure: @escaping () -> Deferred<Success, Failure>) -> Deferred<Success, Failure> {
    return Deferred(on: queue) { completion in
        closure().resolve(completion)
    }
}

/// Constructs a Deferred by wrapping another Deferred.
///
/// Any thrown error is caught and wrapped in a result.
public func deferred<Success>(on queue: DispatchQueue? = nil, catching closure: @escaping () throws -> Deferred<Success, Error>) -> Deferred<Success, Error> {
    return Deferred(on: queue) { completion in
        do {
            try closure().resolve(completion)
        } catch {
            completion(.failure(error))
        }
    }
}

/// Constructs a Deferred in a Promise style with two completion closures: one for the success
/// and one for the failure.
///
///     Deferred<Data> { success, failure in
///         fetch(input) { response in
///             guard response.status == 200 else {
///                 failure(Error.failed)
///                 return
///             }
///             success(response.data)
///         }
///     }
public func deferred<Success, Failure>(on queue: DispatchQueue? = nil, _ closure: @escaping (@escaping (Success) -> Void, @escaping (Failure) -> Void) -> Void) -> Deferred<Success, Failure> {
    return Deferred(on: queue) { completion in
        closure(
            { completion(.success($0)) },
            { completion(.failure($0)) }
        )
    }
}
