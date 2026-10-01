import Foundation
import Observation

/// The single orchestrator for "capture -> scored result -> persisted" —
/// mirrors `pendingAnalysisProvider` in the Flutter app.
@Observable
@MainActor
final class ScanCoordinator {
    enum State: Equatable {
        case idle
        case analyzing
        case failed(String)
    }

    private(set) var state: State = .idle

    private let analysisService: AnalysisService
    private let lastResult: LastResultModel
    private let history: ScanHistoryModel

    init(
        analysisService: AnalysisService,
        lastResult: LastResultModel,
        history: ScanHistoryModel
    ) {
        self.analysisService = analysisService
        self.lastResult = lastResult
        self.history = history
    }

    /// First-launch previews are stored as the latest result but deliberately
    /// omitted from history, so they do not consume the subscriber allowance.
    @discardableResult
    func run(_ input: ScanInput, recordInHistory: Bool = true) async -> ScanResult? {
        let began = Date()
        let context: [String: Any] = ["source": String(describing: input.source),
                                      "mode": recordInHistory ? "subscriber" : "onboarding"]
        AppAnalytics.shared.track(.analysisStarted, context)
        state = .analyzing
        do {
            let result = try await analysisService.analyze(input)
            // If the user cancelled during analysis, don't record the scan.
            guard !Task.isCancelled else {
                AppAnalytics.shared.track(.analysisCancelled, context)
                return nil
            }
            lastResult.set(result)
            if recordInHistory {
                recordResultInHistory(result)
            }
            state = .idle
            AppAnalytics.shared.track(.analysisCompleted, context.merging(["duration_seconds": Date().timeIntervalSince(began)]) { _, new in new })
            return result
        } catch is CancellationError {
            AppAnalytics.shared.track(.analysisCancelled, context)
            return nil
        } catch {
            guard !Task.isCancelled else { return nil }
            AppAnalytics.shared.track(.analysisFailed, context.merging(["error_code": (error as NSError).code]) { _, new in new })
            state = .failed(error.localizedDescription)
            return nil
        }
    }

    /// Promotes a locked onboarding result to the user's permanent history
    /// after RevenueCat confirms Pro. The entry ID guard makes it safe to call
    /// again after an app relaunch or entitlement refresh.
    func recordResultInHistory(_ result: ScanResult) {
        let entryId = ScanHistoryEntry.id(forCapturedAt: result.input.capturedAt)
        guard !history.entries.contains(where: { $0.id == entryId }) else { return }

        history.append(result)
        let path = ScanImageStore.currentPath(forStoredPath: result.input.imagePath)
        Task.detached { ScanPhotoLibrary.save(fromPath: path, id: entryId) }
    }
}
