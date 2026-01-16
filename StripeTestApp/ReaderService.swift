import Foundation

#if canImport(StripeTerminal)
import StripeTerminal
#endif

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

enum ReaderMode {
    case mock
    case stripeTerminal
}

enum ReaderServiceFactory {
    static func make(mode: ReaderMode) -> ReaderService {
        switch mode {
        case .mock:
            return MockReaderService()
        case .stripeTerminal:
            #if canImport(StripeTerminal)
            return StripeTerminalReaderService(
                backendURL: AppConfig.backendURL,
                locationId: AppConfig.readerLocationId
            )
            #else
            return MockReaderService()
            #endif
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

#if canImport(StripeTerminal)
@MainActor
final class StripeTerminalReaderService: NSObject, ReaderService {
    private(set) var status: ReaderStatus = .disconnected
    private let backendURL: URL
    private let locationId: String
    private var discoveredReaders: [Reader] = []
    private var discoveryCancelable: Cancelable?
    private var lastPaymentIntentId: String?

    init(backendURL: URL, locationId: String) {
        self.backendURL = backendURL
        self.locationId = locationId
        super.init()
        Terminal.setTokenProvider(StripeConnectionTokenProvider(backendURL: backendURL))
        Terminal.shared.delegate = self
    }

    func connect() async -> ReaderResult {
        guard status != .connected else {
            return .success("Reader already connected.")
        }

        status = .connecting

        do {
            let reader = try await discoverFirstReader()
            try await connectToReader(reader)
            status = .connected
            return .success("Connected to \(reader.label ?? "M2 Reader").")
        } catch {
            status = .disconnected
            return .failure("Failed to connect: \(error.localizedDescription)")
        }
    }

    func disconnect() async -> ReaderResult {
        do {
            try await disconnectReader()
            status = .disconnected
            return .success("Reader disconnected.")
        } catch {
            return .failure("Failed to disconnect: \(error.localizedDescription)")
        }
    }

    func charge(amount: Decimal) async -> ReaderResult {
        guard status == .connected else {
            return .failure("Reader is not connected. Connect before charging.")
        }

        do {
            let intentResponse = try await createPaymentIntent(amount: amount)
            let paymentIntent = try await retrievePaymentIntent(clientSecret: intentResponse.clientSecret)
            let collected = try await collectPaymentMethod(paymentIntent: paymentIntent)
            let processed = try await processPayment(paymentIntent: collected)
            lastPaymentIntentId = processed.stripeId
            return .success("Payment processed for $\(amount).")
        } catch {
            return .failure("Payment failed: \(error.localizedDescription)")
        }
    }

    func refundLastCharge() async -> ReaderResult {
        guard let paymentIntentId = lastPaymentIntentId else {
            return .failure("No payment to refund yet.")
        }

        do {
            try await refundPaymentIntent(paymentIntentId: paymentIntentId)
            return .success("Refund requested for \(paymentIntentId).")
        } catch {
            return .failure("Refund failed: \(error.localizedDescription)")
        }
    }
}

extension StripeTerminalReaderService: TerminalDelegate {}

extension StripeTerminalReaderService: DiscoveryDelegate {
    func terminal(_ terminal: Terminal, didUpdateDiscoveredReaders readers: [Reader]) {
        discoveredReaders = readers
    }
}

private extension StripeTerminalReaderService {
    func discoverFirstReader() async throws -> Reader {
        let configuration = DiscoveryConfiguration(discoveryMethod: .bluetoothScan, simulated: false)
        return try await withCheckedThrowingContinuation { continuation in
            discoveryCancelable = Terminal.shared.discoverReaders(configuration, delegate: self) { result in
                switch result {
                case .success:
                    if let reader = self.discoveredReaders.first {
                        self.discoveryCancelable?.cancel()
                        continuation.resume(returning: reader)
                    } else {
                        continuation.resume(throwing: ReaderServiceError.noReadersFound)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func connectToReader(_ reader: Reader) async throws {
        let config = BluetoothConnectionConfiguration(locationId: locationId)
        return try await withCheckedThrowingContinuation { continuation in
            Terminal.shared.connectBluetoothReader(reader, delegate: nil, connectionConfig: config) { result in
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func disconnectReader() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            Terminal.shared.disconnectReader { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func retrievePaymentIntent(clientSecret: String) async throws -> PaymentIntent {
        return try await withCheckedThrowingContinuation { continuation in
            Terminal.shared.retrievePaymentIntent(clientSecret: clientSecret) { result in
                switch result {
                case .success(let intent):
                    continuation.resume(returning: intent)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func collectPaymentMethod(paymentIntent: PaymentIntent) async throws -> PaymentIntent {
        return try await withCheckedThrowingContinuation { continuation in
            Terminal.shared.collectPaymentMethod(paymentIntent) { result in
                switch result {
                case .success(let intent):
                    continuation.resume(returning: intent)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func processPayment(paymentIntent: PaymentIntent) async throws -> PaymentIntent {
        return try await withCheckedThrowingContinuation { continuation in
            Terminal.shared.processPayment(paymentIntent) { result in
                switch result {
                case .success(let intent):
                    continuation.resume(returning: intent)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func createPaymentIntent(amount: Decimal) async throws -> PaymentIntentResponse {
        let body = PaymentIntentRequest(
            amount: NSDecimalNumber(decimal: amount)
                .multiplying(by: NSDecimalNumber(value: 100))
                .intValue,
            currency: "usd",
            locationId: locationId
        )
        let url = backendURL.appendingPathComponent("create_payment_intent")
        let response: PaymentIntentResponse = try await post(url: url, body: body)
        return response
    }

    func refundPaymentIntent(paymentIntentId: String) async throws {
        let body = RefundRequest(paymentIntentId: paymentIntentId)
        let url = backendURL.appendingPathComponent("refund")
        let _: EmptyResponse = try await post(url: url, body: body)
    }

    func post<Request: Encodable, Response: Decodable>(url: URL, body: Request) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReaderServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ReaderServiceError.backendError(message)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

private final class StripeConnectionTokenProvider: ConnectionTokenProvider {
    private let backendURL: URL

    init(backendURL: URL) {
        self.backendURL = backendURL
    }

    func fetchConnectionToken(_ completion: @escaping ConnectionTokenCompletionBlock) {
        var request = URLRequest(url: backendURL.appendingPathComponent("connection_token"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(nil, error)
                return
            }
            guard
                let data,
                let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode)
            else {
                completion(nil, ReaderServiceError.invalidResponse)
                return
            }

            do {
                let tokenResponse = try JSONDecoder().decode(ConnectionTokenResponse.self, from: data)
                completion(tokenResponse.secret, nil)
            } catch {
                completion(nil, error)
            }
        }.resume()
    }
}

private enum ReaderServiceError: LocalizedError {
    case noReadersFound
    case backendError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noReadersFound:
            return "No readers found. Make sure the M2 is powered on and in range."
        case .backendError(let message):
            return "Backend error: \(message)"
        case .invalidResponse:
            return "Invalid response from backend."
        }
    }
}

private struct ConnectionTokenResponse: Decodable {
    let secret: String
}

private struct PaymentIntentRequest: Encodable {
    let amount: Int
    let currency: String
    let locationId: String
}

private struct PaymentIntentResponse: Decodable {
    let clientSecret: String
}

private struct RefundRequest: Encodable {
    let paymentIntentId: String
}

private struct EmptyResponse: Decodable {}
#endif
