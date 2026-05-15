import BalanceMacCore
import Observation
import SwiftUI

struct BalanceDashboardView: View {
    @State private var viewModel: BalanceDashboardViewModel

    init(service: BalanceLookupService = BalanceLookupService()) {
        _viewModel = State(initialValue: BalanceDashboardViewModel(service: service))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Address", text: $viewModel.addressText)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Cluster") {
                    Picker("Endpoint", selection: $viewModel.selectedEndpointID) {
                        ForEach(SolanaEndpoint.presets) { endpoint in
                            Text(endpoint.name).tag(endpoint.id)
                        }
                    }
                    if viewModel.selectedEndpointID == SolanaEndpoint.custom.id {
                        TextField("Endpoint URL", text: $viewModel.customEndpointText)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Section {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Label("Check Balance", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                }

                if let snapshot = viewModel.snapshot {
                    Section("Balance") {
                        LabeledContent("Lamports", value: "\(snapshot.lamports)")
                        LabeledContent("SOL", value: snapshot.solText)
                        LabeledContent("Slot", value: "\(snapshot.slot)")
                        LabeledContent("Endpoint", value: snapshot.endpoint.name)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section("Error") {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("BalanceMac")
            .task {
                await viewModel.refreshIfNeeded()
            }
        }
    }
}
