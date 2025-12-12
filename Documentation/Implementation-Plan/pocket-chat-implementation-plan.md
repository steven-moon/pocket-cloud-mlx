# PocketChat Implementation Plan

## Overview

This plan outlines the steps to recreate the PocketChat application for the pocket-cloud-mlx repository, based on the functional MLXChatApp from the mlx-engine-legacy. The new PocketChat app will utilize the PocketCloudMLX engine and integrate with the PocketCloudUI component library, targeting the same platforms supported by the legacy app.

## Background

- **Legacy App**: MLXChatApp (pocket-cloud-mlx/mlx-engine-legacy/MLXChatApp/) is currently deployed on TestFlight and actively used.
- **Dependencies (Legacy)**: 
  - MLXEngine (local)
  - AIDevSwiftUIKit (local UI components)
- **Targets (Legacy)**:
  - Universal iOS app (supports iPhone, iPad, Mac Catalyst, visionOS)
  - Native macOS app
  - Unit and UI tests
- **New Ecosystem**: PocketCloudMLX engine, PocketCloudUI library, aligned with PocketCloud family of applications.

## Objectives

1. Create a new PocketChat application that mirrors MLXChatApp functionality
2. Migrate from legacy MLXEngine/AIDevSwiftUIKit to PocketCloudMLX/PocketCloudUI
3. Maintain identical platform support and deployment targets
4. Ensure compatibility with existing chat session data and user workflows
5. Update to modern development team and bundle identifier conventions

## Implementation Steps

### 1. Project Setup

#### 1.1 Create PocketChat Directory Structure
```
pocket-cloud-mlx/PocketChat/
├── project.yml          # New XcodeGen configuration
├── Sources/             # Shared and platform-specific source files
│   ├── Shared/          # Cross-platform code
│   ├── iOS/             # iOS-specific code and assets
│   ├── macOS/           # macOS-specific code and assets
│   └── PocketChat/      # App-specific shared code
├── Tests/               # Test targets
│   ├── PocketChatTests/
│   └── PocketChatUITests/
└── Resources/           # Shared resources
```

#### 1.2 Copy Source Files from MLXChatApp
- Copy all source files from `mlx-engine-legacy/MLXChatApp/Sources/` to `PocketChat/Sources/`
- Preserve the Shared, iOS, PocketChat structure
- Copy Info.plist and entitlements if needed

#### 1.3 Create XcodeGen Configuration
- See section 3.1 for detailed project.yml structure
- Update bundle identifier prefix to `com.pocketcloud`
- Configure dependencies: PocketCloudMLX, PocketCloudUI, PocketCloudLogger, PocketCloudCommon

### 2. Dependency Migration

#### 2.1 Update Import Statements
- Replace `import MLXEngine` with `import PocketCloudMLX`
- Replace `import AIDevSwiftUIKit` with `import PocketCloudUI`
- Update any other legacy package imports (e.g., logging, common utilities)

#### 2.2 API Compatibility Assessment
- Ensure PocketCloudMLX provides equivalent APIs to legacy MLXEngine
- Verify PocketCloudUI components match or extend AIDevSwiftUIKit functionality
- Update method calls to use new API signatures where necessary

#### 2.3 Test Package Availability
- Confirm PocketCloudMLX, PocketCloudUI, and other dependencies are available in the workspace
- Update Package.swift if dependencies need adjustment

### 3. Configuration Updates

#### 3.1 Project.yml Configuration
```yaml
name: PocketChat
options:
  bundleIdPrefix: com.pocketcloud
  deploymentTarget:
    iOS: '18.0'
    macOS: '15.0'
    visionOS: '2.0'

packages:
  PocketCloudMLX:     # Local MLX engine
    path: ../
  PocketCloudUI:       # UI components
    path: ../../pocket-cloud-ui
  PocketCloudLogger:   # Logging
    path: ../../pocket-cloud-logger
  PocketCloudCommon:   # Shared utilities
    path: ../../pocket-cloud-common

targets:
  # Universal iOS App (iPhone + iPad + Mac Catalyst + visionOS)
  PocketChat-Universal:
    type: application
    platform: iOS
    sources: [Sources/Shared, Sources/iOS, Sources/PocketChat]
    settings:
      GENERATE_INFOPLIST_FILE: NO
      INFOPLIST_FILE: Sources/iOS/Info.plist
      DEVELOPMENT_TEAM: M3W42R75UU
      PRODUCT_BUNDLE_IDENTIFIER: com.pocketcloud.PocketChat
      CODE_SIGN_IDENTITY: "iPhone Developer"
      TARGETED_DEVICE_FAMILY: "1,2,6"  # iPhone, iPad, visionOS
      # ... (match other settings from legacy)
    dependencies:
      - package: PocketCloudMLX
        product: PocketCloudMLX
      - package: PocketCloudUI
        product: PocketCloudUI
      - package: PocketCloudLogger
        product: PocketCloudLogger
      - package: PocketCloudCommon
        product: PocketCloudCommon

  # Native macOS App
  PocketChat-macOS:
    type: application
    platform: macOS
    sources: [Sources/Shared, Sources/PocketChat]
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.pocketcloud.PocketChat.macOS
      # Apple Silicon only
      EXCLUDED_ARCHS: x86_64 arm64e
      # ... (match other settings)
    dependencies:
      - package: PocketCloudMLX
        product: PocketCloudMLX
      - package: PocketCloudUI
        product: PocketCloudUI

  # Unit Tests
  PocketChatTests: ...

  # UI Tests
  PocketChatUITests: ...
```

#### 3.2 Update Bundle Identifiers
- iOS App: `com.pocketcloud.PocketChat`
- macOS App: `com.pocketcloud.PocketChat.macOS`
- Test targets: Append `.tests` and `.uitests`

#### 3.3 Asset Migration
- Copy Assets.xcassets from MLXChatApp
- Update app icons if needed (maintain compatibility with legacy icon structure)
- Ensure platform-specific resources are properly configured

### 4. Source Code Migration

#### 4.1 Core Functionality Verification
- **Chat Sessions**: Verify ChatSessionManager interfaces match
- **Model Management**: Ensure model loading/configuration APIs are compatible
- **Inference Engine**: Confirm InferenceEngine usage patterns work with PocketCloudMLX
- **UI Components**: Test chat UI, model selection, settings views with PocketCloudUI

#### 4.2 Error Handling
- Update error types and handling for new MLX APIs
- Preserve user-facing error messages where possible

#### 4.3 Logging Integration
- Replace legacy logging with PocketCloudLogger
- Ensure debug/trace logs are properly configured

### 5. Testing and Validation

#### 5.1 Unit Tests
- Port existing MLXEngineTests to PocketChatTests
- Test API compatibility and integration points
- Validate model loading and inference functionality

#### 5.2 UI Tests
- Adapt MLXChatAppUITests to test PocketChat interfaces
- Verify platform-specific behaviors (iOS, macOS)
- Test cross-platform compatibility

#### 5.3 Manual Testing
- Perform side-by-side testing with MLXChatApp
- Validate all chat features work identically
- Test visionOS support and optimizations

### 6. Build and Deployment

#### 6.1 Xcode Workspace Integration
- Ensure project builds successfully in Xcode 16.0+
- Verify Swift 6.0 compatibility
- Test code signing and entitlements

#### 6.2 TestFlight Deployment
- Update provisioning profiles for new bundle IDs
- Configure TestFlight builds similar to legacy app
- Test installation and basic functionality

#### 6.3 App Store Preparation
- Prepare app metadata (maintain naming conventions)
- Update privacy manifests and entitlements
- Ready for submission alongside legacy app upgrade path

### 7. Migration Strategy

#### 7.1 User Data Compatibility
- Design data migration path for chat history
- Ensure model caches are compatible where possible
- Consider backwards compatibility during transition period

#### 7.2 Feature Parity Verification
- Compare feature lists between MLXChatApp and PocketChat
- Document any intentional changes or improvements
- Validate performance characteristics match

### 8. Rollout and Monitoring

#### 8.1 Internal Testing
- Beta testing with internal team
- Compare against MLXChatApp metrics
- Performance benchmarking

#### 8.2 Production Deployment
- Staged rollout (internal → beta testers)
- Monitor crash reports and user feedback
- Prepare hotfix capability

## Dependencies and Prerequisites

- PocketCloudMLX: Core inference engine (assumed complete)
- PocketCloudUI: UI component library (assumed compatible with AIDevSwiftUIKit)
- PocketCloudLogger: Logging framework
- PocketCloudCommon: Shared utilities
- Xcode 16.0+ with Swift 6.0
- Apple Silicon macOS for development

## Risk Assessment

- **API Changes**: Potential breaking changes in PocketCloudMLX vs MLXEngine
  - Mitigate: Comprehensive testing and API mapping
- **UI Compatibility**: Component differences between WalletCloudUI and AIDevSwiftUIKit
  - Mitigate: Visual comparison testing, component adapter layer if needed
- **Performance**: Ensure inference performance matches or exceeds legacy
  - Mitigate: Benchmarking against known MLXChatApp metrics

## Success Criteria

1. PocketChat builds and runs on all target platforms
2. All MLXChatApp features function identically
3. Performance and user experience match legacy app
4. Successful TestFlight deployment
5. Clean migration path for existing users

## Timeline

- **Phase 1 (Week 1)**: Project setup, dependency migration, basic build
- **Phase 2 (Week 2)**: Source code porting, API updates, testing
- **Phase 3 (Week 3)**: Integration testing, UI validation, beta deployment
- **Phase 4 (Week 4)**: Production rollout, monitoring, hotfixes

This plan ensures PocketChat replicates MLXChatApp's success while modernizing the architecture to align with the PocketCloud ecosystem.
