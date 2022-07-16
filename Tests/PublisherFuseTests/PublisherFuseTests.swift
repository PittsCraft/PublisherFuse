import XCTest
@testable import PublisherFuse
import Combine

class PublisherFuseTests: XCTestCase {

    class Holder {
        var cancellable: AnyCancellable?
        var cancellableSet = Set<AnyCancellable>()
    }

    var holder = Holder()

    override func setUpWithError() throws {
        holder = Holder()
    }

    override func tearDownWithError() throws {
        holder = Holder()
    }

    typealias FuseType = PublisherFuse<Void, Never>

    func testReceiveInput() throws {
        let subject = PassthroughSubject<Void, Never>()
        let publisher = subject
        let fusePublisher = publisher.fuse(heldBy: holder, on: \.cancellable)
        let expectation = expectation(description: "Sink closure should be called")
        let cancellable = fusePublisher.sink {
            expectation.fulfill()
        }
        subject.send(())
        waitForExpectations(timeout: 0)
    }

    func testPublisherFuseCancellation() throws {
        let subject = PassthroughSubject<Void, Never>()
        let publisher = subject
        let fusePublisher = publisher.fuse(heldBy: holder, on: \.cancellable)
        let cancellable = fusePublisher.sink {
            XCTFail("Sink closure should not be called after PublisherFuse cancellation")
        }
        fusePublisher.cancel()
        subject.send(())
    }

    func testSubscriptionCancellation() throws {
        let subject = PassthroughSubject<Void, Never>()
        let publisher = subject
        let fusePublisher = publisher.fuse(heldBy: holder, on: \.cancellable)
        let cancellable = fusePublisher.sink {
            XCTFail("Sink closure should not be called after subscription cancellation")
        }
        cancellable.cancel()
        subject.send(())
    }

    func testFuseCancellableCancellation() throws {
        let subject = PassthroughSubject<Void, Never>()
        let publisher = subject
        let fusePublisher = publisher.fuse(heldBy: holder, on: \.cancellable)
        let cancellable = fusePublisher.sink {
            XCTFail("Sink closure should not be called after subscription cancellation")
        }
        holder.cancellable?.cancel()
        subject.send(())
    }

    func testSubscriptionReleaseOnSubscriptionCancellation() throws {
        class Thing {}
        let subject = PassthroughSubject<Void, Never>()
        let publisher = subject
        let fusePublisher = publisher.fuse(heldBy: holder, on: \.cancellable)
        var thing: Thing? = Thing()
        weak var weakThing: Thing? = thing
        let cancellable = fusePublisher.sink { [thing] in
            print(thing as Any)
        }
        thing = nil
        XCTAssert(weakThing != nil, "Strong capture made by subscription should not be released before subscription cancellation")
        cancellable.cancel()
        XCTAssert(weakThing == nil, "Strong capture made by subscription should be released after subscription cancellation")
    }

    func testSubscriptionReleaseOnFuseCancellableCancellation() throws {
        class Thing {}
        let subject = PassthroughSubject<Void, Never>()
        let publisher = subject
        let fusePublisher = publisher.fuse(heldBy: holder, on: \.cancellable)
        var thing: Thing? = Thing()
        weak var weakThing: Thing? = thing
        // This won't work. The `AnyCancellable` created by the sink function retains the subscription thus
        // the `receiveValue` closure will not be released by simply cancelling the fuse subscription
        //        let cancellable = fusePublisher.sink { [thing] in
        //            print(thing)
        //        }
        fusePublisher.receive(subscriber: Subscribers.Sink(receiveCompletion: {_ in },
                                                           receiveValue: { [thing] in
            print(thing as Any)
        }))
        thing = nil
        XCTAssert(weakThing != nil, "Strong capture made by subscription should not be released before fuse cancellable cancellation")
        holder.cancellable?.cancel()
        XCTAssert(weakThing == nil, "Strong capture made by subscription should be released after fuse cancellable cancellation")
    }

    func testSubscriptionReleaseOnPublisherFuseCancellation() throws {
        class Thing {}
        let subject = PassthroughSubject<Void, Never>()
        let publisher = subject
        let fusePublisher = publisher.fuse(heldBy: holder, on: \.cancellable)
        var thing: Thing? = Thing()
        weak var weakThing: Thing? = thing
        // Testing with sink function won't work. The `AnyCancellable` created by it retains the subscription thus
        // the `receiveValue` closure will not be released by simply cancelling the fuse subscription

        //        let cancellable = fusePublisher.sink { [thing] in
        //            print(thing)
        //        }

        fusePublisher.receive(subscriber: Subscribers.Sink(receiveCompletion: {_ in },
                                                           receiveValue: { [thing] in
            print(thing as Any)
        }))
        thing = nil
        XCTAssert(weakThing != nil, "Strong capture made by subscription should not be released before fuse cancellation")
        fusePublisher.cancel()
        XCTAssert(weakThing == nil, "Strong capture made by subscription should be released after fuse cancellation")
    }

    func testPublisherAliveWhenSubscriptionExists() throws {
        let subject = PassthroughSubject<Void, Never>()
        let publisher = subject
        var fusePublisher: FuseType! = publisher.fuse(heldBy: holder, on: \.cancellable)
        weak var weakFusePublisher = fusePublisher
        let cancellable = fusePublisher.sink {
            print()
        }
        fusePublisher = nil
        XCTAssert(weakFusePublisher != nil, "Fuse publisher shouldn't be deallocated when there are still subscriptions")
    }

    func testPublisherDeallocation() throws {
        let subject = PassthroughSubject<Void, Never>()
        let publisher = subject
        var fusePublisher: FuseType! = publisher.fuse(heldBy: holder, on: \.cancellable)
        weak var weakFusePublisher = fusePublisher
        let cancellable = fusePublisher.sink {
            print()
        }
        fusePublisher = nil
        cancellable.cancel()
        XCTAssert(weakFusePublisher == nil, "Fuse publisher should be deallocated when there are no more subscriptions")
    }
}
