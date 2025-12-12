# PocketCloud MLX

**Core Local Inference Engine - Apple Silicon Acceleration for Private AI**

The high-performance local inference engine powering the PocketCloud ecosystem with native Apple Silicon acceleration via MLX. Enables private, local-first AI inference across vision models, language models, and embeddings while optimizing for thermal constraints and battery life on mobile devices.

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20visionOS-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 🌟 Features

### **Native Apple Silicon Acceleration**
- **MLX-Powered Performance**: Harnessing Apple Silicon Neural Engines for 10x faster inference than CPU-only alternatives
- **Unified Architecture**: Same performant core across Mac Studio, MacBook Pro, iPhone Pro, and Apple Vision Pro
- **Energy-Efficient Computing**: Optimized for thermal constraints and battery life preservation

### **Multi-Modal Inference Support**
- **Vision Intelligence**: Florence-2, CLIP integration for real-time visual analysis on-device
- **Language Models**: Llama, Phi, and other leading open-source LLMs optimized for Apple Silicon
- **Embedding Models**: Local semantic search with privacy-preserving vector processing
- **Streaming Outputs**: Real-time response generation with adaptive quality-speed tradeoffs

### **Memory & Performance Optimization**
- **Dynamic Quantization**: Automatic model compression based on device capabilities and task requirements
- **Progressive Loading**: Lazy model initialization with memory-mapped loading for minimal startup time
- **Adaptive Batching**: Intelligent batch size optimization based on thermal and memory constraints

## 🏗️ Architecture

```
PocketCloudMLX/
├── Sources/
│   ├── PocketCloudMLX/
│   │   ├── Core/                    # MLX C++ bindings and acceleration layer
│   │   │   ├── AccelerationEngine.swift
│   │   │   ├── MemoryManager.swift
│   │   │   └── PerformanceMonitor.swift
│   │   ├── Models/                  # Model management and loading
│   │   │   ├── ModelLoader.swift
│   │   │   ├── QuantizationEngine.swift
│   │   │   └── ModelCache.swift
│   │   ├── Inference/               # Inference execution engines
│   │   │   ├── LanguageEngine.swift # LLM inference
│   │   │   ├── VisionEngine.swift   # Vision model processing
│   │   │   └── EmbeddingEngine.swift # Vector embeddings
│   │   └── Utils/                   # Cross-platform utilities
│   │       ├── MetalBridge.swift    # Metal compute integration
│   │       └── PlatformAdapter.swift # Hardware adaptation
├── Tests/
└── Documentation/
    ├── Implementation-Plan/          # Development roadmap
    └── Performance-Guide.md          # Optimization techniques
```

## 📦 Dependencies

Part of the **PocketCloud Ecosystem**:
- [PocketCloudCommon](https://github.com/steven-moon/pocket-cloud-common) - Shared utilities and cryptography
- [PocketCloudLogger](https://github.com/steven-moon/pocket-cloud-logger) - Performance monitoring and observability

**External Dependencies:**
- [MLX](https://github.com/ml-explore/mlx) - Apple Silicon machine learning framework

## 🚀 Getting Started

### Prerequisites

- **Swift 6.0+**
- **Apple Silicon Mac** (M1/M2/M3/M4) or **iOS 18+**
- **Xcode 16.0+**

### Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/steven-moon/pocket-cloud-mlx.git", from: "1.0.0"),
    .package(path: "../pocket-cloud-common"),
    .package(path: "../pocket-cloud-logger")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            "PocketCloudMLX",
            "PocketCloudCommon",
            "PocketCloudLogger"
        ]
    )
]
```

### Quick Start

```swift
import PocketCloudMLX

// Initialize MLX engine with automatic hardware detection
let engine = MLXInferenceEngine()

// Load and quantize a vision model for mobile efficiency
let visionModel = try await engine.loadVisionModel(
    "florence-2-base",
    quantization: .int4  // 75% memory reduction
)

// Process camera input with zero latency
let cameraFrame = camera.captureFrame()
let visionResult = try await engine.processVision(
    image: cameraFrame,
    model: visionModel,
    task: .caption  // Real-time image captioning
)

// Run LLM inference with streaming
let languageModel = try await engine.loadLanguageModel(
    "llama-3.1-8b-instruct",
    contextWindow: 4096
)

for try await token in engine.generateStream(
    prompt: "Explain quantum computing",
    model: languageModel,
    maxTokens: 500
) {
    print(token, terminator: "")
}

// Generate embeddings for semantic search
let embeddingModel = try await engine.loadEmbeddingModel("bge-small-en-v1.5")
let documents = ["AI safety", "machine learning ethics", "neural networks"]
let embeddings = try await engine.generateEmbeddings(
    texts: documents,
    model: embeddingModel
)
```

## 📖 Documentation

- [Implementation Plan](Documentation/Implementation-Plan/implementation-plan-overview.md)
- [Performance Optimization Guide](Documentation/Performance-Guide.md)
- [Model Compatibility Matrix](Documentation/Model-Support.md)

## 🤝 Contributing

### Development Setup

This project is a **fork/upgrade** of the [mlx-engine](https://github.com/steven-moon/mlx-engine) repository. For reference:

```bash
# Clone legacy code for comparison (optional)
git clone git@github.com:steven-moon/mlx-engine.git mlx-engine-legacy
```

**Contribution Areas:**
- MLX integration enhancements and performance improvements
- New model architecture support and quantization techniques
- Cross-platform hardware adaptation and optimization
- Memory management and thermal constraint handling

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

**PocketCloud MLX: Local Inference Revolution on Apple Silicon** 🧠⚡
