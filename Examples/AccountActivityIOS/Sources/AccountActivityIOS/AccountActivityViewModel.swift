import AccountActivityIOSCore
import Observation

@MainActor
@Observable
final class AccountActivityViewModel {
    var addressText = "11111111111111111111111111111111"
    var selectedEndpointID = ActivityEndpoint.mainnetBeta.id
    var selectedLimit = 10
    private(set) var snapshot: AccountActivitySnapshot?
    private(set) var errorMessage: String?
    private(set) var isLoading = false

    @ObservationIgnored let limitOptions = [5, 10, 20]
    @ObservationIgnored private let service: AccountActivityService

    init(service: AccountActivityService = AccountActivityService()) {
        self.service = service
    }

    var canSubmit: Bool {
        !isLoading && !addressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var statusText: String {
        if isLoading {
            return "Fetching balance and signatures"
        }
        if snapshot != nil {
            return "Activity loaded"
        }
        return "Ready"
    }

    func lookup() async {
        let address = addressText
        let endpoint = selectedEndpoint
        let limit = selectedLimit
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            snapshot = try await service.lookup(addressText: address, endpoint: endpoint, limit: limit)
        } catch {
            snapshot = nil
            errorMessage = error.localizedDescription
        }
    }

    private var selectedEndpoint: ActivityEndpoint {
        ActivityEndpoint.presets.first { $0.id == selectedEndpointID } ?? .mainnetBeta
    }
}
