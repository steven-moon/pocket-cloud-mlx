import SwiftUI
import MLXEngine
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Status bar that surfaces download and verification state for the Model Hub.
struct ModelHubDownloadBar: View {
    @ObservedObject var downloadState: ModelDownloadStateObserver
    @EnvironmentObject var styleManager: StyleManager
    
    let hasValidToken: Bool

    @State private var showingTokenSheet = false
    @State private var showDetails = false
    @State private var linesSelection: Int = 10 // 0 = All
    @State private var lastProgressUpdate: Date? = nil
    @State private var now: Date = Date()
    @State private var shimmerPhase: CGFloat = -1.0

    private let downloadManager = ModelDiscoveryManager.shared

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                statusContent()

                if !hasValidToken {
                    Button("Set Hugging Face Token") { showingTokenSheet = true }
                        .buttonStyle(.borderedProminent)
                        .tint(styleManager.tokens.accent)
                        .foregroundColor(styleManager.tokens.onPrimary)
                }
            }
            .padding(12)
            .background(styleManager.tokens.surface.opacity(0.9))
            .cornerRadius(12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showingTokenSheet) {
            HuggingFaceTokenView()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            now = Date()
        }
    }

    @ViewBuilder
    private func statusContent() -> some View {
        if let activeId = downloadState.downloadingModels.first {
            downloadingContent(activeId: activeId)
        } else if let activeVerifyId = downloadState.verifyingModels.first {
            verifyingContent(activeVerifyId: activeVerifyId)
        } else if !downloadState.downloadedModelIds.isEmpty {
            Text("Downloaded: \(downloadState.downloadedModelIds.count) model(s)")
                .foregroundColor(styleManager.tokens.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("No active downloads")
                .foregroundColor(styleManager.tokens.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func downloadingContent(activeId: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Downloading \(lastPath(activeId))")
                .font(.headline)
                .foregroundColor(styleManager.tokens.onBackground)

            Text(downloadLabel(for: activeId))
                .font(.caption)
                .foregroundColor(styleManager.tokens.secondaryForeground)

            if let fileLine = formattedFileStatus(for: activeId) {
                Text(fileLine)
                    .font(.caption2)
                    .foregroundColor(styleManager.tokens.secondaryForeground)
                    .lineLimit(2)
            }

            if let last = lastProgressUpdate {
                Text("Updated \(formattedSince(last, now: now)) ago")
                    .font(.caption2)
                    .foregroundColor(styleManager.tokens.secondaryForeground)
            }

            progressView(for: activeId)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: downloadState.downloadProgress[activeId] ?? 0) { _, _ in
            lastProgressUpdate = Date()
        }
        .onChange(of: downloadState.activeDownloadFiles[activeId]?.downloadedBytes ?? 0) { _, _ in
            lastProgressUpdate = Date()
        }
        .contextMenu {
            Button("Cancel Download", role: .destructive) {
                Task { await downloadManager.cancelDownload(modelId: activeId) }
            }
        }
    }

    private func verifyingContent(activeVerifyId: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Verifying \(lastPath(activeVerifyId))")
                .font(.headline)
                .foregroundColor(styleManager.tokens.onBackground)

            if let msgs = downloadState.verificationMessages[activeVerifyId], let last = msgs.last {
                Text(last)
                    .font(.caption)
                    .foregroundColor(styleManager.tokens.secondaryForeground)
                    .lineLimit(2)
            } else {
                Text("Checking files and repairing if needed…")
                    .font(.caption)
                    .foregroundColor(styleManager.tokens.secondaryForeground)
            }

            verificationSummary(for: activeVerifyId)

            if showDetails, let msgs = downloadState.verificationMessages[activeVerifyId] {
                verificationDetails(messages: msgs, id: activeVerifyId)
            }

            if let totalToRepair = downloadState.verifyTotalToRepair[activeVerifyId], totalToRepair > 0 {
                ProgressView(value: downloadState.verificationProgress[activeVerifyId] ?? 0)
                    .progressViewStyle(LinearProgressViewStyle(tint: styleManager.tokens.accent))
                    .frame(maxWidth: 280)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: styleManager.tokens.accent))
                    .frame(width: 18, height: 18)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func verificationSummary(for id: String) -> some View {
        HStack(spacing: 12) {
            if let missing = downloadState.verifyMissingCount[id] { chip("Missing: \(missing)") }
            if let corrupt = downloadState.verifyCorruptCount[id] { chip("Corrupt: \(corrupt)") }
            if let repaired = downloadState.verifyRepairedCount[id], let total = downloadState.verifyTotalToRepair[id], total > 0 {
                chip("Repaired: \(repaired)/\(total)")
            }
            if let scanned = downloadState.verifyScanIndex[id], let total = downloadState.verifyScanTotal[id] {
                chip("Scanned: \(scanned)/\(total)")
            }
            if let srcBytes = downloadState.verifySrcBytes[id], let tgtBytes = downloadState.verifyTgtBytes[id] {
                chip("Size src: \(ByteCountFormatter.string(fromByteCount: srcBytes, countStyle: .file))")
                chip("Size tgt: \(ByteCountFormatter.string(fromByteCount: tgtBytes, countStyle: .file))")
            }
            Button(action: { withAnimation { showDetails.toggle() } }) {
                Label(showDetails ? "Hide Details" : "Details", systemImage: showDetails ? "chevron.up" : "chevron.down")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding(8)
        .background(styleManager.tokens.surface.opacity(0.5))
        .cornerRadius(8)
    }

    private func verificationDetails(messages: [String], id: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Text("Lines:")
                        .font(.caption)
                        .foregroundColor(styleManager.tokens.secondaryForeground)
                    Picker("Lines", selection: $linesSelection) {
                        Text("10").tag(10)
                        Text("25").tag(25)
                        Text("50").tag(50)
                        Text("100").tag(100)
                        Text("All").tag(0)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)
                }
                Button {
                    copyLog(messages: messages)
                } label: {
                    Label("Copy Log", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                #if os(macOS)
                Menu {
                    if let src = downloadState.verifySourcePath[id] {
                        Button("Show Source in Finder") { openInFinder(path: src) }
                    }
                    if let tgt = downloadState.verifyTargetPath[id] {
                        Button("Show Target in Finder") { openInFinder(path: tgt) }
                    }
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                        .font(.caption)
                }
                .menuStyle(.borderedButton)
                #endif
                Spacer()
            }

            let sliceCount = linesSelection == 0 ? messages.count : min(linesSelection, messages.count)
            let lines = Array(messages.suffix(sliceCount))
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.caption2)
                    .foregroundColor(styleManager.tokens.secondaryForeground)
                    .textSelection(.enabled)
            }
        }
        .padding(8)
        .background(styleManager.tokens.surface.opacity(0.6))
        .cornerRadius(8)
    }

    private func progressView(for activeId: String) -> some View {
        let progressValue = downloadState.downloadProgress[activeId] ?? 0
        return HStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: styleManager.tokens.accent))
                .frame(width: 18, height: 18)

            ZStack(alignment: .leading) {
                ProgressView(value: progressValue)
                    .progressViewStyle(LinearProgressViewStyle(tint: styleManager.tokens.accent))
                    .frame(maxWidth: 280)

                GeometryReader { geo in
                    let width = max(0, min(1, progressValue)) * min(280, geo.size.width)
                    let gradient = LinearGradient(
                        gradient: Gradient(colors: [
                            styleManager.tokens.onPrimary.opacity(0.0),
                            styleManager.tokens.onPrimary.opacity(0.25),
                            styleManager.tokens.onPrimary.opacity(0.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    Rectangle()
                        .fill(gradient)
                        .frame(width: min(width, geo.size.width), height: 4)
                        .offset(x: min(width, geo.size.width) * shimmerPhase)
                        .opacity(progressValue > 0 && progressValue < 1 ? 1 : 0)
                }
                .allowsHitTesting(false)
                .frame(maxWidth: 280, maxHeight: 4)
            }
            .frame(maxWidth: 280)
        }
        .onAppear(perform: restartShimmer)
        .onChange(of: downloadState.downloadingModels.first) { _, _ in
            restartShimmer()
        }
    }

    private func downloadLabel(for id: String) -> String {
        let progress = downloadState.downloadProgress[id] ?? 0
        if let total = downloadState.totalBytesByModel[id], let done = downloadState.downloadedBytesByModel[id] {
            let downloadedString = ByteCountFormatter.string(fromByteCount: done, countStyle: .file)
            let totalString = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
            return "\(downloadedString) / \(totalString) (\(Int(progress * 100))%)"
        }
        return "\(Int(progress * 100))%"
    }

    private func restartShimmer() {
        shimmerPhase = -1.0
        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
            shimmerPhase = 1.0
        }
    }

    private func formattedFileStatus(for modelId: String) -> String? {
        guard let status = downloadState.activeDownloadFiles[modelId] else { return nil }
        var parts: [String] = []
        let totalFiles = status.total
        if totalFiles > 0 {
            parts.append("File \(status.index)/\(totalFiles)")
        } else {
            parts.append("File \(status.index)")
        }
        parts.append(status.name)
        if let downloaded = status.downloadedBytes, let total = status.totalBytes, total > 0 {
            let downloadedString = ByteCountFormatter.string(fromByteCount: downloaded, countStyle: .file)
            let totalString = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
            parts.append("\(downloadedString) / \(totalString)")
        } else if let total = status.totalBytes, total > 0 {
            let totalString = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
            parts.append(totalString)
        }
        if let progress = status.progress {
            parts.append("\(Int(progress * 100))%")
        }
        return parts.joined(separator: " • ")
    }

    private func lastPath(_ id: String) -> String {
        id.components(separatedBy: "/").last ?? id
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(styleManager.tokens.surface.opacity(0.6))
            .foregroundColor(styleManager.tokens.secondaryForeground)
            .clipShape(Capsule())
    }

    private func copyLog(messages: [String]) {
        let count = linesSelection == 0 ? messages.count : min(linesSelection, messages.count)
        let text = messages.suffix(count).joined(separator: "\n")
        #if os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }

    #if os(macOS)
    private func openInFinder(path: String) {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            let parent = url.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: parent.path) {
                NSWorkspace.shared.open(parent)
            }
        }
    }
    #endif

    private func formattedSince(_ date: Date, now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 1 { return "just now" }
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        return "\(hours)h"
    }
}
