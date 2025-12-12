// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Diagnostics/DiagnosticsOverlayView.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct DiagnosticsOverlayView: View {
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
import AIDevLogger

struct DiagnosticsOverlayView: View {
    @State private var filePreviews: [(URL, String)] = []
    @State private var recent: [LogEntry] = []
    @State private var breadcrumbs: [String] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Breadcrumbs") {
                    Text(breadcrumbs.isEmpty ? "<none>" : breadcrumbs.joined(separator: " > "))
                        .font(.footnote)
                }
                Section("Recent Logs (in-memory)") {
                    ForEach(Array(recent.enumerated()), id: \.offset) { _, entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("[\(entry.level.rawValue)] [\(entry.component)] \(entry.message)")
                                .font(.caption)
                            Text("\(entry.file.components(separatedBy: "/").last ?? entry.file):\(entry.line) \(entry.function)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Log Files (tail)") {
                    ForEach(filePreviews, id: \.0) { (url, tail) in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(url.lastPathComponent).font(.caption).bold()
                            ScrollView(.horizontal) { Text(tail).font(.caption2).textSelection(.enabled) }
                        }
                    }
                }
            }
            .navigationTitle("Diagnostics")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Refresh", action: refresh) }
                #elseif os(macOS)
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Refresh", action: refresh) }
                #else
                ToolbarItem(placement: .automatic) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .automatic) { Button("Refresh", action: refresh) }
                #endif
            }
            .onAppear(perform: refresh)
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    private func refresh() {
        breadcrumbs = Logger.currentBreadcrumbs()
        recent = Logger.recentLogs(limit: 120)

        // Tail a handful of log files including component logs
        let files = Logger.getAllLogFiles().prefix(8)
        filePreviews = files.compactMap { url in
            guard let s = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let lines = s.split(separator: "\n", omittingEmptySubsequences: false)
            let tail = lines.suffix(10).joined(separator: "\n")
            return (url, tail)
        }
    }
}
