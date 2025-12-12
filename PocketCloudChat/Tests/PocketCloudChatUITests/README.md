# MLX Chat App Advanced Features Test Suite

This comprehensive test suite validates the MLX Chat App's advanced features, including LoRA adapter management, real model downloads, and end-to-end functionality testing.

## 🚀 Quick Start

### 1. Setup Test Environment

Run the automated setup script:

```bash
cd mlx-engine/MLXChatApp/Tests/MLXChatAppUITests
chmod +x setup_test_environment.sh
./setup_test_environment.sh
```

This script will:
- Check for required dependencies
- Prompt for HuggingFace token (optional but recommended)
- Configure test environment variables
- Create test runner script

### 2. Run Tests

```bash
# Option 1: Use the test runner script (recommended)
./run_advanced_tests.sh

# Option 2: Run tests directly
cd ../../../../mlx-engine
swift test --filter MLXChatAppAdvancedFeaturesTests
```

## 🧪 Test Coverage

### LoRA Adapter Management Tests
- ✅ **Adapter Discovery** - Validates adapter loading and metadata parsing
- ✅ **Adapter Download** - Tests real adapter downloads from HuggingFace
- ✅ **Adapter Application** - Verifies adapter integration with chat sessions
- ✅ **Adapter Compatibility** - Tests compatibility checking with models
- ✅ **Adapter Management** - Tests activation, deactivation, and removal

### Model Integration Tests
- ✅ **Model Download** - Downloads and verifies real models from HuggingFace
- ✅ **Model Loading** - Tests model loading and initialization
- ✅ **Chat Functionality** - End-to-end chat testing with real models
- ✅ **Streaming Chat** - Tests real-time streaming responses
- ✅ **Document Processing** - Tests document upload and analysis

### UI Component Tests
- ✅ **View Model Testing** - Tests LoRA adapter view model functionality
- ✅ **State Management** - Validates reactive UI state updates
- ✅ **Search & Filtering** - Tests adapter discovery and filtering
- ✅ **Progress Tracking** - Validates download progress reporting

### Integration & Performance Tests
- ✅ **Full Integration Flow** - Complete end-to-end workflow testing
- ✅ **Performance Metrics** - Measures response times and resource usage
- ✅ **Error Handling** - Tests graceful error handling and recovery
- ✅ **Resource Cleanup** - Validates proper cleanup of test artifacts

## 🔐 HuggingFace Token Setup

### Option 1: Interactive Setup (Recommended)
Run the setup script and enter your token when prompted:
```bash
./setup_test_environment.sh
```

### Option 2: Manual Configuration
Create a file named `huggingface_token.txt` in the project root:
```bash
echo "your_huggingface_token_here" > ../../../../huggingface_token.txt
chmod 600 ../../../../huggingface_token.txt
```

### Option 3: Environment Variable
Set the token as an environment variable:
```bash
export HUGGINGFACE_TOKEN="your_token_here"
```

## 🏗️ Test Configuration

### Test Models
The test suite uses these optimized models for testing:

| Model | Size | Use Case | Download Time |
|-------|------|----------|----------------|
| TinyLlama-1.1B-Chat-v1.0 | ~2.2GB | General testing | ~1 minute |
| Qwen2-0.5B-Instruct | ~1GB | Fast testing | ~30 seconds |
| Phi-3-mini-4k-instruct | ~7.6GB | Comprehensive testing | ~3 minutes |

### Test Adapters
Pre-configured LoRA adapters for testing:

| Adapter | Size | Category | Base Model |
|---------|------|----------|------------|
| Medical Assistant | ~50MB | Medical | Llama-2-7B |
| Coding Assistant | ~45MB | Programming | Llama-2-7B |
| Legal Assistant | ~48MB | Legal | Llama-2-7B |

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `RUN_REAL_MODEL_TESTS` | Enable real model downloads | `false` |
| `CI` | Running in CI environment | `false` |
| `HUGGINGFACE_TOKEN` | HuggingFace API token | `nil` |

## 📊 Test Results & Reporting

### Test Output
Tests provide detailed output including:
- 📥 Download progress and speed
- 🤖 Model response times and quality
- 📊 Performance metrics
- 🚨 Error details and recovery actions

### Performance Benchmarks
The test suite measures:
- Model download times
- First response latency
- Streaming response throughput
- Memory usage patterns
- Adapter application overhead

## 🛠️ Troubleshooting

### Common Issues

#### "HuggingFace token required"
**Solution**: Run setup script and provide a valid token, or set `HUGGINGFACE_TOKEN` environment variable.

#### "Model download failed"
**Solutions**:
- Check internet connection
- Verify HuggingFace token permissions
- Ensure sufficient disk space (models can be 1-8GB)
- Check firewall/proxy settings

#### "Adapter compatibility error"
**Solution**: Ensure the adapter's base model matches the selected chat model.

#### "Test timeout"
**Solution**: Increase timeout in TestConfiguration or check network speed.

### Debug Mode
Enable detailed logging:
```bash
export DEBUG_MLX_TESTS=1
./run_advanced_tests.sh
```

### Cleanup
Remove test artifacts:
```bash
rm -rf test-models test-adapters test-results
```

## 🏛️ Architecture

### Test Structure
```
Tests/
├── MLXChatAppAdvancedFeaturesTests.swift  # Main test suite
├── TestConfiguration.swift                # Test configuration
├── setup_test_environment.sh              # Setup script
├── run_advanced_tests.sh                  # Test runner
└── README.md                             # This documentation
```

### Test Flow
1. **Environment Setup** - Load configuration and credentials
2. **Model Discovery** - Find available models and adapters
3. **Download Phase** - Download test models/adapters
4. **Integration Testing** - Test real functionality
5. **Performance Testing** - Measure and validate performance
6. **Cleanup** - Remove test artifacts

## 🔒 Security Considerations

### Token Management
- Tokens are stored securely with restricted permissions
- Never committed to version control
- Environment variables take precedence over files

### Test Data
- Test models are downloaded to temporary directories
- Automatic cleanup removes test artifacts
- No sensitive data is transmitted in tests

## 📈 CI/CD Integration

### GitHub Actions
The test suite is designed for CI/CD environments:

```yaml
- name: Run Advanced Tests
  env:
    HUGGINGFACE_TOKEN: ${{ secrets.HUGGINGFACE_TOKEN }}
    RUN_REAL_MODEL_TESTS: true
    CI: true
  run: |
    cd mlx-engine/MLXChatApp/Tests/MLXChatAppUITests
    ./setup_test_environment.sh
    ./run_advanced_tests.sh
```

### Performance Tracking
Tests generate performance metrics that can be tracked over time to monitor:
- Model download speeds
- Inference performance
- Memory usage patterns
- Adapter application overhead

## 🎯 Best Practices

### For Contributors
1. **Run tests locally** before submitting PRs
2. **Use appropriate models** for different test scenarios
3. **Clean up artifacts** after testing
4. **Monitor performance** metrics for regressions

### For CI/CD
1. **Use smallest viable models** for faster CI runs
2. **Cache downloaded models** between runs
3. **Set appropriate timeouts** for different environments
4. **Monitor performance trends** over time

## 📞 Support

### Getting Help
- Check the troubleshooting section above
- Review test output for specific error messages
- Verify HuggingFace token permissions
- Ensure sufficient system resources

### Common Questions

**Q: Do I need a HuggingFace token?**
A: For basic tests, no. For comprehensive testing with real models, yes.

**Q: How long do tests take?**
A: Basic tests: 1-2 minutes. Full tests with downloads: 5-15 minutes.

**Q: What system resources are needed?**
A: 4GB+ RAM, 10GB+ free disk space, stable internet connection.

**Q: Can I run tests in parallel?**
A: Yes, tests are designed to be independent and can run concurrently.

---

## 🚀 Next Steps

After running these tests successfully, you'll have validated:

- ✅ **LoRA Adapter Management** - Complete adapter lifecycle
- ✅ **Real Model Integration** - Production-ready model handling
- ✅ **Advanced Chat Features** - Streaming, document processing
- ✅ **Performance & Reliability** - Real-world performance metrics
- ✅ **Security & Privacy** - Secure token handling and data protection

This comprehensive test suite ensures the MLX Chat App delivers on its promise of being a **professional AI customization platform** with **enterprise-grade features**! 🎉
