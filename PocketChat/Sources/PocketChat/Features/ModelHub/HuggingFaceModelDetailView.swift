// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/ModelHub/HuggingFaceModelDetailView.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct HuggingFaceModelDetailView: View {
//   - struct HuggingFaceDetailItem: View {
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
import Foundation
import MLXEngine

/// Sophisticated model detail view for HuggingFace models
/// This is the sophisticated implementation that was previously embedded in ModelCardView.swift
/// Extracted to avoid naming conflicts with SwiftUIKit's generic ModelDetailView
struct HuggingFaceModelDetailView: View {
    let model: HuggingFaceModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var styleManager: StyleManager
    private let manager = ModelDiscoveryManager.shared
    @State private var localFiles: [ModelDiscoveryManager.LocalModelFile] = []
    private let onDeviceFileLimit = 24
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private var tokens: ThemeTokens { styleManager.tokens }

    var body: some View {
        #if os(macOS)
        NavigationStack { mainContent }
        #else
        NavigationView { mainContent }
        #endif
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: tokens.spacing.lg) {
                heroSection

                if !metricItems.isEmpty {
                    detailSection(title: "Key Metrics", systemImage: "chart.bar.doc.horizontal") {
                        LazyVGrid(columns: metricColumns, spacing: tokens.spacing.sm) {
                            ForEach(metricItems) { metric in
                                MetricTile(metric: metric)
                            }
                        }
                    }
                }

                if !compatibilityItems.isEmpty {
                    detailSection(title: "Access & Compatibility", systemImage: "lock.open.display") {
                        VStack(alignment: .leading, spacing: tokens.spacing.sm) {
                            ForEach(Array(compatibilityItems.enumerated()), id: \.offset) { index, item in
                                HStack(alignment: .firstTextBaseline, spacing: tokens.spacing.sm) {
                                    Image(systemName: item.icon)
                                        .foregroundColor(item.tint)
                                        .font(.subheadline.weight(.semibold))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(tokens.onBackground)
                                        if let detail = item.detail {
                                            Text(detail)
                                                .font(.footnote)
                                                .foregroundColor(tokens.secondaryForeground)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                                if index < compatibilityItems.count - 1 {
                                    Divider().opacity(0.3)
                                }
                            }
                        }
                    }
                }

                if let onDeviceSection = onDeviceFilesSection {
                    onDeviceSection
                }

                if let tagsSection = tagsSection {
                    tagsSection
                }

                if let filesSection = filesSection {
                    filesSection
                }

                if let cardSection = modelCardSection {
                    cardSection
                }
            }
            .frame(maxWidth: contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, tokens.spacing.lg)
            .padding(.vertical, tokens.spacing.md)
        }
        .background(tokens.background.ignoresSafeArea())
        .task(id: manager.containsDownloadedModel(id: model.id)) {
            await refreshLocalFiles()
        }
        .navigationTitle("Model Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        #elseif os(macOS)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Done") { dismiss() }
            }
        }
        #endif
    }

    private var heroSection: some View {
        detailCard {
            VStack(alignment: .leading, spacing: tokens.spacing.sm) {
                VStack(alignment: .leading, spacing: tokens.spacing.xs) {
                    Text(displayName)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(tokens.onBackground)
                    Text(model.id)
                        .font(.footnote)
                        .foregroundColor(tokens.secondaryForeground)
                }

                if let heroSubtitle = heroSubtitle {
                    Text(heroSubtitle)
                        .font(.callout)
                        .foregroundColor(tokens.onBackground)
                }

                if !heroBadges.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: tokens.spacing.xs) {
                            ForEach(heroBadges, id: \.title) { badge in
                                BadgeView(badge: badge)
                            }
                        }
                    }
                }

                downloadControls

                HStack(spacing: tokens.spacing.sm) {
                    if let author = model.author {
                        Label(author, systemImage: "person.fill")
                            .font(.footnote)
                            .foregroundColor(tokens.secondaryForeground)
                    }
                    if let url = huggingFaceURL {
                        Spacer(minLength: tokens.spacing.sm)
                        Link(destination: url) {
                            Label("View on Hugging Face", systemImage: "arrow.up.forward.app")
                                .font(.footnote.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(tokens.accent)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var downloadControls: some View {
        if manager.downloadingModels.contains(model.id) {
            VStack(alignment: .leading, spacing: tokens.spacing.sm) {
                HStack(spacing: tokens.spacing.sm) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: tokens.accent))
                        .scaleEffect(0.9)
                    ProgressView(value: manager.downloadProgress[model.id] ?? 0)
                        .progressViewStyle(.linear)
                }
                Text(progressLabel())
                    .font(.caption)
                    .foregroundColor(tokens.secondaryForeground)
                Button(role: .cancel) {
                    Task { await manager.cancelDownload(modelId: model.id) }
                } label: {
                    Label("Cancel Download", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
            }
        } else if manager.containsDownloadedModel(id: model.id) {
            HStack(spacing: tokens.spacing.sm) {
                Label("Files on device", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Spacer()
                Button(role: .destructive) {
                    Task { await manager.deleteDownloadedFiles(modelId: model.id) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        } else {
            Button {
                Task { await manager.startDownload(for: model) }
            } label: {
                Label("Download Model", systemImage: "arrow.down.circle")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(tokens.accent)
            .task { await manager.prefetchTotalBytes(for: model.id) }
        }
    }

    private var metricColumns: [GridItem] {
        #if os(macOS)
        return [GridItem(.adaptive(minimum: 200), spacing: tokens.spacing.sm)]
        #else
        let minWidth: CGFloat
        if horizontalSizeClass == .regular {
            minWidth = 200
        } else {
            minWidth = 160
        }
        return [GridItem(.adaptive(minimum: minWidth), spacing: tokens.spacing.sm)]
        #endif
    }

    private var metricItems: [MetricItem] {
        var items: [MetricItem] = []

        if let params = model.extractParameters() {
            items.append(MetricItem(title: "Parameters", value: params, icon: "number"))
        }
        if let quant = model.extractQuantization() {
            items.append(MetricItem(title: "Quantization", value: quant.uppercased(), icon: "speedometer"))
        }
        if let architecture = model.extractArchitecture() {
            items.append(MetricItem(title: "Architecture", value: architecture, icon: "cube"))
        }
        if let size = resolvedSize() {
            items.append(MetricItem(title: size.title, value: size.value, icon: "internaldrive"))
        }
        if let downloads = formatCount(model.downloads) {
            items.append(MetricItem(title: "Downloads", value: downloads, icon: "arrow.down"))
        }
        if let likes = formatCount(model.likes) {
            items.append(MetricItem(title: "Likes", value: likes, icon: "hand.thumbsup"))
        }
        if let updated = formatDate(model.lastModified) {
            items.append(MetricItem(title: "Last Updated", value: updated, icon: "clock"))
        }
        if let created = formatDate(model.createdAt) {
            items.append(MetricItem(title: "Published", value: created, icon: "calendar"))
        }
        if let library = model.library_name, !library.isEmpty {
            items.append(MetricItem(title: "Library", value: library.capitalized, icon: "shippingbox"))
        }

        return items
    }

    private var heroBadges: [Badge] {
        var badges: [Badge] = []

        if let pipeline = pipelineDisplayName {
            badges.append(Badge(title: pipeline, icon: "sparkles", tint: tokens.accent))
        }
        if model.hasMLXFiles() {
            badges.append(Badge(title: "MLX Files", icon: "checkmark.seal.fill", tint: .green))
        }
        if model.gated == true {
            badges.append(Badge(title: "Gated", icon: "lock.fill", tint: .orange))
        }
        if model.private_ == true {
            badges.append(Badge(title: "Private", icon: "person.crop.circle.badge.exclamationmark", tint: .orange))
        }
        if model.disabled == true {
            badges.append(Badge(title: "Disabled", icon: "exclamationmark.triangle.fill", tint: .red))
        }

        return badges
    }

    private var compatibilityItems: [CompatibilityItem] {
        var items: [CompatibilityItem] = []

        if model.hasMLXFiles() {
            items.append(CompatibilityItem(title: "MLX assets detected", detail: "Ready to run locally", icon: "checkmark.seal", tint: .green))
        } else {
            items.append(CompatibilityItem(title: "No MLX conversion found", detail: "Verify format before download", icon: "questionmark.diamond", tint: .orange))
        }

        if let size = resolvedSize() {
            items.append(CompatibilityItem(title: "Estimated disk footprint", detail: size.value, icon: "internaldrive", tint: tokens.secondary))
        }

        if model.gated == true {
            items.append(CompatibilityItem(title: "Requires Hugging Face access", detail: "Request access before downloading", icon: "lock.shield", tint: .orange))
        }

        if manager.containsDownloadedModel(id: model.id) {
            items.append(CompatibilityItem(title: "Downloaded", detail: "Files available on this device", icon: "checkmark.circle.fill", tint: .green))
        }

        return items
    }

    private var onDeviceFilesSection: AnyView? {
        guard manager.containsDownloadedModel(id: model.id), !localFiles.isEmpty else { return nil }

        return AnyView(
            detailSection(title: "On-Device Files", systemImage: "externaldrive") {
                VStack(alignment: .leading, spacing: tokens.spacing.sm) {
                    ForEach(Array(localFiles.enumerated()), id: \.element.id) { index, file in
                        HStack(alignment: .firstTextBaseline) {
                            Text(file.displayName)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(tokens.onBackground)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            if let sizeText = formatByteCount(file.size) {
                                Text(sizeText)
                                    .font(.footnote)
                                    .foregroundColor(tokens.secondaryForeground)
                            }
                        }
                        if index < localFiles.count - 1 {
                            Divider().opacity(0.25)
                        }
                    }

                    if localFiles.count >= onDeviceFileLimit {
                        Text("Showing first \(onDeviceFileLimit) files")
                            .font(.footnote)
                            .foregroundColor(tokens.secondaryForeground)
                    }
                }
            }
        )
    }

    private var tagsSection: AnyView? {
        guard let tags = model.tags?.filter({ !$0.isEmpty }), !tags.isEmpty else { return nil }
        let trimmed = Array(tags.prefix(24))

        return AnyView(
            detailSection(title: "Tags", systemImage: "tag") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: tokens.spacing.sm)], spacing: tokens.spacing.sm) {
                    ForEach(trimmed, id: \.self) { tag in
                        Text(tag)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, tokens.spacing.sm)
                            .padding(.vertical, tokens.spacing.xs)
                            .background(tokens.accent.opacity(0.15))
                            .foregroundColor(tokens.accent)
                            .clipShape(Capsule())
                    }
                }
            }
        )
    }

    private var filesSection: AnyView? {
        guard let siblings = model.siblings, !siblings.isEmpty else { return nil }
        let preferred = siblings.sorted { ($0.size ?? 0) > ($1.size ?? 0) }.prefix(12)

        return AnyView(
            detailSection(title: "Available Files", systemImage: "doc.on.doc") {
                VStack(alignment: .leading, spacing: tokens.spacing.sm) {
                    ForEach(Array(preferred.enumerated()), id: \.element.rfilename) { index, file in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.rfilename)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(tokens.onBackground)
                                if let badge = securityBadge(for: file) {
                                    Text(badge)
                                        .font(.caption)
                                        .foregroundColor(tokens.secondaryForeground)
                                }
                            }
                            Spacer()
                            if let size = file.expectedSizeInBytes {
                                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .binary))
                                    .font(.footnote)
                                    .foregroundColor(tokens.secondaryForeground)
                            }
                        }
                        if index < preferred.count - 1 {
                            Divider().opacity(0.3)
                        }
                    }
                }
            }
        )
    }

    private var modelCardSection: AnyView? {
        let highlights = cardHighlights
        guard !highlights.isEmpty else { return nil }

        return AnyView(
            detailSection(title: "Model Card Highlights", systemImage: "doc.text") {
                VStack(alignment: .leading, spacing: tokens.spacing.sm) {
                    ForEach(Array(highlights.enumerated()), id: \.offset) { index, item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(tokens.secondaryForeground)
                            Text(item.value)
                                .font(.subheadline)
                                .foregroundColor(tokens.onBackground)
                        }
                        if index < highlights.count - 1 {
                            Divider().opacity(0.25)
                        }
                    }
                }
            }
        )
    }

    private var cardHighlights: [(title: String, value: String)] {
        var highlights: [(String, String)] = []

        if let license = cardValue(for: ["license", "licenseName", "license_name"]) {
            highlights.append(("License", license))
        }
        if let datasets = cardValue(for: ["datasets", "dataset"], allowLists: true) {
            highlights.append(("Datasets", datasets))
        }
        if let languages = cardValue(for: ["language", "languages"], allowLists: true) {
            highlights.append(("Languages", languages))
        }
        if let useCases = cardValue(for: ["tasks","task"], allowLists: true) {
            highlights.append(("Use Cases", useCases))
        }
        if let modality = pipelineDisplayName {
            highlights.append(("Pipeline", modality))
        }
        if let contextLength = configValue(for: ["max_position_embeddings", "max_sequence_length"]) {
            highlights.append(("Context Window", contextLength))
        }
        if let tokenizer = configValue(for: ["tokenizer_class"]) {
            highlights.append(("Tokenizer", tokenizer))
        }
        if let reference = cardValue(for: ["paper", "paper_title"]) {
            highlights.append(("Reference", reference))
        }

        return highlights
    }

    private func detailSection<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        detailCard {
            VStack(alignment: .leading, spacing: tokens.spacing.sm) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .foregroundColor(tokens.onBackground)
                content()
            }
        }
    }

    private func detailCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: tokens.spacing.sm) {
            content()
        }
        .padding(tokens.spacing.md)
        .background(
            RoundedRectangle(cornerRadius: tokens.cornerRadius.lg)
                .fill(tokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: tokens.cornerRadius.lg)
                        .stroke(tokens.borderColor.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func progressLabel() -> String {
        let progress = manager.downloadProgress[model.id] ?? 0
        if let total = manager.totalBytesByModel[model.id], total > 0,
           let downloaded = manager.downloadedBytesByModel[model.id] {
            let completed = ByteCountFormatter.string(fromByteCount: downloaded, countStyle: .file)
            let totalText = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
            return "\(completed) / \(totalText) (\(Int((progress * 100).rounded()))%)"
        }
        return "\(Int((progress * 100).rounded()))%"
    }

    private func resolvedSize() -> (title: String, value: String)? {
        if let total = manager.totalBytesByModel[model.id] {
            return ("Size", ByteCountFormatter.string(fromByteCount: total, countStyle: .file))
        }

        let params = model.extractParameters() ?? ""
        let quant = model.extractQuantization()?.lowercased() ?? ""
        var sizeGB: Double?

        if params.contains("8B") { sizeGB = quant.contains("4") ? 5.0 : 10.0 }
        else if params.contains("7B") { sizeGB = quant.contains("4") ? 4.3 : 8.6 }
        else if params.contains("4B") { sizeGB = quant.contains("4") ? 2.6 : 5.2 }
        else if params.contains("3B") { sizeGB = quant.contains("4") ? 2.1 : 4.2 }
        else if params.contains("1B") { sizeGB = quant.contains("4") ? 0.8 : 1.6 }

        if let sizeGB {
            return ("Estimated Size", String(format: "%.1f GB", sizeGB))
        }
        return nil
    }

    private func formatCount(_ value: Double?) -> String? {
        guard let value else { return nil }
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        }
        if value > 0 {
            if value.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", value)
            }
            return String(format: "%.1f", value)
        }
        return nil
    }

    private func formatDate(_ dateString: String?) -> String? {
        guard let dateString else { return nil }
        let parsed = Self.iso8601WithFractional.date(from: dateString) ?? Self.iso8601.date(from: dateString)
        if let date = parsed {
            return Self.displayDateFormatter.string(from: date)
        }
        return dateString
    }

    private func formatByteCount(_ size: Int64?) -> String? {
        guard let size else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .binary)
    }

    private func refreshLocalFiles() async {
        let isDownloaded = await MainActor.run { manager.containsDownloadedModel(id: model.id) }
        if isDownloaded {
            let files = await manager.listLocalFiles(for: model.id, limit: onDeviceFileLimit)
            await MainActor.run { localFiles = files }
        } else {
            await MainActor.run { localFiles = [] }
        }
    }

    private var displayName: String {
        model.id.split(separator: "/").last.map(String.init) ?? model.id
    }

    private var heroSubtitle: String? {
        if let summary = cardValue(for: ["summary", "short_description", "description"]) {
            return summary
        }
        if let pipeline = pipelineDisplayName {
            return pipeline
        }
        return nil
    }

    private var pipelineDisplayName: String? {
        guard let tag = model.pipeline_tag else { return nil }
        switch tag {
        case "text-generation": return "Text Generation"
        case "text2text-generation": return "Instruction Following"
        case "feature-extraction": return "Embeddings"
        case "image-to-text": return "Vision"
        case "text-to-image": return "Diffusion"
        case "automatic-speech-recognition": return "Speech to Text"
        case "text-classification": return "Classification"
        default: return tag.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }

    private var huggingFaceURL: URL? {
        URL(string: "https://huggingface.co/\(model.id)")
    }

    private func cardValue(for keys: [String], allowLists: Bool = false) -> String? {
        guard let card = model.cardData else { return nil }

        for key in keys {
            if let value = card[key]?.value {
                if let stringValue = formattedString(from: value, allowLists: allowLists) {
                    return stringValue
                }
            }
        }
        return nil
    }

    private func configValue(for keys: [String]) -> String? {
        guard let config = model.config else { return nil }
        for key in keys {
            if let value = config[key]?.value, let string = formattedString(from: value, allowLists: true) {
                return string
            }
        }
        return nil
    }

    private func formattedString(from value: Any, allowLists: Bool) -> String? {
        if let string = value as? String {
            return string
        }
        if let bool = value as? Bool {
            return bool ? "Yes" : "No"
        }
        if let number = value as? NSNumber {
            let doubleValue = number.doubleValue
            if doubleValue.truncatingRemainder(dividingBy: 1) == 0 {
                return number.stringValue
            }
            return String(format: "%.2f", doubleValue)
        }
        if allowLists, let array = value as? [Any] {
            let parts = array.compactMap { formattedString(from: $0, allowLists: false) }
            if !parts.isEmpty { return parts.joined(separator: ", ") }
        }
        return nil
    }

    private func securityBadge(for file: Sibling) -> String? {
        if let status = file.securityStatus, !status.isEmpty { return status }
        if let sha = file.preferredSHA256, !sha.isEmpty { return "SHA256: \(sha.prefix(8))…" }
        return nil
    }
}

private extension HuggingFaceModelDetailView {
    var contentMaxWidth: CGFloat {
        #if os(macOS)
        return 780
        #else
        if horizontalSizeClass == .regular {
            return 720
        }
        return 560
        #endif
    }
}

private struct MetricItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
}

private struct CompatibilityItem {
    let title: String
    let detail: String?
    let icon: String
    let tint: Color
}

private struct Badge {
    let title: String
    let icon: String
    let tint: Color
}

private struct MetricTile: View {
    let metric: MetricItem
    @EnvironmentObject private var styleManager: StyleManager

    var body: some View {
        let tokens = styleManager.tokens
        VStack(alignment: .leading, spacing: tokens.spacing.xs) {
            Label(metric.title, systemImage: metric.icon)
                .font(.caption)
                .foregroundColor(tokens.secondaryForeground)
            Text(metric.value)
                .font(.headline)
                .foregroundColor(tokens.onBackground)
        }
        .padding(.vertical, tokens.spacing.sm)
        .padding(.horizontal, tokens.spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: tokens.cornerRadius.md)
                .fill(tokens.surface.opacity(0.6))
        )
    }
}

private struct BadgeView: View {
    let badge: Badge
    @EnvironmentObject private var styleManager: StyleManager

    var body: some View {
        let tokens = styleManager.tokens
        HStack(spacing: tokens.spacing.xs) {
            Image(systemName: badge.icon)
            Text(badge.title)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, tokens.spacing.sm)
        .padding(.vertical, tokens.spacing.xs)
        .background(badge.tint.opacity(0.15))
        .foregroundColor(badge.tint)
        .clipShape(Capsule())
    }
}

private extension HuggingFaceModelDetailView {
    static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = .autoupdatingCurrent
        return formatter
    }()
}

#Preview {
    let sampleModel = HuggingFaceModel(
        id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
        author: "mlx-community",
        downloads: 15000,
        likes: 500,
        tags: ["mlx", "llama", "instruct", "4bit"],
        pipeline_tag: "text-generation",
        cardData: [
            "license": AnyCodable("Apache 2.0"),
            "datasets": AnyCodable(["tatsu-lab/alpaca"]),
            "summary": AnyCodable("Instruction tuned Llama-3.2 3B quantized to 4-bit for MLX.")
        ],
        siblings: [
            Sibling(rfilename: "model.safetensors", size: 2_100_000_000),
            Sibling(rfilename: "tokenizer.json", size: 500_000)
        ]
    )

    HuggingFaceModelDetailView(model: sampleModel)
        .environmentObject(StyleManager())
}