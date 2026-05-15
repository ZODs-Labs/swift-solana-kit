import AirdropIOSCore
import Observation
import SwiftUI

struct AirdropRequestView: View {
    @State private var viewModel: AirdropRequestViewModel

    init(service: AirdropRequestService = AirdropRequestService()) {
        _viewModel = State(initialValue: AirdropRequestViewModel(service: service))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section("Recipient") {
                    TextField("Address", text: $viewModel.addressText)
                        .solanaAddressInput()
                }

                Section("Amount") {
                    TextField("SOL", text: $viewModel.solAmountText)
                        .solAmountInput()
                    Text("Devnet faucet requests are capped at 2 SOL in this example.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Endpoint") {
                    Picker("Cluster", selection: $viewModel.selectedEndpointID) {
                        ForEach(AirdropEndpoint.presets) { endpoint in
                            Text(endpoint.name).tag(endpoint.id)
                        }
                    }
                }

                Section {
                    Button {
                        Task { await viewModel.requestAirdrop() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Label("Request Devnet Airdrop", systemImage: "drop.fill")
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                }

                if let result = viewModel.result {
                    Section("Result") {
                        LabeledContent("Signature", value: result.signature.rawValue)
                        LabeledContent("Requested", value: "\(result.requestedSolText) SOL")
                        if let balance = result.balanceAfterLamports {
                            LabeledContent("Balance", value: "\(solDisplayString(from: balance)) SOL")
                        }
                        if let slot = result.balanceSlot {
                            LabeledContent("Slot", value: "\(slot)")
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section("Error") {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("AirdropIOS")
        }
    }
}

private extension View {
    @ViewBuilder
    func solanaAddressInput() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }

    @ViewBuilder
    func solAmountInput() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }
}
