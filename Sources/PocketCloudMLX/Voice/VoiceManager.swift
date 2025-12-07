// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/Voice/VoiceManager.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class VoiceManager: NSObject, ObservableObject {
//   - extension VoiceManager: AVSpeechSynthesizerDelegate {
//
// Living Docs:
//   - Main README: pocket-cloud-mlx/Documentation/README.md
//   - Integration Roadmap: pocket-cloud-mlx/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: pocket-cloud-mlx/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: pocket-cloud-mlx/Documentation/Internal/Development-Status/feature-completion.md
//
// Related Files (heuristic):

//
// Note for AI Agents:
//   - Keep this header accurate. If you rename/move files or change responsibilities,
//     update Key Types and Related Files. Add links to any additional living docs you create.
//   - Prefer tokens from StyleManager for colors/spacing; avoid hardcoded values.
//
// == End LLM Context Header ==
import Foundation
import Speech
import AVFoundation
import PocketCloudLogger

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Manages voice input and output capabilities
@MainActor
public class VoiceManager: NSObject, ObservableObject {
    private let logger = Logger(label: "VoiceManager")
    
    @Published public var isListening = false
    @Published public var transcribedText = ""
    @Published public var isSpeaking = false
    @Published public var speechRecognitionAvailable = false
    @Published public var speechSynthesisAvailable = false
    
    private let speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    public override init() {
        // Initialize speech recognizer for current locale
        self.speechRecognizer = SFSpeechRecognizer()
        
        super.init()
        
        // Set up synthesizer delegate
        synthesizer.delegate = self
        
        // Check availability
        self.speechRecognitionAvailable = speechRecognizer?.isAvailable ?? false
        self.speechSynthesisAvailable = true // AVSpeechSynthesizer is always available
        
        logger.info("VoiceManager initialized - Recognition: \(self.speechRecognitionAvailable), Synthesis: \(self.speechSynthesisAvailable)")
        
        // Request permissions
        requestPermissions()
    }
    
    // MARK: - Permission Management
    
    /// Request necessary permissions for speech recognition and audio recording
    public func requestPermissions() {
        // Request speech recognition permission
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.speechRecognitionAvailable = status == .authorized
                self?.logger.info("Speech recognition authorization: \(status.rawValue)")
            }
        }
        
        // Request microphone permission
        #if os(iOS)
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.logger.info("Microphone permission: \(granted)")
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.logger.info("Microphone permission: \(granted)")
                }
            }
        }
        #else
        // On macOS, microphone permission is handled differently
        logger.info("Microphone permission: assumed granted on macOS")
        #endif
    }
    
    // MARK: - Speech Recognition
    
    /// Start listening for speech input
    public func startListening() async throws {
        guard speechRecognitionAvailable else {
            throw VoiceError.speechRecognitionNotAvailable
        }
        
        guard !isListening else {
            logger.warning("Already listening")
            return
        }
        
        // Cancel any previous task
        if let task = recognitionTask {
            task.cancel()
            recognitionTask = nil
        }
        
        // Configure audio session
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceError.recognitionRequestCreationFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Get input node
        let inputNode = audioEngine.inputNode
        
        // Create recognition task
        guard let speechRecognizer = speechRecognizer else {
            throw VoiceError.speechRecognitionNotAvailable
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.transcribedText = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        self?.stopListening()
                    }
                }
                
                if let error = error {
                    self?.logger.error("Speech recognition error: \(error.localizedDescription)")
                    self?.stopListening()
                }
            }
        }
        
        // Configure audio format
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        isListening = true
        transcribedText = ""
        
        logger.info("Started speech recognition")
    }
    
    /// Stop listening for speech input
    public func stopListening() {
        guard isListening else { return }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isListening = false
        
        logger.info("Stopped speech recognition")
    }
    
    // MARK: - Speech Synthesis
    
    /// Speak the given text
    public func speak(_ text: String, rate: Float = 0.5, pitch: Float = 1.0, volume: Float = 1.0) {
        guard !text.isEmpty else { return }
        
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        
        // Configure voice settings
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.volume = volume
        
        // Use default voice for current locale
        if let voice = AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier ?? "en-US") {
            utterance.voice = voice
        }
        
        isSpeaking = true
        synthesizer.speak(utterance)
        
        logger.info("Started speaking text: \(text.prefix(50))...")
    }
    
    /// Stop current speech synthesis
    public func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            logger.info("Stopped speaking")
        }
    }
    
    /// Pause current speech synthesis
    public func pauseSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .immediate)
            logger.info("Paused speaking")
        }
    }
    
    /// Resume paused speech synthesis
    public func resumeSpeaking() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
            logger.info("Resumed speaking")
        }
    }
    
    // MARK: - Voice Settings
    
    /// Get available voices for the current locale
    public func getAvailableVoices() -> [AVSpeechSynthesisVoice] {
        let currentLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        return AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language.hasPrefix(currentLanguage)
        }
    }
    
    /// Set preferred voice for speech synthesis
    public func setPreferredVoice(_ voice: AVSpeechSynthesisVoice) {
        // Store preference for future utterances
        UserDefaults.standard.set(voice.identifier, forKey: "preferredVoiceIdentifier")
        logger.info("Set preferred voice: \(voice.name)")
    }
    
    /// Get preferred voice or default
    public func getPreferredVoice() -> AVSpeechSynthesisVoice? {
        if let identifier = UserDefaults.standard.string(forKey: "preferredVoiceIdentifier"),
           let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice
        }
        
        // Return default voice for current locale
        return AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier ?? "en-US")
    }
    
    // MARK: - Utility Methods
    
    /// Check if device supports speech recognition
    public func checkSpeechRecognitionSupport() -> Bool {
        return speechRecognizer?.isAvailable ?? false
    }
    
    /// Get current speech recognition locale
    public func getCurrentLocale() -> Locale? {
        return speechRecognizer?.locale
    }
    
    /// Set speech recognition locale
    public func setSpeechRecognitionLocale(_ locale: Locale) -> Bool {
        // Note: This would require reinitializing the speech recognizer
        // For now, we'll just log the request
        logger.info("Speech recognition locale change requested: \(locale.identifier)")
        return false // Not implemented in this version
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceManager: AVSpeechSynthesizerDelegate {
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.logger.info("Speech synthesis started")
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.logger.info("Speech synthesis finished")
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.logger.info("Speech synthesis cancelled")
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.logger.info("Speech synthesis paused")
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.logger.info("Speech synthesis resumed")
        }
    }
}

// MARK: - Voice Errors

public enum VoiceError: LocalizedError {
    case speechRecognitionNotAvailable
    case recognitionRequestCreationFailed
    case audioEngineStartFailed
    case microphonePermissionDenied
    case speechSynthesisNotAvailable
    
    public var errorDescription: String? {
        switch self {
        case .speechRecognitionNotAvailable:
            return "Speech recognition is not available on this device"
        case .recognitionRequestCreationFailed:
            return "Failed to create speech recognition request"
        case .audioEngineStartFailed:
            return "Failed to start audio engine"
        case .microphonePermissionDenied:
            return "Microphone permission is required for speech recognition"
        case .speechSynthesisNotAvailable:
            return "Speech synthesis is not available"
        }
    }
}

// MARK: - Voice Commands

public struct VoiceCommand {
    public let trigger: String
    public let action: () -> Void
    public let description: String
    
    public init(trigger: String, description: String, action: @escaping () -> Void) {
        self.trigger = trigger
        self.description = description
        self.action = action
    }
}

/// Voice command processor for handling specific voice commands
public class VoiceCommandProcessor {
    private let logger = Logger(label: "VoiceCommandProcessor")
    private var commands: [VoiceCommand] = []
    
    public init() {
        setupDefaultCommands()
    }
    
    /// Add a custom voice command
    public func addCommand(_ command: VoiceCommand) {
        commands.append(command)
        logger.info("Added voice command: \(command.trigger)")
    }
    
    /// Process transcribed text for voice commands
    public func processText(_ text: String) -> Bool {
        let lowercaseText = text.lowercased()
        
        for command in commands {
            if lowercaseText.contains(command.trigger.lowercased()) {
                command.action()
                logger.info("Executed voice command: \(command.trigger)")
                return true
            }
        }
        
        return false
    }
    
    /// Get all available commands
    public func getAvailableCommands() -> [VoiceCommand] {
        return commands
    }
    
    private func setupDefaultCommands() {
        // Add default commands
        addCommand(VoiceCommand(
            trigger: "clear chat",
            description: "Clear the current chat conversation"
        ) {
            // This would be implemented by the chat view model
        })
        
        addCommand(VoiceCommand(
            trigger: "stop listening",
            description: "Stop voice input"
        ) {
            // This would stop the voice manager
        })
        
        addCommand(VoiceCommand(
            trigger: "stop speaking",
            description: "Stop voice output"
        ) {
            // This would stop speech synthesis
        })
    }
} 