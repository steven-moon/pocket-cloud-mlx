// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/HuggingFace_Errors.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - enum HuggingFaceError_Type: Error, LocalizedError, Equatable {
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

/// Errors that can occur when interacting with Hugging Face Hub
public enum HuggingFaceError_Type: Error, LocalizedError, Equatable {
    case invalidURL
    case networkError
    case decodingError
    case fileError
    case unauthorized(String)
    case forbidden(String)
    case notFound(String)
    case rateLimited(retryAfter: TimeInterval?)
    case downloadCorrupted(String)

    public static func == (lhs: HuggingFaceError, rhs: HuggingFaceError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.networkError, .networkError),
             (.decodingError, .decodingError),
             (.fileError, .fileError):
            return true
        case (.downloadCorrupted(let lhsMessage), .downloadCorrupted(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.unauthorized(let lhsMessage), .unauthorized(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.forbidden(let lhsMessage), .forbidden(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.notFound(let lhsMessage), .notFound(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.rateLimited(let lhsRetry), .rateLimited(let rhsRetry)):
            return lhsRetry == rhsRetry
        default:
            return false
        }
    }

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Network error occurred"
        case .decodingError:
            return "Failed to decode response"
        case .fileError:
            return "File operation failed"
        case .unauthorized(let message):
            return "Unauthorized: \(message)"
        case .forbidden(let message):
            return "Forbidden: \(message)"
        case .notFound(let message):
            return "Not found: \(message)"
        case .rateLimited(let retryAfter):
            if let retryAfter {
                let seconds = Int(retryAfter.rounded())
                return "Rate limited. Retry after ~\(seconds)s"
            }
            return "Rate limited by Hugging Face"
        case .downloadCorrupted(let message):
            return "Download corrupted: \(message)"
        }
    }
}
