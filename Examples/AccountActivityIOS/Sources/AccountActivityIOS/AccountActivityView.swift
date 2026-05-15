import AccountActivityIOSCore
import Observation
import SwiftUI

struct AccountActivityView: View {
    @State private var viewModel: AccountActivityViewModel

    init(service: AccountActivityService = AccountActivityService()) {
        _viewModel = State(initialValue: AccountActivityViewModel(service: service))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section {
                    TextField("Public address", text: $viewModel.addressText)
                        .solanaAddressInput()
                    Text(viewModel.statusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("1 Address", systemImage: "1.circle")
                }

                Section {
                    Picker("Cluster", selection: $viewModel.selectedEndpointID) {
                        ForEach(ActivityEndpoint.presets) { endpoint in
                            Text(endpoint.name).tag(endpoint.id)
                        }
                    }
                    Picker("History", selection: $viewModel.selectedLimit) {
                        ForEach(viewModel.limitOptions, id: \.self) { limit in
                            Text("\(limit)").tag(limit)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Label("2 Network", systemImage: "2.circle")
                } footer: {
                    Text("History controls how many recent signatures are requested.")
                }

                Section {
                    Button {
                        Task { await viewModel.lookup() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Label("Fetch Activity", systemImage: "list.bullet.rectangle")
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                } header: {
                    Label("3 Lookup", systemImage: "3.circle")
                }

                if let snapshot = viewModel.snapshot {
                    balanceSection(snapshot)
                    activitySection(snapshot.signatures)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section("Error") {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("AccountActivity")
        }
    }

    private func balanceSection(_ snapshot: AccountActivitySnapshot) -> some View {
        Section("Balance") {
            LabeledContent("SOL", value: snapshot.solText)
            LabeledContent("Lamports", value: "\(snapshot.lamports)")
            LabeledContent("Slot", value: "\(snapshot.slot)")
            LabeledContent("Cluster", value: snapshot.endpoint.name)
        }
    }

    private func activitySection(_ signatures: [ActivitySignatureSummary]) -> some View {
        Section("Recent Activity") {
            if signatures.isEmpty {
                Text("No recent signatures were returned for this address.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(signatures) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.shortSignature)
                                .font(.headline.monospaced())
                            Spacer()
                            Text(item.statusText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(item.isSuccessful ? .green : .red)
                        }
                        LabeledContent("Slot", value: "\(item.slot)")
                            .font(.footnote)
                        if let blockTimeText = item.blockTimeText {
                            LabeledContent("Time", value: blockTimeText)
                                .font(.footnote)
                        }
                        if let memo = item.memo, !memo.isEmpty {
                            Text(memo)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
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
}
