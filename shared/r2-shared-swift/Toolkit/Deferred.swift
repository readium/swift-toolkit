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

/// Continuation monad implementation to manipulate asynchronous values easily, with error forwarding.
/// This is NOT a Promise implementation, because state-less, simpler and not thread-safe. It's a purely syntactic tool meant to flatten a sequence of closure-based asynchronous calls into a monadic chain.
///
/// eg.
/// fetchFoo { status, error1 in
///     guard var status = val1 else {
///         completion(nil, error1)
///         return
///     }
///     status = "\(status + 100)"
///     parseBar(status) { object, error2 in
///         guard let object = object else {
///             completion(nil, error2)
///             return
///         }
///         do {
///             let result = try processThing(object)
///             completion(result, nil)
///         } catch {
///             completion(nil, error)
///         }
///     }
/// }
///
/// becomes (if the async functions return Deferred objects):
///
/// fetchFoo()
///     .map { status in "\(status + 100)" }  // Transforms the value synchronously with map
///     .flatMap(parseBar)  // Transforms using an async function with flatMap, if it returns a Deferred
///     .map(processThing)  // Thrown errors are automatically forwarded
///     .resolve(completion)  // If you don't call resolve nothing is executed, unlike Promises which are eager.
///
/// To keep things simple, almost every closure allows Error to be thrown. Deferred will automatically catch and forward them. You can then recover from the error using `catch`, or process it in `resolve`.
public final class Deferred<T> {
    
    /// Traditional completion closure signature, with optional value and error.
    public typealias Completion<V> = (V?, Error?) -> Void
    
    private let closure: (@escaping Completion<T>) throws -> Void
    private var resolved: Bool = false

    /// Constructs a Deferred from a closure taking a traditional completion block to return its result.
    ///
    /// func traditionalAsync(_ completion: @escaping (String?, Error?) -> Void) { ... }
    ///
    /// Deferred { completion in
    ///     traditionalAsync(completion)
    /// }
    public init(_ closure: @escaping (@escaping Completion<T>) throws -> Void) {
        self.closure = closure
    }

    /// Constructs a Deferred by wrapping another Deferred.
    /// This is useful for example when returning a Deferred in a function that performs some synchronous check before using another Deferred.
    /// Since we want the check to be performed when the Deferred is resolved (and not synchronously, when the function is called), we must wrap the full body of the function in a Deferred.
    ///
    /// func fetchStatus(for id: String?) -> Deferred<Data> {
    ///     return Deferred {
    ///         if let status = self.cachedStatus {
    ///             return .success(status)  // shortcut for: return Deferred.success(status)
    ///         }
    ///         let url = self.statusURL(for: id)
    ///         return Network.fetch(url)  // Network.fetch returns a Deferred
    ///             .map { response in
    ///                 return response.data
    ///             }
    ///     }
    /// }
    public convenience init(_ closure: @escaping () throws -> Deferred<T>) {
        self.init { completion in
            try closure().resolve(completion)
        }
    }
    
    /// Constructs a Deferred in a Promise style with two completion closures: one for the success and one for the failure.
    ///
    /// Deferred<Data> { success, failure in
    ///     fetch(input) { response in
    ///         guard response.status == 200 else {
    ///             failure(Error.failed)
    ///             return
    ///         }
    ///         success(response.data)
    ///     }
    /// }
    public convenience init(_ closure: @escaping (@escaping (T) -> Void, @escaping (Error) -> Void) throws -> Void) {
        self.init { completion in
            try closure({ completion($0, nil) }, { completion(nil, $0) })
        }
    }

    /// Shortcut to build a Deferred from a success value.
    /// Can be useful to return early a value in a .flatMap or Deferred { ... } construct.
    /// There's no `Deferred.failure` equivalent because you can simply throw Error directly, they will be wrapped by Deferred.
    public class func success(_ value: T) -> Deferred {
        return Deferred { $0(value, nil) }
    }
    
    /// Fires the deferred closure to resolve its value and forward it to the given traditional completion closure.
    /// To keep things simple, this can only be called once since the value is not cached.
    /// The completion block is systematically dispatched asynchronously on the given queue (default is the main thread), to avoid temporal coupling at the calling site.
    public func resolve(on queue: DispatchQueue = .main, _ completion: Completion<T>? = nil) {
        assert(!resolved, "Deferred doesn't cache the closure's value. It must only be called once.")
        resolved = true
        
        let completionOnQueue: Completion<T> = { value, error in
            guard let completion = completion else {
                return
            }
            queue.async {
                completion(value, error)
            }
        }
        
        do {
            try closure(completionOnQueue)
        } catch {
            completionOnQueue(nil, error)
        }
    }

    /// Resolves ignoring the value. Useful for a Deferred<Void>, when only the error matters.
    ///
    /// .resolve { error in
    ///     if let error = error {
    ///         print("Error: \(error)")
    ///     }
    /// }
    public func resolve(on queue: DispatchQueue = .main, _ completion: @escaping (Error?) -> Void) {
        resolve(on: queue) { _, error in
            completion(error)
        }
    }

    /// Transforms the value synchronously.
    ///
    /// .map { user in
    ///    return "Hello, \(user.name)"
    /// }
    public func map<V>(_ transform: @escaping (T) throws -> V) -> Deferred<V> {
        return map(
            success: { val, compl in compl(try transform(val), nil) }
        )
    }

    /// Transforms the value asynchronously, through a nested Deferred.
    ///
    /// func asyncOperation(value: Int) -> Deferred<String>
    ///
    /// .flatMap { val in
    ///    asyncOperation(val)
    /// }
    public func flatMap<V>(_ transform: @escaping (T) throws -> Deferred<V>) -> Deferred<V> {
        return map(
            success: { val, compl in try transform(val).resolve(compl) }
        )
    }
    
    /// Transforms the value through a traditional completion-based asynchronous function.
    ///
    /// func traditionalAsync(value: Int, _ completion: @escaping (String?, Error?) -> Void) throws { ... }
    ///
    /// .asyncMap { val, completion in
    ///    guard let val = val else {
    ///       throw Error.x
    ///    }
    ///    traditionalAsync(value: val, completion)
    /// }
    public func asyncMap<V>(_ transform: @escaping (T, @escaping Completion<V>) throws -> Void) -> Deferred<V> {
        return map(
            success: { val, compl in try transform(val, compl) }
        )
    }

    /// Attempts to recover from an error occured previously.
    /// You can either return an alternate success value, or throw again another (or the same) error to forward it.
    ///
    /// .catch { error in
    ///    if case Error.network = error {
    ///       return fetch()
    ///    }
    ///    throw error
    /// }
    public func `catch`(_ recover: @escaping (Error) throws -> T) -> Deferred<T> {
        return map(
            success: { val, compl in compl(val, nil) },
            failure: { err, compl in compl(try recover(err), nil) }
        )
    }

    /// Same as `catch`, but attempts to recover asynchronously, by returning a new Deferred object.
    public func flatCatch(_ recover: @escaping (Error) throws -> Deferred<T>) -> Deferred<T> {
        return map(
            success: { val, compl in compl(val, nil) },
            failure: { err, compl in try recover(err).resolve(compl) }
        )
    }
    
    /// Transforms (potentially) asynchronously the resolved value or error.
    /// The transformation is wrapped in another Deferred to be able to chain the transformations.
    ///
    /// All other mapping functions are based on this one.
    /// It's surprisingly easy to add new mapping functions. First, figure out the typed signature and then the implementation flows naturally from available values, thanks to the type checker.
    private func map<V>(
        success: @escaping (T, @escaping Completion<V>) throws -> Void,
        // The default failure handler simply forwards the error.
        failure: @escaping (Error, @escaping Completion<V>) throws -> Void = { $1(nil, $0) }
        ) -> Deferred<V> {
        return Deferred<V> { completion in
            self.resolve { value, error in
                do {
                    if let value = value {
                        try success(value, completion)
                    } else if let error = error {
                        try failure(error, completion)
                    } else {
                        completion(nil, nil)
                    }
                } catch {
                    completion(nil, error)
                }
            }
        }
    }

}
