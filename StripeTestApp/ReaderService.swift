import Foundation

// Interface for real or mock reader behavior.
protocol ReaderService {
    var status: ReaderStatus { get }

    func connect() async -> ReaderResult
    func disconnect() async -> ReaderResult
    func charge(amount: Decimal) async -> ReaderResult
    func refundLastCharge() async -> ReaderResult
}

enum ReaderStatus: String {
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case connected = "Connected"
}

enum ReaderResult: CustomStringConvertible {
    case success(String)
    case failure(String)

    var description: String {
        switch self {
        case .success(let message):
            return message
        case .failure(let message):
            return message
        }
    }
}

// Mock implementation used for UI prototyping.
final class MockReaderService: ReaderService {
    private(set) var status: ReaderStatus = .disconnected

    func connect() async -> ReaderResult {
        status = .connecting
        try? await Task.sleep(nanoseconds: 500_000_000)
        status = .connected
        return .success("Mock connection established. Stripe Terminal SDK not wired yet.")
    }

    func disconnect() async -> ReaderResult {
        status = .disconnected
        return .success("Mock reader disconnected.")
    }

    func charge(amount: Decimal) async -> ReaderResult {
        guard status == .connected else {
            return .failure("Reader is not connected. Connect before charging.")
        }
        return .success("Simulated charge for $\(amount).")
    }

    func refundLastCharge() async -> ReaderResult {
        guard status == .connected else {
            return .failure("Reader is not connected. Connect before refunding.")
        }
        return .success("Simulated refund issued.")
    }
}
