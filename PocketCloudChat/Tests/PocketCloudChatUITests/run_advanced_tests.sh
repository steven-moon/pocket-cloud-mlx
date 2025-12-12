#!/bin/bash

# MLX Chat App Advanced Features Test Runner
# This script runs comprehensive tests with real model downloads

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Load test environment
if [ -f "$SCRIPT_DIR/test.env" ]; then
    source "$SCRIPT_DIR/test.env"
fi

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_header() {
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN} MLX Chat App Advanced Features Tests${NC}"
    echo -e "${GREEN}================================${NC}"
    echo
}

run_tests() {
    print_header

    cd "$PROJECT_ROOT/mlx-engine"

    echo "🧪 Running advanced features tests..."
    echo "   Test Models: $TEST_MODELS_DIR"
    echo "   Test Adapters: $TEST_ADAPTERS_DIR"
    echo "   Results: $TEST_RESULTS_DIR"
    echo

    # Load HuggingFace token if available
    if [ -f "$SCRIPT_DIR/../../../huggingface_token.txt" ]; then
        export HUGGINGFACE_TOKEN=$(cat "$SCRIPT_DIR/../../../huggingface_token.txt")
        echo "✅ HuggingFace token loaded"
    fi

    # Run the tests
    if swift test --filter MLXChatAppAdvancedFeaturesTests; then
        echo -e "${GREEN}🎉 All tests passed!${NC}"
    else
        echo -e "${RED}❌ Some tests failed${NC}"
        exit 1
    fi
}

cleanup() {
    echo
    echo "🧹 Cleaning up test artifacts..."

    # Optional: clean up downloaded models
    read -p "Do you want to clean up downloaded test models? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$TEST_MODELS_DIR" "$TEST_ADAPTERS_DIR"
        echo "✅ Test artifacts cleaned up"
    fi
}

# Main execution
run_tests
cleanup
