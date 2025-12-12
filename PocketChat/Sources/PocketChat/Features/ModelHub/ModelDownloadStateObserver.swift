import Foundation
import Combine

/// Lightweight observable wrapper that forwards a throttled subset of ModelDiscoveryManager state
/// so views can react to download progress without observing the manager's entire publisher surface.
@MainActor
final class ModelDownloadStateObserver: ObservableObject {
    @Published private(set) var downloadingModels: Set<String> = []
    @Published private(set) var downloadProgress: [String: Double] = [:]
    @Published private(set) var totalBytesByModel: [String: Int64] = [:]
    @Published private(set) var downloadedBytesByModel: [String: Int64] = [:]
    @Published private(set) var downloadedModelIds: Set<String> = []
    @Published private(set) var activeDownloadFiles: [String: ModelDiscoveryManager.ActiveDownloadFile] = [:]
    @Published private(set) var verifyingModels: Set<String> = []
    @Published private(set) var verificationMessages: [String: [String]] = [:]
    @Published private(set) var verificationProgress: [String: Double] = [:]
    @Published private(set) var verifyMissingCount: [String: Int] = [:]
    @Published private(set) var verifyCorruptCount: [String: Int] = [:]
    @Published private(set) var verifyRepairedCount: [String: Int] = [:]
    @Published private(set) var verifyTotalToRepair: [String: Int] = [:]
    @Published private(set) var verifyScanIndex: [String: Int] = [:]
    @Published private(set) var verifyScanTotal: [String: Int] = [:]
    @Published private(set) var verifySrcBytes: [String: Int64] = [:]
    @Published private(set) var verifyTgtBytes: [String: Int64] = [:]
    @Published private(set) var verifySourcePath: [String: String] = [:]
    @Published private(set) var verifyTargetPath: [String: String] = [:]
    @Published private(set) var downloadErrors: [String: ModelDiscoveryManager.DownloadErrorInfo] = [:]

    private let manager: ModelDiscoveryManager
    private var cancellables: Set<AnyCancellable> = []

    init(manager: ModelDiscoveryManager? = nil) {
        let resolvedManager = manager ?? ModelDiscoveryManager.shared
        self.manager = resolvedManager
        bind()
    }

    private func bind() {
        bind(manager.$downloadingModels, to: \.downloadingModels)
        bind(manager.$downloadProgress, to: \.downloadProgress, throttle: .milliseconds(150))
        bind(manager.$totalBytesByModel, to: \.totalBytesByModel)
        bind(manager.$downloadedBytesByModel, to: \.downloadedBytesByModel, throttle: .milliseconds(150))
        bind(manager.$downloadedModelIds, to: \.downloadedModelIds)
        bind(manager.$activeDownloadFiles, to: \.activeDownloadFiles, throttle: .milliseconds(200))
        bind(manager.$verifyingModels, to: \.verifyingModels)
        bind(manager.$verificationMessages, to: \.verificationMessages, throttle: .milliseconds(150))
        bind(manager.$verificationProgress, to: \.verificationProgress, throttle: .milliseconds(200))
        bind(manager.$verifyMissingCount, to: \.verifyMissingCount)
        bind(manager.$verifyCorruptCount, to: \.verifyCorruptCount)
        bind(manager.$verifyRepairedCount, to: \.verifyRepairedCount)
        bind(manager.$verifyTotalToRepair, to: \.verifyTotalToRepair)
        bind(manager.$verifyScanIndex, to: \.verifyScanIndex)
        bind(manager.$verifyScanTotal, to: \.verifyScanTotal)
        bind(manager.$verifySrcBytes, to: \.verifySrcBytes)
        bind(manager.$verifyTgtBytes, to: \.verifyTgtBytes)
        bind(manager.$verifySourcePath, to: \.verifySourcePath)
        bind(manager.$verifyTargetPath, to: \.verifyTargetPath)
        bind(manager.$downloadErrors, to: \.downloadErrors)
    }

    private func bind<T: Equatable>(
        _ publisher: Published<T>.Publisher,
        to keyPath: ReferenceWritableKeyPath<ModelDownloadStateObserver, T>,
        throttle: RunLoop.SchedulerTimeType.Stride? = nil
    ) {
        var stream = publisher
            .removeDuplicates()
            .eraseToAnyPublisher()

        if let throttle {
            stream = stream
                .throttle(for: throttle, scheduler: RunLoop.main, latest: true)
                .eraseToAnyPublisher()
        }

        stream
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?[keyPath: keyPath] = value
            }
            .store(in: &cancellables)
    }
}
