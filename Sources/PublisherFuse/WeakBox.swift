import Foundation
import Combine

class WeakBox<T: AnyObject>: Hashable {

    weak var value: T?

    private let id = UUID().uuidString

    init(_ value: T) {
        self.value = value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: WeakBox<T>, rhs: WeakBox<T>) -> Bool {
        lhs.id == rhs.id
    }
}

extension WeakBox: Cancellable where T: Cancellable {
    func cancel() {
        value?.cancel()
    }
}
