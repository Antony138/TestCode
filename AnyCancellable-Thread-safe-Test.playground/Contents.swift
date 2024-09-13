import Foundation
import Combine

class ThreadSafeCancellableSet {
    private var cancellables = Set<AnyCancellable>()
    private let lock = NSLock()

    func insert(_ cancellable: AnyCancellable) {
        lock.lock()
        defer { lock.unlock() }
        cancellables.insert(cancellable)
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        cancellables.removeAll()
    }
}

extension AnyCancellable {
    func store(in set: ThreadSafeCancellableSet) {
        set.insert(self)
    }
}


// Combine's AnyCancellable: Thread unsafe
//private var cancellableSet: Set<AnyCancellable> = []

// Custom thread-safe cancellableSet
private let cancellableSet = ThreadSafeCancellableSet()

func startPublisher() {
    Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
        .sink { _ in
            print("Timer fired")
        }
//        .store(in: &cancellableSet)
        .store(in: cancellableSet)
}

func cancelCancellable() {
    cancellableSet.removeAll()
    print("Cancelled on thread: \(Thread.current)")
}

func testCancelOnDifferentThreads() {
    let group = DispatchGroup()
    let concurrentQueue = DispatchQueue(label: "com.test.concurrent", attributes: .concurrent)

    startPublisher()

    // Background thread cancellation
    for _ in 1...100 {
        group.enter()
        concurrentQueue.async {
            cancelCancellable()
            group.leave()
        }
    }

    // Main thread cancellation
    cancelCancellable()

    group.notify(queue: .main) {
        print("Test completed")
    }
}

testCancelOnDifferentThreads()
