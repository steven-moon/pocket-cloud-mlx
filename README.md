# PocketCloud MLX

PocketCloud MLX is the core local inference engine for the PocketCloud ecosystem, providing native Apple Silicon acceleration via MLX.

## Origin & Legacy

This project is a **fork/upgrade** of the [mlx-engine](https://github.com/steven-moon/mlx-engine) repository, which was the foundational local inference engine that powered the original [mlx-engine-cursor-workspace](https://github.com/steven-moon/mlx-engine-cursor-workspace) — the direct predecessor to the PocketCloud ecosystem.

The `mlx-engine` is currently in production use and will continue to be maintained for backward compatibility with existing projects. This new `pocket-cloud-mlx` builds upon that foundation with improvements tailored for the PocketCloud architecture.

## Development Setup

### Referencing Legacy Code

During development, it's helpful to have the legacy `mlx-engine` repository available locally for reference. To set this up:

1. Clone the legacy repository into this project directory:

   ```bash
   cd pocket-cloud-mlx
   git clone git@github.com:steven-moon/mlx-engine.git mlx-engine-legacy
   ```

2. The `mlx-engine-legacy` folder is already added to `.gitignore`, so it won't be committed to this repository.

3. Use this local copy to reference the original implementation while building out the PocketCloud MLX features.

### Why Keep Legacy Code Locally?

- **Reference Implementation**: Easily compare and port existing MLX functionality
- **Migration Path**: Understand the original architecture while designing improvements
- **Testing Compatibility**: Verify that new implementations maintain compatibility with existing model formats
- **Performance Benchmarking**: Compare performance between legacy and new implementations

## Relationship to PocketCloud Ecosystem

PocketCloud MLX serves as the core local inference engine across:

- **PocketCloud AI Agent** — Primary backend for local-first AI inference
- **PocketCloud BrainDeck** — Local embeddings and semantic search
- **Sample Apps** — Reference implementations and demos
- **Future PocketCloud applications** — Any app requiring local ML inference

## Features (Planned)

- Native Apple Silicon (M1/M2/M3/M4) acceleration via MLX
- Support for LLMs, Vision Models, and Embedding Models
- Efficient memory management for large models
- Streaming inference support
- Model quantization and optimization
- Cross-platform abstraction layer

## License

[TBD]

## Contributing

[TBD]
