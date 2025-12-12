// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Tests/MLXChatAppUnitTests/PrivacySecurityTests.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class PrivacySecurityTests: XCTestCase {
//
// Living Docs:
//   - Main README: mlx-engine/Documentation/README.md
//   - Integration Roadmap: mlx-engine/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: mlx-engine/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: mlx-engine/Documentation/Internal/Development-Status/feature-completion.md
//
// Related Files (heuristic):

//
// Note for AI Agents:
//   - Keep this header accurate. If you rename/move files or change responsibilities,
//     update Key Types and Related Files. Add links to any additional living docs you create.
//   - Prefer tokens from StyleManager for colors/spacing; avoid hardcoded values.
//
// == End LLM Context Header ==
import XCTest
import SwiftUI
@testable import PocketChat
@testable import PocketCloudMLX

/// Unit tests for MLX Engine privacy and security features
/// Tests data protection, privacy controls, secure token management, and compliance
class PrivacySecurityTests: XCTestCase {

    private var chatEngine: ChatEngine!
    private var mockLLMEngine: MockLLMEngine!
    private var privacyManager: PrivacyManager!
    private let testTimeout: TimeInterval = 30.0

    override func setUp() async throws {
        // Use real engine by default, only use mock if explicitly requested
        let useMockTests = ProcessInfo.processInfo.environment["FORCE_MOCK_TESTS"] == "true"

        if useMockTests {
            mockLLMEngine = MockLLMEngine()
            chatEngine = try await ChatEngine(llmEngine: mockLLMEngine)
        } else {
            // Use real MLX engine for testing
            let config = ModelConfiguration(
                name: "SmolLM2 Test",
                hubId: "mlx-community/SmolLM2-360M-Instruct",
                description: "Real MLX model for testing (DEFAULT)",
                modelType: .llm,
                gpuCacheLimit: 512 * 1024 * 1024,
                features: []
            )
            let realEngine = try await InferenceEngine.loadModel(config) { _ in }
            chatEngine = try await ChatEngine(llmEngine: realEngine)
        }
        privacyManager = chatEngine.privacyManager
    }

    override func tearDown() async throws {
        await chatEngine?.cancelAllTasks()
        chatEngine = nil
        mockLLMEngine = nil
        privacyManager = PrivacyManager()
    }

    // MARK: - Data Retention Policies

    func testDataRetentionPolicyConfiguration() async throws {
        // Test none policy
        privacyManager.setDataRetentionPolicy(.none)
        XCTAssertEqual(privacyManager.dataRetentionPolicy, .none)

        // Test session policy
        privacyManager.setDataRetentionPolicy(.session)
        XCTAssertEqual(privacyManager.dataRetentionPolicy, .session)

        // Test temporary policy
        privacyManager.setDataRetentionPolicy(.temporary)
        XCTAssertEqual(privacyManager.dataRetentionPolicy, .temporary)

        // Test permanent policy
        privacyManager.setDataRetentionPolicy(.permanent)
        XCTAssertEqual(privacyManager.dataRetentionPolicy, .permanent)
    }

    func testDataRetentionPolicyDescriptions() async throws {
        let policies: [DataRetentionPolicy] = [.none, .session, .temporary, .permanent]

        for policy in policies {
            XCTAssertFalse(policy.displayName.isEmpty)
            XCTAssertFalse(policy.description.isEmpty)
            XCTAssertTrue(policy.displayName.count > 5)
            XCTAssertTrue(policy.description.count > 10)
        }
    }

    func testDataMinimization() async throws {
        let textWithPII = "My email is test@example.com and phone is 555-1234"

        privacyManager.setDataRetentionPolicy(.session) // Enables minimization

        let processedContext = privacyManager.processContext(
            ContextItem(type: .system, content: textWithPII)
        )

        XCTAssertFalse(processedContext.content.contains("@"))
        XCTAssertFalse(processedContext.content.contains("555-"))
        XCTAssertTrue(processedContext.content.contains("[EMAIL]") || processedContext.content.isEmpty)
    }

    // MARK: - Context Sharing Controls

    func testContextSharingEnableDisable() async throws {
        // Enable sharing
        privacyManager.setContextSharingEnabled(true)
        XCTAssertTrue(privacyManager.contextSharingEnabled)

        // Disable sharing
        privacyManager.setContextSharingEnabled(false)
        XCTAssertFalse(privacyManager.contextSharingEnabled)
    }

    func testContextSharingBlocking() async throws {
        privacyManager.setContextSharingEnabled(false)

        let contextItem = ContextItem(type: .webpage, content: "Test webpage content")

        do {
            _ = try await chatEngine.extractWebContext(from: URL(string: "https://example.com")!)
            // Should not reach here if privacy check is working
        } catch {
            // Expected behavior - context sharing disabled
            XCTAssertTrue(mockLLMEngine.privacyCheckPerformed)
        }
    }

    func testContextSharingWithVision() async throws {
        privacyManager.setContextSharingEnabled(false)
        let image = UIImage(systemName: "star")!

        do {
            _ = try await chatEngine.analyzeImage(image: image)
            XCTFail("Expected privacy error")
        } catch let error as PrivacyError {
            XCTAssertEqual(error, .sharingDisabled)
        } catch {
            // Privacy check should prevent vision processing
            XCTAssertTrue(mockLLMEngine.visionPrivacyCheckPerformed)
        }
    }

    // MARK: - Voice Data Storage Controls

    func testVoiceDataStorageEnableDisable() async throws {
        // Enable voice data storage
        privacyManager.setVoiceDataStorageEnabled(true)
        XCTAssertTrue(privacyManager.voiceDataStorageEnabled)

        // Disable voice data storage
        privacyManager.setVoiceDataStorageEnabled(false)
        XCTAssertFalse(privacyManager.voiceDataStorageEnabled)
    }

    func testVoiceDataStoragePrivacy() async throws {
        privacyManager.setVoiceDataStorageEnabled(false)

        let audioData = Data("mock audio data".utf8)
        let transcription = "Mock transcription"

        let processedVoiceData = privacyManager.processVoiceData(audioData: audioData, transcription: transcription)

        // Audio data should be discarded when storage is disabled
        XCTAssertNil(processedVoiceData.audioData)
        XCTAssertEqual(processedVoiceData.transcription, transcription)
    }

    func testVoiceDataStorageRetention() async throws {
        privacyManager.setVoiceDataStorageEnabled(true)
        privacyManager.setDataRetentionPolicy(.session)

        let audioData = Data("mock audio data".utf8)
        let transcription = "Mock transcription"

        let processedVoiceData = privacyManager.processVoiceData(audioData: audioData, transcription: transcription)

        // Audio data should be retained with session expiration
        XCTAssertNotNil(processedVoiceData.audioData)
        XCTAssertLessThan(processedVoiceData.expiresAt.timeIntervalSinceNow, 86401) // Within 24 hours
        XCTAssertGreaterThan(processedVoiceData.expiresAt.timeIntervalSinceNow, 0)
    }

    // MARK: - Secure Token Management

    func testSecureTokenStorage() async throws {
        let testToken = "hf_test_token_12345"

        // Simulate storing token securely
        try await chatEngine.storeSecureToken(testToken, for: .huggingFace)

        XCTAssertTrue(mockLLMEngine.tokenStoredSecurely)
        XCTAssertEqual(mockLLMEngine.storedToken, testToken)
    }

    func testTokenRetrieval() async throws {
        let testToken = "hf_retrieved_token_67890"

        mockLLMEngine.retrievedToken = testToken
        let retrievedToken = try await chatEngine.retrieveSecureToken(for: .huggingFace)

        XCTAssertEqual(retrievedToken, testToken)
        XCTAssertTrue(mockLLMEngine.tokenRetrievedSecurely)
    }

    func testTokenValidation() async throws {
        let validToken = "hf_valid_token_123"
        let invalidToken = "invalid_token"

        let validResult = try await chatEngine.validateToken(validToken, for: .huggingFace)
        XCTAssertTrue(validResult)

        let invalidResult = try await chatEngine.validateToken(invalidToken, for: .huggingFace)
        XCTAssertFalse(invalidResult)
    }

    func testTokenDeletion() async throws {
        let testToken = "hf_token_to_delete"

        try await chatEngine.storeSecureToken(testToken, for: .huggingFace)
        XCTAssertTrue(mockLLMEngine.tokenStoredSecurely)

        try await chatEngine.deleteSecureToken(for: .huggingFace)
        XCTAssertTrue(mockLLMEngine.tokenDeletedSecurely)
    }

    // MARK: - Data Sanitization

    func testEmailSanitization() async throws {
        let textWithEmails = "Contact me at test@example.com or support@company.org for help"

        let sanitized = try await chatEngine.sanitizeText(textWithEmails)

        XCTAssertFalse(sanitized.contains("@"))
        XCTAssertFalse(sanitized.contains("example.com"))
        XCTAssertFalse(sanitized.contains("company.org"))
        XCTAssertTrue(sanitized.contains("[EMAIL]"))
    }

    func testPhoneSanitization() async throws {
        let textWithPhones = "Call me at 555-1234 or (555) 987-6543"

        let sanitized = try await chatEngine.sanitizeText(textWithPhones)

        XCTAssertFalse(sanitized.contains("555-1234"))
        XCTAssertFalse(sanitized.contains("555) 987-6543"))
        XCTAssertTrue(sanitized.contains("[PHONE]"))
    }

    func testCombinedSanitization() async throws {
        let textWithBoth = "Contact john@doe.com at 555-1234 for the project"

        let sanitized = try await chatEngine.sanitizeText(textWithBoth)

        XCTAssertFalse(sanitized.contains("@"))
        XCTAssertFalse(sanitized.contains("555-1234"))
        XCTAssertTrue(sanitized.contains("[EMAIL]"))
        XCTAssertTrue(sanitized.contains("[PHONE]"))
    }

    // MARK: - Privacy Compliance

    func testPrivacyComplianceReport() async throws {
        let report = privacyManager.getPrivacyComplianceReport()

        XCTAssertNotNil(report.dataRetentionPolicy)
        XCTAssertNotNil(report.lastDataCleanup)
        XCTAssertNotNil(report.dataTypesStored)
        XCTAssertNotNil(report.thirdPartyServices)

        // Report should be populated
        XCTAssertFalse(report.dataTypesStored.isEmpty)
    }

    func testDataExport() async throws {
        let export = privacyManager.exportUserData()

        XCTAssertNotNil(export.conversations)
        XCTAssertNotNil(export.contextHistory)
        XCTAssertNotNil(export.preferences)
        XCTAssertGreaterThanOrEqual(export.exportDate.timeIntervalSinceNow, -1) // Within last second
    }

    func testDataCleanup() async throws {
        // Add some mock data
        _ = try await chatEngine.generateResponse("Test conversation")
        _ = try await chatEngine.extractWebContext(from: URL(string: "https://example.com")!)

        // Perform cleanup
        privacyManager.clearAllData()

        XCTAssertTrue(mockLLMEngine.allDataCleared)
        XCTAssertTrue(mockLLMEngine.temporaryFilesCleared)
        XCTAssertTrue(mockLLMEngine.cacheCleared)
    }

    func testExpiredDataCleanup() async throws {
        privacyManager.setDataRetentionPolicy(.temporary)

        // Add data that should expire
        _ = privacyManager.processContext(
            ContextItem(type: .webpage, content: "Temporary data")
        )

        privacyManager.cleanupExpiredData()

        XCTAssertTrue(mockLLMEngine.expiredDataCleaned)
    }

    // MARK: - Analytics Controls

    func testAnalyticsEnableDisable() async throws {
        // Enable analytics
        privacyManager.setAnalyticsEnabled(true)
        XCTAssertTrue(privacyManager.analyticsEnabled)

        // Disable analytics
        privacyManager.setAnalyticsEnabled(false)
        XCTAssertFalse(privacyManager.analyticsEnabled)
    }

    func testAnalyticsDataCollection() async throws {
        privacyManager.setAnalyticsEnabled(false)

        _ = try await chatEngine.generateResponse("Test prompt")

        // Analytics should be disabled
        XCTAssertFalse(mockLLMEngine.analyticsDataCollected)
    }

    func testAnalyticsWithPrivacy() async throws {
        privacyManager.setAnalyticsEnabled(true)
        privacyManager.setContextSharingEnabled(false)

        _ = try await chatEngine.generateResponse("Test prompt")

        // Analytics should respect privacy settings
        XCTAssertTrue(mockLLMEngine.analyticsPrivacyRespected)
    }

    // MARK: - Crash Reporting Controls

    func testCrashReportingEnableDisable() async throws {
        // Enable crash reporting
        privacyManager.setCrashReportingEnabled(true)
        XCTAssertTrue(privacyManager.crashReportingEnabled)

        // Disable crash reporting
        privacyManager.setCrashReportingEnabled(false)
        XCTAssertFalse(privacyManager.crashReportingEnabled)
    }

    func testCrashReportingAnonymization() async throws {
        privacyManager.setCrashReportingEnabled(true)

        // Simulate crash data with PII
        let crashData = "Crash at line 123 in file containing user@example.com"

        let anonymizedData = try await chatEngine.anonymizeCrashData(crashData)

        XCTAssertFalse(anonymizedData.contains("@"))
        XCTAssertFalse(anonymizedData.contains("user@example.com"))
        XCTAssertTrue(mockLLMEngine.crashDataAnonymized)
    }

    // MARK: - Data Encryption

    func testDataEncryptionAtRest() async throws {
        let sensitiveData = "Sensitive user information"

        let encrypted = try await chatEngine.encryptData(sensitiveData)

        XCTAssertNotEqual(encrypted, sensitiveData)
        XCTAssertTrue(encrypted.count > sensitiveData.count) // Encryption adds overhead

        let decrypted = try await chatEngine.decryptData(encrypted)
        XCTAssertEqual(decrypted, sensitiveData)

        XCTAssertTrue(mockLLMEngine.dataEncryptionPerformed)
    }

    func testEncryptionKeyManagement() async throws {
        // Test key generation
        try await chatEngine.generateEncryptionKey()
        XCTAssertTrue(mockLLMEngine.encryptionKeyGenerated)

        // Test key rotation
        try await chatEngine.rotateEncryptionKey()
        XCTAssertTrue(mockLLMEngine.encryptionKeyRotated)
    }

    // MARK: - Network Security

    func testSecureNetworkCommunication() async throws {
        let testURL = URL(string: "https://api.huggingface.co/models")!

        let response = try await chatEngine.makeSecureRequest(to: testURL)

        XCTAssertNotNil(response)
        XCTAssertTrue(mockLLMEngine.secureConnectionUsed)
        XCTAssertTrue(mockLLMEngine.sslCertificateValidated)
    }

    func testNetworkRequestLogging() async throws {
        privacyManager.setAnalyticsEnabled(false)

        _ = try await chatEngine.makeSecureRequest(to: URL(string: "https://example.com")!)

        // Network requests should not be logged when analytics disabled
        XCTAssertFalse(mockLLMEngine.networkRequestLogged)
    }

    // MARK: - File System Security

    func testSecureFileStorage() async throws {
        let sensitiveContent = "Sensitive file content"

        try await chatEngine.storeSecureFile(content: sensitiveContent, filename: "sensitive.txt")

        XCTAssertTrue(mockLLMEngine.fileStoredSecurely)
        XCTAssertTrue(mockLLMEngine.fileEncryptionApplied)
    }

    func testFileAccessControls() async throws {
        let content = "Test content"

        try await chatEngine.storeSecureFile(content: content, filename: "test.txt")

        // File should have restricted permissions
        XCTAssertTrue(mockLLMEngine.filePermissionsRestricted)
        XCTAssertFalse(mockLLMEngine.fileWorldReadable)
    }

    // MARK: - Privacy Audit

    func testPrivacyAudit() async throws {
        // Perform some operations that create audit trails
        _ = try await chatEngine.generateResponse("Audit test")
        _ = try await chatEngine.extractWebContext(from: URL(string: "https://example.com")!)

        let auditReport = try await chatEngine.generatePrivacyAuditReport()

        XCTAssertFalse(auditReport.isEmpty)
        XCTAssertTrue(auditReport.contains("Data Access"))
        XCTAssertTrue(mockLLMEngine.privacyAuditPerformed)
    }

    func testComplianceValidation() async throws {
        let complianceReport = try await chatEngine.validateCompliance()

        XCTAssertNotNil(complianceReport.gdprCompliant)
        XCTAssertNotNil(complianceReport.ccpaCompliant)
        XCTAssertNotNil(complianceReport.dataRetentionCompliant)

        XCTAssertTrue(mockLLMEngine.complianceValidationPerformed)
    }

    // MARK: - Secure Memory Management

    func testSecureMemoryWiping() async throws {
        let sensitiveData = "Sensitive information in memory"

        // Data should be wiped after use
        try await chatEngine.processSensitiveData(sensitiveData)

        XCTAssertTrue(mockLLMEngine.memoryWipedSecurely)
        XCTAssertFalse(mockLLMEngine.sensitiveDataRemainedInMemory)
    }

    func testMemoryLeakPrevention() async throws {
        // Process multiple pieces of sensitive data
        for i in 1...5 {
            let data = "Sensitive data \(i)"
            try await chatEngine.processSensitiveData(data)
        }

        XCTAssertTrue(mockLLMEngine.memoryLeaksPrevented)
        XCTAssertEqual(mockLLMEngine.processedSensitiveItemsCount, 5)
    }

    // MARK: - Third-party Service Privacy

    func testThirdPartyDataSharing() async throws {
        privacyManager.setContextSharingEnabled(false)

        let result = try await chatEngine.queryThirdPartyService("test query")

        // No data should be shared with third parties
        XCTAssertFalse(mockLLMEngine.dataSharedWithThirdParty)
        XCTAssertTrue(mockLLMEngine.thirdPartyPrivacyRespected)
    }

    func testThirdPartyDataMinimization() async throws {
        privacyManager.setContextSharingEnabled(true)
        privacyManager.setDataRetentionPolicy(.session)

        _ = try await chatEngine.queryThirdPartyService("test query")

        XCTAssertTrue(mockLLMEngine.thirdPartyDataMinimized)
        XCTAssertFalse(mockLLMEngine.excessiveDataShared)
    }

    // MARK: - User Consent Management

    func testUserConsentTracking() async throws {
        // Grant consent
        try await chatEngine.grantConsent(for: .analytics)
        XCTAssertTrue(mockLLMEngine.consentGrantedForAnalytics)

        // Revoke consent
        try await chatEngine.revokeConsent(for: .analytics)
        XCTAssertTrue(mockLLMEngine.consentRevokedForAnalytics)
    }

    func testConsentBasedFeatureAccess() async throws {
        // Revoke all consents
        try await chatEngine.revokeConsent(for: .analytics)
        try await chatEngine.revokeConsent(for: .crashReporting)

        // Features requiring consent should be disabled
        XCTAssertFalse(mockLLMEngine.analyticsFeatureAccessible)
        XCTAssertFalse(mockLLMEngine.crashReportingFeatureAccessible)
    }

    func testConsentPersistence() async throws {
        try await chatEngine.grantConsent(for: .analytics)

        // Simulate app restart
        let newChatEngine = ChatEngine(llmEngine: MockLLMEngine())

        // Consent should persist
        XCTAssertTrue(mockLLMEngine.consentPersisted)
    }
}

// MARK: - Supporting Types

enum ConsentType {
    case analytics
    case crashReporting
    case dataSharing
    case personalization
}

// MARK: - Mock Extensions

extension MockLLMEngine {
    var privacyCheckPerformed: Bool {
        get { return objc_getAssociatedObject(self, &privacyCheckPerformedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &privacyCheckPerformedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var visionPrivacyCheckPerformed: Bool {
        get { return objc_getAssociatedObject(self, &visionPrivacyCheckPerformedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &visionPrivacyCheckPerformedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var tokenStoredSecurely: Bool {
        get { return objc_getAssociatedObject(self, &tokenStoredSecurelyKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &tokenStoredSecurelyKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var storedToken: String? {
        get { return objc_getAssociatedObject(self, &storedTokenKey) as? String }
        set { objc_setAssociatedObject(self, &storedTokenKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var tokenRetrievedSecurely: Bool {
        get { return objc_getAssociatedObject(self, &tokenRetrievedSecurelyKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &tokenRetrievedSecurelyKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var retrievedToken: String? {
        get { return objc_getAssociatedObject(self, &retrievedTokenKey) as? String }
        set { objc_setAssociatedObject(self, &retrievedTokenKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var allDataCleared: Bool {
        get { return objc_getAssociatedObject(self, &allDataClearedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &allDataClearedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var temporaryFilesCleared: Bool {
        get { return objc_getAssociatedObject(self, &temporaryFilesClearedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &temporaryFilesClearedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var cacheCleared: Bool {
        get { return objc_getAssociatedObject(self, &cacheClearedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &cacheClearedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var expiredDataCleaned: Bool {
        get { return objc_getAssociatedObject(self, &expiredDataCleanedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &expiredDataCleanedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var analyticsDataCollected: Bool {
        get { return objc_getAssociatedObject(self, &analyticsDataCollectedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &analyticsDataCollectedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var analyticsPrivacyRespected: Bool {
        get { return objc_getAssociatedObject(self, &analyticsPrivacyRespectedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &analyticsPrivacyRespectedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var crashDataAnonymized: Bool {
        get { return objc_getAssociatedObject(self, &crashDataAnonymizedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &crashDataAnonymizedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var dataEncryptionPerformed: Bool {
        get { return objc_getAssociatedObject(self, &dataEncryptionPerformedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &dataEncryptionPerformedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var encryptionKeyGenerated: Bool {
        get { return objc_getAssociatedObject(self, &encryptionKeyGeneratedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &encryptionKeyGeneratedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var encryptionKeyRotated: Bool {
        get { return objc_getAssociatedObject(self, &encryptionKeyRotatedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &encryptionKeyRotatedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var secureConnectionUsed: Bool {
        get { return objc_getAssociatedObject(self, &secureConnectionUsedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &secureConnectionUsedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var sslCertificateValidated: Bool {
        get { return objc_getAssociatedObject(self, &sslCertificateValidatedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &sslCertificateValidatedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var networkRequestLogged: Bool {
        get { return objc_getAssociatedObject(self, &networkRequestLoggedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &networkRequestLoggedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var fileStoredSecurely: Bool {
        get { return objc_getAssociatedObject(self, &fileStoredSecurelyKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &fileStoredSecurelyKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var fileEncryptionApplied: Bool {
        get { return objc_getAssociatedObject(self, &fileEncryptionAppliedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &fileEncryptionAppliedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var filePermissionsRestricted: Bool {
        get { return objc_getAssociatedObject(self, &filePermissionsRestrictedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &filePermissionsRestrictedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var fileWorldReadable: Bool {
        get { return objc_getAssociatedObject(self, &fileWorldReadableKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &fileWorldReadableKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var privacyAuditPerformed: Bool {
        get { return objc_getAssociatedObject(self, &privacyAuditPerformedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &privacyAuditPerformedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var complianceValidationPerformed: Bool {
        get { return objc_getAssociatedObject(self, &complianceValidationPerformedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &complianceValidationPerformedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var memoryWipedSecurely: Bool {
        get { return objc_getAssociatedObject(self, &memoryWipedSecurelyKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &memoryWipedSecurelyKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var sensitiveDataRemainedInMemory: Bool {
        get { return objc_getAssociatedObject(self, &sensitiveDataRemainedInMemoryKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &sensitiveDataRemainedInMemoryKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var memoryLeaksPrevented: Bool {
        get { return objc_getAssociatedObject(self, &memoryLeaksPreventedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &memoryLeaksPreventedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var processedSensitiveItemsCount: Int {
        get { return objc_getAssociatedObject(self, &processedSensitiveItemsCountKey) as? Int ?? 0 }
        set { objc_setAssociatedObject(self, &processedSensitiveItemsCountKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var dataSharedWithThirdParty: Bool {
        get { return objc_getAssociatedObject(self, &dataSharedWithThirdPartyKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &dataSharedWithThirdPartyKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var thirdPartyPrivacyRespected: Bool {
        get { return objc_getAssociatedObject(self, &thirdPartyPrivacyRespectedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &thirdPartyPrivacyRespectedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var thirdPartyDataMinimized: Bool {
        get { return objc_getAssociatedObject(self, &thirdPartyDataMinimizedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &thirdPartyDataMinimizedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var excessiveDataShared: Bool {
        get { return objc_getAssociatedObject(self, &excessiveDataSharedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &excessiveDataSharedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var consentGrantedForAnalytics: Bool {
        get { return objc_getAssociatedObject(self, &consentGrantedForAnalyticsKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &consentGrantedForAnalyticsKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var consentRevokedForAnalytics: Bool {
        get { return objc_getAssociatedObject(self, &consentRevokedForAnalyticsKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &consentRevokedForAnalyticsKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var analyticsFeatureAccessible: Bool {
        get { return objc_getAssociatedObject(self, &analyticsFeatureAccessibleKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &analyticsFeatureAccessibleKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var crashReportingFeatureAccessible: Bool {
        get { return objc_getAssociatedObject(self, &crashReportingFeatureAccessibleKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &crashReportingFeatureAccessibleKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var consentPersisted: Bool {
        get { return objc_getAssociatedObject(self, &consentPersistedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &consentPersistedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}

// Associated object keys
private var privacyCheckPerformedKey: UInt8 = 0
private var visionPrivacyCheckPerformedKey: UInt8 = 0
private var tokenStoredSecurelyKey: UInt8 = 0
private var storedTokenKey: UInt8 = 0
private var tokenRetrievedSecurelyKey: UInt8 = 0
private var retrievedTokenKey: UInt8 = 0
private var allDataClearedKey: UInt8 = 0
private var temporaryFilesClearedKey: UInt8 = 0
private var cacheClearedKey: UInt8 = 0
private var expiredDataCleanedKey: UInt8 = 0
private var analyticsDataCollectedKey: UInt8 = 0
private var analyticsPrivacyRespectedKey: UInt8 = 0
private var crashDataAnonymizedKey: UInt8 = 0
private var dataEncryptionPerformedKey: UInt8 = 0
private var encryptionKeyGeneratedKey: UInt8 = 0
private var encryptionKeyRotatedKey: UInt8 = 0
private var secureConnectionUsedKey: UInt8 = 0
private var sslCertificateValidatedKey: UInt8 = 0
private var networkRequestLoggedKey: UInt8 = 0
private var fileStoredSecurelyKey: UInt8 = 0
private var fileEncryptionAppliedKey: UInt8 = 0
private var filePermissionsRestrictedKey: UInt8 = 0
private var fileWorldReadableKey: UInt8 = 0
private var privacyAuditPerformedKey: UInt8 = 0
private var complianceValidationPerformedKey: UInt8 = 0
private var memoryWipedSecurelyKey: UInt8 = 0
private var sensitiveDataRemainedInMemoryKey: UInt8 = 0
private var memoryLeaksPreventedKey: UInt8 = 0
private var processedSensitiveItemsCountKey: UInt8 = 0
private var dataSharedWithThirdPartyKey: UInt8 = 0
private var thirdPartyPrivacyRespectedKey: UInt8 = 0
private var thirdPartyDataMinimizedKey: UInt8 = 0
private var excessiveDataSharedKey: UInt8 = 0
private var consentGrantedForAnalyticsKey: UInt8 = 0
private var consentRevokedForAnalyticsKey: UInt8 = 0
private var analyticsFeatureAccessibleKey: UInt8 = 0
private var crashReportingFeatureAccessibleKey: UInt8 = 0
private var consentPersistedKey: UInt8 = 0
