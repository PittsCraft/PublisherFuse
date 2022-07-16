import Foundation
import Combine

extension PublisherFuse {
    class Subscription {
        private var subscriber: AnySubscriber<Output, Failure>?
        private var subscription: Combine.Subscription?
        private let onDeinit: () -> Void
        // Strong retain the publisher until this subscription is alive
        private var fusePublisher: AnyPublisher<Output, Failure>?

        init<S: Subscriber, P: Publisher>(fusePublisher: PublisherFuse<Output, Failure>,
                                          subscriber: S,
                                          publisher: P,
                                          onDeinit: @escaping () -> Void)
        where S.Input == Output, S.Failure == Failure, P.Output == Output, P.Failure == Failure {
            self.fusePublisher = fusePublisher.eraseToAnyPublisher()
            self.subscriber = AnySubscriber(subscriber)
            self.onDeinit = onDeinit
            publisher.receive(subscriber: self)
        }

        deinit {
            cancel()
            onDeinit()
        }
    }
}

extension PublisherFuse.Subscription: Subscriber {
    func receive(subscription: Subscription) {
        self.subscription = subscription
    }

    func receive(_ input: Output) -> Subscribers.Demand {
        subscriber?.receive(input) ?? .none
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        subscriber?.receive(completion: completion)
    }
}

extension PublisherFuse.Subscription: Combine.Subscription {
    func request(_ demand: Subscribers.Demand) {
        subscription?.request(demand)
    }

    func cancel() {
        subscription?.cancel()
        subscription = nil
        subscriber = nil
    }
}
