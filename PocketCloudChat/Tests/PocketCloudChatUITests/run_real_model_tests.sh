#!/bin/bash

# MLX Chat App Real Model Test Runner
# Downloads and tests real models from HuggingFace

set -e

echo "🚀 MLX Chat App Real Model Test Runner"
echo "======================================="

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
TEST_DIR="$SCRIPT_DIR"
TOKEN_FILE="$PROJECT_ROOT/huggingface_token.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    print_step "Checking prerequisites..."

    # Check for Swift
    if ! command -v swift &> /dev/null; then
        print_error "Swift not found. Please install Xcode or Swift toolchain."
        exit 1
    fi

    # Check for HuggingFace token
    if [ ! -f "$TOKEN_FILE" ]; then
        print_warning "HuggingFace token not found at $TOKEN_FILE"
        echo
        echo "To set up your token, run:"
        echo "  ./setup_huggingface_token.sh"
        echo
        read -p "Do you want to set up the token now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ./setup_huggingface_token.sh
        else
            print_error "HuggingFace token required for real model tests"
            exit 1
        fi
    fi

    # Validate token
    if ! ./setup_huggingface_token.sh -t "$(cat "$TOKEN_FILE")" 2>/dev/null; then
        print_error "Invalid HuggingFace token"
        exit 1
    fi

    print_success "Prerequisites check passed"
}

setup_test_environment() {
    print_step "Setting up test environment..."

    # Create test directories
    mkdir -p "$PROJECT_ROOT/test-models"
    mkdir -p "$PROJECT_ROOT/test-adapters"
    mkdir -p "$PROJECT_ROOT/test-results"

    # Set environment variables
    export RUN_REAL_MODEL_TESTS=true
    export HUGGINGFACE_TOKEN="$(cat "$TOKEN_FILE")"
    export TEST_MODELS_DIR="$PROJECT_ROOT/test-models"
    export TEST_ADAPTERS_DIR="$PROJECT_ROOT/test-adapters"
    export TEST_RESULTS_DIR="$PROJECT_ROOT/test-results"

    print_success "Test environment configured"
}

run_tests() {
    local test_filter="${1:-MLXChatAppAdvancedFeaturesTests}"

    print_step "Running real model tests..."

    cd "$PROJECT_ROOT/mlx-engine"

    echo "🧪 Test Configuration:"
    echo "   Filter: $test_filter"
    echo "   Models Directory: $TEST_MODELS_DIR"
    echo "   Adapters Directory: $TEST_ADAPTERS_DIR"
    echo "   Results Directory: $TEST_RESULTS_DIR"
    echo

    # Run the tests
    if swift test --filter "$test_filter" --verbose; then
        print_success "All tests passed successfully! 🎉"
        return 0
    else
        print_error "Some tests failed"
        return 1
    fi
}

display_results() {
    echo
    echo "📊 Test Results Summary"
    echo "========================"

    # Show downloaded models
    if [ -d "$TEST_MODELS_DIR" ] && [ "$(ls -A "$TEST_MODELS_DIR" 2>/dev/null)" ]; then
        echo "📥 Downloaded Models:"
        find "$TEST_MODELS_DIR" -maxdepth 2 -type d -name "*.safetensors" -o -name "*.bin" -o -name "*.gguf" | head -10 | while read -r file; do
            echo "   • $(basename "$(dirname "$file")")/$(basename "$file")"
        done
        echo
    fi

    # Show downloaded adapters
    if [ -d "$TEST_ADAPTERS_DIR" ] && [ "$(ls -A "$TEST_ADAPTERS_DIR" 2>/dev/null)" ]; then
        echo "🔌 Downloaded Adapters:"
        ls -la "$TEST_ADAPTERS_DIR" | grep "^d" | tail -n +2 | while read -r line; do
            dir_name=$(echo "$line" | awk '{print $9}')
            if [ -n "$dir_name" ] && [ "$dir_name" != "." ] && [ "$dir_name" != ".." ]; then
                size=$(du -sh "$TEST_ADAPTERS_DIR/$dir_name" 2>/dev/null | cut -f1)
                echo "   • $dir_name ($size)"
            fi
        done
        echo
    fi

    # Show test results
    if [ -d "$TEST_RESULTS_DIR" ]; then
        echo "📈 Test Performance Data:"
        find "$TEST_RESULTS_DIR" -name "*.json" -o -name "*.txt" | head -5 | while read -r file; do
            echo "   • $(basename "$file")"
        done
        echo
    fi
}

cleanup_artifacts() {
    echo
    read -p "Do you want to clean up downloaded test models and adapters? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_step "Cleaning up test artifacts..."

        rm -rf "$TEST_MODELS_DIR"
        rm -rf "$TEST_ADAPTERS_DIR"

        print_success "Test artifacts cleaned up"
    else
        print_success "Test artifacts preserved at:"
        echo "   Models: $TEST_MODELS_DIR"
        echo "   Adapters: $TEST_ADAPTERS_DIR"
    fi
}

show_usage() {
    echo "Usage: $0 [OPTIONS] [TEST_FILTER]"
    echo
    echo "Run comprehensive MLX Chat App tests with real model downloads"
    echo
    echo "Arguments:"
    echo "  TEST_FILTER    Test class or method filter (default: MLXChatAppAdvancedFeaturesTests)"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --no-cleanup   Skip cleanup prompt"
    echo
    echo "Examples:"
    echo "  $0                                    # Run all advanced features tests"
    echo "  $0 MLXChatAppAdvancedFeaturesTests    # Run specific test class"
    echo "  $0 --no-cleanup                       # Keep test artifacts"
    echo
    echo "Environment Variables:"
    echo "  HUGGINGFACE_TOKEN     Your HuggingFace API token"
    echo "  RUN_REAL_MODEL_TESTS  Enable real model downloads (auto-set)"
    echo "  TEST_MODELS_DIR       Directory for test models (auto-set)"
    echo "  TEST_ADAPTERS_DIR     Directory for test adapters (auto-set)"
}

main() {
    local skip_cleanup=false
    local test_filter=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --no-cleanup)
                skip_cleanup=true
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$test_filter" ]; then
                    test_filter="$1"
                else
                    print_error "Multiple test filters not supported"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Set default test filter
    if [ -z "$test_filter" ]; then
        test_filter="MLXChatAppAdvancedFeaturesTests"
    fi

    echo "🔬 Running MLX Chat App Advanced Features Tests with Real Models"
    echo "================================================================="
    echo "   Test Filter: $test_filter"
    echo "   Skip Cleanup: $skip_cleanup"
    echo

    check_prerequisites
    setup_test_environment

    if run_tests "$test_filter"; then
        display_results

        if [ "$skip_cleanup" = false ]; then
            cleanup_artifacts
        fi

        print_success "Real model testing completed successfully!"
        echo
        echo "🎉 Your MLX Chat App is ready for production use!"
    else
        print_error "Real model testing failed"
        exit 1
    fi
}

# Run main function
main "$@"
