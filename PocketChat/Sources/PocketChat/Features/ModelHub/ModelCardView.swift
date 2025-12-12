// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/ModelHub/ModelCardView.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct ModelCardView: View {
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
import MLXEngine
#if canImport(MLXLLM)
import MLXLLM
#endif
import os.log

/// Native model card view that uses the app's StyleManager
struct ModelCardView: View {
    let model: HuggingFaceModel
    let isDownloading: Bool
    let downloadProgress: Double
    let isDownloaded: Bool
    let downloadError: ModelDiscoveryManager.DownloadErrorInfo?
    let onDownload: () -> Void
    var onCancel: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onUse: (() -> Void)? = nil
    
    @State private var showingDetails = false
    @EnvironmentObject var styleManager: StyleManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    // Access manager without observing to avoid excessive re-renders from 23 @Published properties
    private let manager = ModelDiscoveryManager.shared
    private static let log = Logger(subsystem: "com.mlxchatapp", category: "ModelCard")
    private static let popularTextFamilies = ["llama", "mistral", "phi", "qwen", "gemma", "codellama", "smol", "hermes"]
    
    /// Check if this model is supported by MLX
    private var isModelSupported: Bool {
        let normalizedId = ModelConfiguration.normalizeHubId(model.id)
        let registryModels = ModelRegistry.allModels

        if registryModels.contains(where: { $0.hubId.caseInsensitiveCompare(normalizedId) == .orderedSame }) {
            return true
        }

        if registryModels.contains(where: { $0.hubId.caseInsensitiveCompare(model.id) == .orderedSame }) {
            return true
        }

        if let shortId = normalizedId.split(separator: "/").last?.lowercased(),
           registryModels.contains(where: { $0.hubId.lowercased().contains(shortId) }) {
            return true
        }

        #if canImport(MLXLLM)
        let mlxRegistryIds = Set(MLXLLM.LLMRegistry.shared.models.map { String(describing: $0.id).lowercased() })
        let hfLower = normalizedId.lowercased()

        if mlxRegistryIds.contains(hfLower) {
            return true
        }

        if mlxRegistryIds.contains(where: { hfLower.contains($0) || $0.contains(hfLower) }) {
            return true
        }
        #endif

        return false
    }

    private var registryConfiguration: ModelConfiguration? {
        let normalizedId = ModelConfiguration.normalizeHubId(model.id)
        return ModelRegistry.findModel(by: normalizedId)
    }

    private var isChatCapable: Bool {
        guard let config = registryConfiguration else { return true }
        return config.supportsChat
    }
    
    var body: some View {
        let tokens = styleManager.tokens
        let useWideLayout = !isCompact
        // Choose between a two-column layout and stacked layout based on size class.
        let contentLayout: AnyLayout = useWideLayout
            ? AnyLayout(HStackLayout(alignment: .top, spacing: tokens.spacing.lg))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: tokens.spacing.md))

        VStack(alignment: .leading, spacing: tokens.spacing.md) {
            HStack(alignment: .top, spacing: 8) {
                if let arch = model.extractArchitecture() {
                    Text(arch.uppercased())
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(styleManager.tokens.accent.opacity(0.15))
                        .foregroundColor(styleManager.tokens.accent)
                        .clipShape(Capsule())
                }
                Spacer(minLength: 0)
                statusContent(useWideLayout: useWideLayout)
            }

            contentLayout {
                infoColumn
                    .layoutPriority(1)
                actionColumn(wideLayout: useWideLayout)
            }
        }
        .padding(tokens.spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: tokens.cornerRadius.lg)
                .fill(tokens.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: tokens.cornerRadius.lg)
                .stroke(tokens.borderColor.opacity(colorScheme == .dark ? 0.6 : 0.2), lineWidth: 1)
        )
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.08), radius: colorScheme == .dark ? 10 : 6, x: 0, y: colorScheme == .dark ? 6 : 3)
        .sheet(isPresented: $showingDetails) {
            HuggingFaceModelDetailView(model: model)
        }
    }

    @ViewBuilder
    private func statusContent(useWideLayout: Bool) -> some View {
        let tokens = styleManager.tokens
        if isDownloading {
            VStack(alignment: useWideLayout ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: tokens.accent))
                        .scaleEffect(useWideLayout ? 0.85 : 0.75)
                    ProgressView(value: downloadProgress)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: useWideLayout ? 160 : .infinity)
                }
                Text(progressLabel())
                    .font(.caption2)
                    .foregroundColor(tokens.secondaryForeground)
                    .frame(maxWidth: .infinity, alignment: useWideLayout ? .trailing : .leading)
            }
            .frame(maxWidth: useWideLayout ? 200 : .infinity, alignment: useWideLayout ? .trailing : .leading)
        } else if let error = downloadError {
            VStack(alignment: useWideLayout ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Download failed")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.orange)
                }
                Text(error.message)
                    .font(.caption2)
                    .foregroundColor(tokens.secondaryForeground)
                    .multilineTextAlignment(useWideLayout ? .trailing : .leading)
                    .lineLimit(3)
                    .frame(maxWidth: useWideLayout ? 220 : .infinity, alignment: useWideLayout ? .trailing : .leading)
            }
            .frame(maxWidth: useWideLayout ? 220 : .infinity, alignment: useWideLayout ? .trailing : .leading)
        } else if manager.verifyingModels.contains(model.id) {
            VStack(alignment: useWideLayout ? .trailing : .leading, spacing: 4) {
                if let total = manager.verifyTotalToRepair[model.id], total > 0 {
                    ProgressView(value: manager.verificationProgress[model.id] ?? 0)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: useWideLayout ? 160 : .infinity)
                    Text("Repairing: \(manager.verifyRepairedCount[model.id] ?? 0)/\(total)")
                        .font(.caption2)
                        .foregroundColor(tokens.secondaryForeground)
                        .frame(maxWidth: .infinity, alignment: useWideLayout ? .trailing : .leading)
                } else {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: tokens.accent))
                        Text("Verifying…")
                            .font(.caption2)
                            .foregroundColor(tokens.secondaryForeground)
                    }
                    .frame(maxWidth: .infinity, alignment: useWideLayout ? .trailing : .leading)
                }
            }
            .frame(maxWidth: useWideLayout ? 200 : .infinity, alignment: useWideLayout ? .trailing : .leading)
        }
    }

    private var infoColumn: some View {
        VStack(alignment: .leading, spacing: styleManager.tokens.spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.id.components(separatedBy: "/").last ?? model.id)
                    .font(.headline)
                    .foregroundColor(styleManager.tokens.onSurface)
                Text(model.pipeline_tag ?? "MLX-compatible model")
                    .font(.subheadline)
                    .foregroundColor(styleManager.tokens.secondaryForeground)
                    .lineLimit(2)
            }
            capabilityRow
            specRow(compact: isCompact)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func actionColumn(wideLayout: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            actionButtons(vertical: false)
            actionButtons(vertical: true)
        }
        .frame(maxWidth: wideLayout ? 320 : .infinity, alignment: .leading)
    }
    
    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private func spec(label: String, value: String, color: Color, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(styleManager.tokens.secondaryForeground)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(color)
        }
        .frame(maxWidth: compact ? .infinity : nil, alignment: .leading)
    }
    
    @ViewBuilder
    private func specRow(compact: Bool) -> some View {
        let items = specItems()

        if compact {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, entry in
                    spec(label: entry.label, value: entry.value, color: entry.color, compact: true)
                }
            }
        } else {
            HStack(spacing: 16) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, entry in
                    spec(label: entry.label, value: entry.value, color: entry.color, compact: false)
                }
                Spacer()
            }
        }
    }

    private func specItems() -> [(label: String, value: String, color: Color)] {
        var results: [(label: String, value: String, color: Color)] = []
        if let params = model.extractParameters() {
            results.append((label: "Parameters", value: params, color: styleManager.tokens.info))
        }
        if let quant = model.extractQuantization() {
            results.append((label: "Quantization", value: quant, color: styleManager.tokens.accent))
        }
        if let (label, size) = sizeDescription() {
            results.append((label: label, value: size, color: styleManager.tokens.secondary))
        }

        // Add download count if available
        if let downloads = model.downloads, downloads > 0 {
            let downloadStr: String
            if downloads >= 1_000_000 {
                downloadStr = String(format: "%.1fM", downloads / 1_000_000)
            } else if downloads >= 1_000 {
                downloadStr = String(format: "%.1fK", downloads / 1_000)
            } else {
                downloadStr = String(format: "%.0f", downloads)
            }
            results.append((label: "Downloads", value: downloadStr, color: styleManager.tokens.success))
        }

        // Add publish date if available
        if let dateStr = model.lastModified ?? model.createdAt {
            let formattedDate = formatDate(dateStr)
            results.append((label: "Published", value: formattedDate, color: styleManager.tokens.secondaryForeground))
        }

        return results
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let now = Date()
            let calendar = Calendar.current
            let components = calendar.dateComponents([.day, .month, .year], from: date, to: now)

            if let years = components.year, years > 0 {
                return years == 1 ? "1 year ago" : "\(years) years ago"
            } else if let months = components.month, months > 0 {
                return months == 1 ? "1 month ago" : "\(months) months ago"
            } else if let days = components.day, days > 0 {
                return days == 1 ? "1 day ago" : "\(days) days ago"
            } else {
                return "Today"
            }
        }

        // Fallback: just show the date in a simple format
        if dateString.count >= 10 {
            let yearMonthDay = String(dateString.prefix(10))
            return yearMonthDay
        }
        return dateString
    }

    private var capabilityRow: some View {
        let tokens = styleManager.tokens
        let capabilities = Self.capabilities(for: model)

        return Group {
            if !capabilities.isEmpty {
                HStack(spacing: tokens.spacing.xs) {
                    ForEach(capabilities) { capability in
                        HStack(spacing: 4) {
                            Image(systemName: capability.symbolName)
                                .font(.caption.weight(.semibold))
                            Text(capability.displayName)
                                .font(.caption2.weight(.semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(capability.tintColor(tokens).opacity(0.12))
                        .foregroundColor(capability.tintColor(tokens))
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func actionButtons(vertical: Bool) -> some View {
        if vertical {
            VStack(spacing: 8) {
                detailsButton(fillWidth: true)
                if isDownloading, let onCancel = onCancel {
                    cancelButton(fillWidth: true, onCancel: onCancel)
                } else if !isDownloaded {
                    downloadButton(fillWidth: true)
                }
                if isDownloaded, let onUse = onUse {
                    useButton(fillWidth: true, onUse: onUse)
                }
                if isDownloaded, let onDelete = onDelete {
                    deleteButton(fillWidth: true, onDelete: onDelete)
                }
            }
        } else {
            HStack(spacing: 12) {
                detailsButton(fillWidth: false)
                if isDownloading, let onCancel = onCancel {
                    cancelButton(fillWidth: false, onCancel: onCancel)
                } else if !isDownloaded {
                    downloadButton(fillWidth: false)
                }
                if isDownloaded, let onUse = onUse {
                    useButton(fillWidth: false, onUse: onUse)
                }
                if isDownloaded, let onDelete = onDelete {
                    deleteButton(fillWidth: false, onDelete: onDelete)
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func detailsButton(fillWidth: Bool) -> some View {
        Button {
            showingDetails = true
        } label: {
            Label("Details", systemImage: "info.circle")
                .font(.subheadline.weight(.medium))
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.bordered)
        .tint(styleManager.tokens.accent)
        .frame(maxWidth: fillWidth ? .infinity : nil)
    }

    @ViewBuilder
    private func cancelButton(fillWidth: Bool, onCancel: @escaping () -> Void) -> some View {
        Button(action: onCancel) {
            Label("Cancel", systemImage: "xmark.circle")
                .font(.subheadline.weight(.medium))
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.bordered)
        .tint(styleManager.tokens.warning)
        .frame(maxWidth: fillWidth ? .infinity : nil)
    }

    @ViewBuilder
    private func downloadButton(fillWidth: Bool) -> some View {
        if !isModelSupported {
            Button(action: {}) {
                Label("Not Supported", systemImage: "exclamationmark.triangle")
                    .font(.subheadline.weight(.medium))
                    .labelStyle(.titleAndIcon)
                    .foregroundColor(styleManager.tokens.onSurface.opacity(0.6))
            }
            .buttonStyle(.bordered)
            .tint(styleManager.tokens.warning.opacity(0.5))
            .disabled(true)
            .frame(maxWidth: fillWidth ? .infinity : nil)
        } else {
            Button(action: onDownload) {
                Label("Download", systemImage: "arrow.down.circle")
                    .font(.subheadline.weight(.medium))
                    .labelStyle(.titleAndIcon)
                    .foregroundColor(styleManager.tokens.onPrimary)
            }
            .buttonStyle(.borderedProminent)
            .tint(styleManager.tokens.accent)
            .disabled(isDownloading)
            .frame(maxWidth: fillWidth ? .infinity : nil)
        }
    }

    @ViewBuilder
    private func useButton(fillWidth: Bool, onUse: @escaping () -> Void) -> some View {
        if isChatCapable {
            Button(action: {
                Self.log.info("USE_TAP model=\(model.id, privacy: .public)")
                onUse()
                NotificationCenter.default.post(name: .switchToChat, object: nil)
            }) {
                Label("Use", systemImage: "checkmark.circle")
                    .font(.subheadline.weight(.medium))
                    .labelStyle(.titleAndIcon)
                    .foregroundColor(styleManager.tokens.onPrimary)
            }
            .buttonStyle(.borderedProminent)
            .tint(styleManager.tokens.success)
            .frame(maxWidth: fillWidth ? .infinity : nil)
        } else {
            Button(action: {}) {
                Label("Vision Only", systemImage: "eye")
                    .font(.subheadline.weight(.medium))
                    .labelStyle(.titleAndIcon)
                    .foregroundColor(styleManager.tokens.onSurface.opacity(0.6))
            }
            .buttonStyle(.bordered)
            .tint(styleManager.tokens.success.opacity(0.4))
            .disabled(true)
            .frame(maxWidth: fillWidth ? .infinity : nil)
        }
    }

    @ViewBuilder
    private func deleteButton(fillWidth: Bool, onDelete: @escaping () -> Void) -> some View {
        Button(action: onDelete) {
            Label("Delete Files", systemImage: "trash")
                .font(.subheadline.weight(.medium))
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.bordered)
        .tint(styleManager.tokens.error)
        .frame(maxWidth: fillWidth ? .infinity : nil)
    }

    private func sizeDescription() -> (String, String)? {
        if let total = manager.totalBytesByModel[model.id], total > 0 {
            return ("Size", ByteCountFormatter.string(fromByteCount: total, countStyle: .file))
        }
        // Heuristic fallback
        let params = model.extractParameters() ?? ""
        let quant = model.extractQuantization()?.lowercased() ?? ""
        let sizeGB: Double?
        if params.contains("8B") { sizeGB = quant.contains("4") ? 5.0 : 10.0 }
        else if params.contains("7B") { sizeGB = quant.contains("4") ? 4.3 : 8.6 }
        else if params.contains("3B") { sizeGB = quant.contains("4") ? 2.1 : 4.2 }
        else if params.contains("1B") { sizeGB = quant.contains("4") ? 0.8 : 1.6 }
        else { sizeGB = nil }
        if let s = sizeGB { return ("Estimated Size", String(format: "%.1f GB", s)) }
        return nil
    }

    private func progressLabel() -> String {
        let id = model.id
        let p = manager.downloadProgress[id] ?? downloadProgress
        if let total = manager.totalBytesByModel[id], total > 0, let downloaded = manager.downloadedBytesByModel[id] {
            return "\(ByteCountFormatter.string(fromByteCount: downloaded, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file)) (\(Int((p * 100).rounded()))%)"
        }
        return "\(Int((p * 100).rounded()))%"
    }
}

extension ModelCardView {
    private enum Capability: String, CaseIterable, Identifiable {
        case text
        case vision
        case audio
        case embed

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .text: return "Text"
            case .vision: return "Vision"
            case .audio: return "Audio"
            case .embed: return "Embed"
            }
        }

        var symbolName: String {
            switch self {
            case .text: return "text.alignleft"
            case .vision: return "eye"
            case .audio: return "waveform"
            case .embed: return "link"
            }
        }

        func tintColor(_ tokens: ThemeTokens) -> Color {
            switch self {
            case .text: return tokens.accent
            case .vision: return tokens.success
            case .audio: return tokens.warning
            case .embed: return tokens.info
            }
        }
    }

    private static func capabilities(for model: HuggingFaceModel) -> [Capability] {
        let pipeline = (model.pipeline_tag ?? "").lowercased()
        let tags = Set((model.tags ?? []).map { $0.lowercased() })
        let architecture = (model.extractArchitecture() ?? "").lowercased()

        func supportsText() -> Bool {
            if pipeline.contains("text") || pipeline.contains("generation") || pipeline.contains("chat") {
                return true
            }
            if popularTextFamilies.contains(where: { architecture.contains($0) }) {
                return true
            }
            return tags.contains { $0.contains("text-generation") || $0.contains("chat") || $0.contains("instruction") }
        }

        func supportsVision() -> Bool {
            if pipeline.contains("image") || pipeline.contains("vision") {
                return true
            }
            if architecture.contains("llava") || architecture.contains("vision") {
                return true
            }
            return tags.contains { $0.contains("vision") || $0.contains("multimodal") }
        }

        func supportsAudio() -> Bool {
            if pipeline.contains("audio") || pipeline.contains("speech") {
                return true
            }
            return tags.contains { $0.contains("audio") || $0.contains("speech") || $0.contains("tts") }
        }

        func supportsEmbedding() -> Bool {
            if pipeline.contains("embedding") {
                return true
            }
            if architecture.contains("bge") {
                return true
            }
            return tags.contains { $0.contains("embedding") }
        }

        var result: [Capability] = []
        if supportsText() { result.append(.text) }
        if supportsVision() { result.append(.vision) }
        if supportsAudio() { result.append(.audio) }
        if supportsEmbedding() { result.append(.embed) }

        return result
    }
}

// ModelDetailView and DetailItem have been moved to HuggingFaceModelDetailView.swift
// to avoid naming conflicts with SwiftUIKit's generic ModelDetailView

#Preview {
    let sampleModel = HuggingFaceModel(
        id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
        author: "mlx-community",
        downloads: 15000,
        likes: 500,
        tags: ["mlx", "llama", "instruct", "4bit"],
        siblings: [
            Sibling(rfilename: "model.safetensors", size: 2_100_000_000),
            Sibling(rfilename: "tokenizer.json", size: 500_000)
        ]
    )
    
    ModelCardView(
        model: sampleModel,
        isDownloading: true,
        downloadProgress: 0.42,
        isDownloaded: false,
        downloadError: nil,
        onDownload: {}
    )
    .padding()
    .environmentObject(StyleManager())
} 
