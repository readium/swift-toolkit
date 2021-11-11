//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

#if canImport(Combine)

import Foundation
import Combine

/// Bindings to convert a Readium `Observable` into a Combine `Publisher`.
@available(iOS 13.0, *)
public extension Observable {
    
    /// Returns a Combine `Publisher` to observe this stream of values.
    func publisher() -> Publisher {
        Publisher(observable: self)
    }
    
    struct Publisher: Combine.Publisher {
        public typealias Output = Value
        public typealias Failure = Never
        
        let observable: Observable<Value>
        
        public func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, Value == S.Input {
            let cancellable = observable.subscribe { value in
                _ = subscriber.receive(value)
            }
            let subscription = ObservableSubscription<S>(cancellable: cancellable)
            subscriber.receive(subscription: subscription)
        }
    }
    
    private class ObservableSubscription<Target: Subscriber>: Subscription where Target.Input == Value {
        private var cancellable: Cancellable?
        
        init(cancellable: Cancellable) {
            self.cancellable = cancellable
        }
        
        func cancel() {
            cancellable?.cancel()
            cancellable = nil
        }
        
        func request(_ demand: Subscribers.Demand) {}
    }
}

#endif
