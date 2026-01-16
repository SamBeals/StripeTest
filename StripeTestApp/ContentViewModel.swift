import Foundation

// View model holds state + actions. Keep this file small and easy to read.
@MainActor
final class ContentViewModel: ObservableObject {
    @Published private(set) var connectionStatus: ReaderStatus = .disconnected
    @Published var saleAmount = "2.50"
    @Published var lastActionMessage = "Ready to connect."

    private let readerService: ReaderService

    init(readerService: ReaderService = MockReaderService()) {
        self.readerService = readerService
        connectionStatus = readerService.status
    }

    func connect() async {
        connectionStatus = .connecting
        let result = await readerService.connect()
        connectionStatus = readerService.status
        lastActionMessage = result.description
    }

    func disconnect() async {
        let result = await readerService.disconnect()
        connectionStatus = readerService.status
        lastActionMessage = result.description
    }

    func charge() async {
        let amount = Decimal(string: saleAmount) ?? 0
        let result = await readerService.charge(amount: amount)
        lastActionMessage = result.description
    }

    func refundLastCharge() async {
        let result = await readerService.refundLastCharge()
        lastActionMessage = result.description
    }
}
