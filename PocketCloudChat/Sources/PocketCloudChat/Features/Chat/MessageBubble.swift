// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Chat/MessageBubble.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct MessageBubble: View {
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
import SwiftUI
import PocketCloudMLX

struct MessageBubble: View {
    let message: ChatMessage
    let isStreaming: Bool
    let performanceOverride: ChatMessage.PerformanceInfo?
    let onRegenerate: (() -> Void)?
    @EnvironmentObject var styleManager: StyleManager

    init(
        message: ChatMessage,
        isStreaming: Bool = false,
        performanceOverride: ChatMessage.PerformanceInfo? = nil,
        onRegenerate: (() -> Void)? = nil
    ) {
        self.message = message
        self.isStreaming = isStreaming
        self.performanceOverride = performanceOverride
        self.onRegenerate = onRegenerate
    }

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
                messageContent
                    .frame(maxWidth: .infinity * 0.8, alignment: .trailing)
            } else {
                messageContent
                    .frame(maxWidth: .infinity * 0.8, alignment: .leading)
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private var messageContent: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
            headerView
            bubbleRow
            metadataView
        }
    }

    private var headerView: some View {
        HStack {
            if message.role != .user {
                Image(systemName: "cpu")
                    .foregroundColor(styleManager.tokens.secondaryForeground)
                    .font(.caption)
            }

            Text(message.role == .user ? "You" : "Assistant")
                .font(.caption)
                .foregroundColor(styleManager.tokens.secondaryForeground)

            if message.role == .user {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(styleManager.tokens.accent)
                    .font(.caption)
            }
        }
    }

    private var bubbleRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(message.content)
                .textSelection(.enabled)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(message.role == .user ? styleManager.tokens.accent : styleManager.tokens.surface)
                )
                .foregroundColor(message.role == .user ? styleManager.tokens.onPrimary : styleManager.tokens.onSurface)

            if isStreaming {
                VStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.8)
                    if let liveTokens = liveTokensPerSecondText {
                        Text(liveTokens)
                            .font(.caption2)
                            .foregroundColor(styleManager.tokens.secondaryForeground)
                    }
                }
            }
        }
    }

    @ViewBuilder private var metadataView: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
            if message.role == .assistant, let summary = performanceSummary {
                HStack(spacing: 4) {
                    Image(systemName: isStreaming ? "bolt.horizontal.fill" : "speedometer")
                        .font(.caption2)
                        .foregroundColor(styleManager.tokens.secondaryForeground)
                    Text(summary)
                        .font(.caption2)
                        .foregroundColor(styleManager.tokens.secondaryForeground)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 6) {
                Text(timestampText)
                    .font(.caption2)
                    .foregroundColor(styleManager.tokens.secondaryForeground)

                if message.role != .user && !isStreaming {
                    Button {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.content, forType: .string)
                        #else
                        UIPasteboard.general.string = message.content
                        #endif
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(styleManager.tokens.secondaryForeground)

                    if let onRegenerate {
                        Button(action: onRegenerate) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(styleManager.tokens.secondaryForeground)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var effectivePerformance: ChatMessage.PerformanceInfo? {
        performanceOverride ?? message.performance
    }

    private var performanceSummary: String? {
        guard let performance = effectivePerformance else { return nil }
        var components: [String] = []

        if let identifier = performance.modelName ?? performance.modelId {
            components.append(shortModelName(from: identifier))
        }

        if let tokensPerSecond = performance.tokensPerSecond, tokensPerSecond > 0.05 {
            components.append(formatTokensPerSecond(tokensPerSecond))
        }

        if let tokenCount = performance.tokenCount, tokenCount > 0 {
            components.append("\(tokenCount) tok")
        }

        if let duration = performance.generationDuration, duration > 0.05 {
            components.append(String(format: "%.1fs", duration))
        }

        return components.isEmpty ? nil : components.joined(separator: " • ")
    }

    private var liveTokensPerSecondText: String? {
        guard isStreaming, let tokensPerSecond = effectivePerformance?.tokensPerSecond, tokensPerSecond > 0.05 else {
            return nil
        }
        return formatTokensPerSecond(tokensPerSecond)
    }

    private var timestampText: String {
        message.timestamp.formatted(date: .omitted, time: .shortened)
    }

    private func shortModelName(from identifier: String) -> String {
        if let last = identifier.split(separator: "/").last {
            return String(last)
        }
        return identifier
    }

    private func formatTokensPerSecond(_ value: Double) -> String {
        switch value {
        case ..<0.1:
            return "<0.1 tok/s"
        case ..<10:
            return String(format: "%.1f tok/s", value)
        default:
            return "\(Int(round(value))) tok/s"
        }
    }
}