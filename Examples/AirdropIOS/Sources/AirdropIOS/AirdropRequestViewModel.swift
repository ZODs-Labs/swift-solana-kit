import AirdropIOSCore
import Observation

@MainActor
@Observable
final class AirdropRequestViewModel {
    var addressText = "11111111111111111111111111111111"
    var solAmountText = "1"
    var selectedEndpointID = AirdropEndpoint.devnet.id
    private(set) var result: AirdropRequestResult?
    private(set) var errorMessage: String?
    private(set) var isLoading = false

    @ObservationIgnored private let service: AirdropRequestService

    init(service: AirdropRequestService = AirdropRequestService()) {
        self.service = service
    }

    var canSubmit: Bool {
        !isLoading && !addressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func requestAirdrop() async {
        let address = addressText
        let amount = solAmountText
        let endpoint = selectedEndpoint
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            result = try await service.request(addressText: address, solAmountText: amount, endpoint: endpoint)
        } catch {
            result = nil
            errorMessage = error.localizedDescription
        }
    }

    private var selectedEndpoint: AirdropEndpoint {
        AirdropEndpoint.presets.first { $0.id == selectedEndpointID } ?? .devnet
    }
}
