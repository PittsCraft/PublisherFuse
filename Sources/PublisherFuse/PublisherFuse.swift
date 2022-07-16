import Foundation
import Combine

public class PublisherFuse<Output, Failure: Error>: Publisher {
    
    private let publisher: AnyPublisher<Output, Failure>
    private var subscriptions = Set<WeakBox<Subscription>>()
    private var cancelled = false
    private let removeCancellable: (AnyCancellable) -> Void
    private weak var ownCancellable: AnyCancellable?
    
    
    public init<P>(_ publisher: P,
                   storeCancellable: (AnyCancellable) -> Void,
                   removeCancellable: @escaping (AnyCancellable) -> Void)
    where P: Publisher, P.Output == Output, P.Failure == Failure {
        self.publisher = publisher.eraseToAnyPublisher()
        self.removeCancellable = removeCancellable
        let ownCancellable = AnyCancellable(WeakBox(self))
        self.ownCancellable = ownCancellable
        storeCancellable(ownCancellable)
    }
    
    public convenience init<P, Holder>(_ publisher: P,
                                       holder: Holder,
                                       cancellablesKeyPath: ReferenceWritableKeyPath<Holder, Set<AnyCancellable>>)
    where Holder: AnyObject, P: Publisher, P.Output == Output, P.Failure == Failure {
        self.init(publisher, storeCancellable: {
            holder[keyPath: cancellablesKeyPath].insert($0)
        }, removeCancellable: { [weak holder] in
            holder?[keyPath: cancellablesKeyPath].remove($0)
        })
    }
    
    public convenience init<P, Holder>(_ publisher: P,
                                       holder: Holder,
                                       cancellableKeyPath: ReferenceWritableKeyPath<Holder, AnyCancellable?>)
    where Holder: AnyObject, P: Publisher, P.Output == Output, P.Failure == Failure {
        self.init(publisher, storeCancellable: {
            holder[keyPath: cancellableKeyPath] = $0
        }, removeCancellable: { [weak holder] in
            guard let holder = holder, holder[keyPath: cancellableKeyPath] == $0 else {
                return
            }
            holder[keyPath: cancellableKeyPath] = nil
        })
    }
    
    deinit {
        cancel()
        if let ownCancellable = ownCancellable {
            removeCancellable(ownCancellable)
        }
    }
    
    public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        guard !cancelled else { return }
        var onDeinit = {}
        let subscription = Subscription(fusePublisher: self,
                                        subscriber: subscriber,
                                        publisher: publisher,
                                        onDeinit: { onDeinit() })
        let box = WeakBox(subscription)
        onDeinit = { [weak self, weak box] in
            guard let box = box else { return }
            self?.subscriptions.remove(box)
        }
        subscriptions.insert(box)
        subscriber.receive(subscription: subscription)
    }
}

extension PublisherFuse: Cancellable {
    
    public func cancel() {
        cancelled = true
        subscriptions.forEach { $0.value?.cancel() }
        subscriptions = []
    }
}

public extension Publisher {
    
    func fuse<Holder: AnyObject>(heldBy holder: Holder,
                                 on keyPath: ReferenceWritableKeyPath<Holder, Set<AnyCancellable>>)
    -> PublisherFuse<Output, Failure> {
        PublisherFuse(self, holder: holder, cancellablesKeyPath: keyPath)
    }
    
    func fuse<Holder: AnyObject>(heldBy holder: Holder,
                                 on keyPath: ReferenceWritableKeyPath<Holder, AnyCancellable?>)
    -> PublisherFuse<Output, Failure> {
        PublisherFuse(self, holder: holder, cancellableKeyPath: keyPath)
    }
    
    func fuse(storeCancellable: (AnyCancellable) -> Void,
              removeCancellable: @escaping (AnyCancellable) -> Void) -> PublisherFuse<Output, Failure> {
        PublisherFuse(self, storeCancellable: storeCancellable, removeCancellable: removeCancellable)
    }
}
