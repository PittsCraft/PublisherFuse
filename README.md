# PublisherFuse ⚡️

Safety Combine publisher fuse allowing to cancel upstream subscriptions especially when a chosen object is deallocated.

- iOS 13+
- macOS 10.15+

## Problem

```swift
class Forwarder {

    private let repository: Repository // Provides a publisher of A
    
    private func map<A, B>(_ input: A) -> B? {
        // Some stateful mapping
    }
    
    func publisher() -> AnyPublisher<B?, Never> {
        repository
            .aPublisher()
            .map { [unowned self] in
                map($0)
            }
            .eraseToAnyPublisher()
    }

}
```

If the `Forwarder` has a lifetime shorter than the `Repository`, any subscription to the publisher will live 
independently of `Forwarder`'s deallocation, leading to a crash caused by the use of `unowned` capture.

## Usual solutions


I strongly encourage you to have a close look to find out why you're in such a situation and how you 
could avoid these issues, by paying particular attention to lifecycles, sanitizing your architecture and code.

For example, if you have got a `AnyPublisher<Forwarder?, Never>` that represents your `Forwarder`'s lifecycle, don't use
 `compactMap` to get its non `nil` values. Instead, properly handling the `nil` case to maintain your subscriptions 
 can be enough.

If refactoring is not possible, then this problem could be solved easily by using `weak` or `strong` capture depending on what is wanted. 

However there are drawbacks to these solutions, for example:
- using `weak` may be uncomfortable: `guard let self = self else { return nil }` is usual but 
the output of the mapping can be indistinguishable from a potential meaningful `nil` value. Moreover, the receptions 
won't stop until the subscription is canceled, independently of `Forwarder`'s deallocation.
- `strong` causes the subscription to retain the `Forwarder` and that may be unwanted.


## Safety first

Depending on the context, you may still want to use a safety mechanism to make sure that any future development won't make weird behaviors occur.

This is what this package is about.

```swift
class Forwarder {

    private var cancellables = Set<AnyCancellable>()
    private let repository: Repository // Provides a publisher of A
    
    private func map<A, B>(_ input: A) -> B? {
        // Some mapping
    }
    
    func publisher() -> AnyPublisher<B?, Never> {
        repository
            .aPublisher()
            .map { [unowned self] in
                map($0)
            }
            .fuse(heldBy: self, on: \.cancellables)
            .eraseToAnyPublisher()
    }
}
```

**Short version**

This fuse stops all activity as soon as its holder is deallocated, making it safe for consumers of the publishers to stay subscribed longer than `Forwarder`'s lifetime. 

However subscriptions made to a publisher provided by the `publisher()` function should be canceled at some point if you want to release what's retained by them and avoid memory leaks.

**Longer version**

What's going on here:
- any call to `publisher()` will store an associated proxy stored in the `cancellables` set
- when the `Forwarder` is deallocated the proxies are canceled, invalidating all the subscription chains above and including the
`fuse(heldBy:on:)` call (ie anything related to `repository.aPublisher().map(...).fuse(...)`)
- of course same thing happens if you explicitly cancel the proxies
- if there are no more active subscriptions on it and nothing retains a publisher, its proxy is properly removed from 
the set 

## Dev

This was more of an exercise to me, that's why:
- tests don't cover straightforward parts of the code
- it's probable there won't be any further development or maintaining effort except if there's any real world adoption

