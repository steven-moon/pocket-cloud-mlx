// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/Download/ModelFileCanonicalizer.swift
// Purpose       : Canonicalizes model file structure for compatibility
//
// Key Types in this file:
//   - actor ModelFileCanonicalizer
//
// Living Docs:
//   - Main README: pocket-cloud-mlx/Documentation/README.md
//
// == End LLM Context Header ==

import Foundation

/// Canonicalizes model file structure for loader compatibility
public actor ModelFileCanonicalizer: ModelFileCanonicalization {
    
    public init() {}
    
    // MARK: - ModelFileCanonicalization Protocol
    
    public func canonicalizeFiles(at directory: URL) async {
        flattenSingleFileDirectories(at: directory)
        
        // Check for specific canonical names that some loaders expect
        let fm = FileManager.default
        let configJsonPath = directory.appendingPathComponent("config.json").path
        
        // If config.json doesn't exist, try to find alternate config names
        if !fm.fileExists(atPath: configJsonPath) {
            let alternateConfigs = ["model_config.json", "generation_config.json", "mlx_config.json"]
            for alternate in alternateConfigs {
                let alternatePath = directory.appendingPathComponent(alternate)
                if fm.fileExists(atPath: alternatePath.path) {
                    // Copy (not move) to preserve original
                    try? fm.copyItem(at: alternatePath, to: URL(fileURLWithPath: configJsonPath))
                    break
                }
            }
        }
    }
    
    public func flattenSingleFileDirectories(at directory: URL) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        var directoriesToFlatten: [(parent: URL, child: URL)] = []
        
        for case let itemURL as URL in enumerator {
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: itemURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            
            // Check if directory contains exactly one item with same name
            guard let contents = try? fm.contentsOfDirectory(at: itemURL, includingPropertiesForKeys: nil),
                  contents.count == 1,
                  let singleItem = contents.first else { continue }
            
            if singleItem.lastPathComponent == itemURL.lastPathComponent {
                directoriesToFlatten.append((parent: itemURL, child: singleItem))
            }
        }
        
        // Perform flattening
        for (parent, child) in directoriesToFlatten {
            do {
                let tempURL = parent.deletingLastPathComponent()
                    .appendingPathComponent(UUID().uuidString)
                try fm.moveItem(at: child, to: tempURL)
                try fm.removeItem(at: parent)
                try fm.moveItem(at: tempURL, to: parent)
            } catch {
                // Silent failure - not critical
            }
        }
    }
}
