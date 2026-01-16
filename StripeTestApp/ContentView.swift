import SwiftUI

// Main screen shown by the app.
// Each section below is extracted into a computed view so it's easy to edit.
struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                mockNotice
                statusCard
                connectionControls
                saleSimulator
                futureAutomationNote
                Spacer()
            }
            .padding()
            .navigationTitle("M2 Reader Demo")
        }
    }

    // MARK: - Sections

    private var mockNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mock Mode")
                .font(.headline)
            Text("This screen uses a mocked reader service. It will not connect to real M2 hardware until the Stripe Terminal SDK is integrated.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Backend: \(AppConfig.backendURL.absoluteString)")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Location: \(AppConfig.readerLocationId)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(12)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reader Status")
                .font(.headline)
            Text(viewModel.connectionStatus.rawValue)
                .font(.title3)
                .foregroundColor(viewModel.connectionStatus == .connected ? .green : .secondary)
            Text(viewModel.lastActionMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var connectionControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connect to M2 Reader")
                .font(.headline)
            Text("Tap connect to start discovery and pair the M2 reader.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            HStack(spacing: 12) {
                Button("Connect") {
                    Task { await viewModel.connect() }
                }
                .buttonStyle(.borderedProminent)

                Button("Disconnect") {
                    Task { await viewModel.disconnect() }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var saleSimulator: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Simulate Sale")
                .font(.headline)
            Text("Enter an amount and tap charge to simulate a test payment.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                TextField("Amount", text: $viewModel.saleAmount)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Button("Charge") {
                    Task { await viewModel.charge() }
                }
                .buttonStyle(.borderedProminent)
            }

            Button("Refund Last Charge") {
                Task { await viewModel.refundLastCharge() }
            }
            .buttonStyle(.bordered)
        }
    }

    private var futureAutomationNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next: Vending Automation")
                .font(.headline)
            Text("After a real charge completes, the app will call a backend API. The backend will signal the Raspberry Pi over I2C to pulse the correct terminal for vending.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    ContentView()
}
