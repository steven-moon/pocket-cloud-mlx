#!/bin/bash

# MLX Chat App Advanced Features Test Setup
# This script helps configure the test environment for running comprehensive tests

set -e

echo "🚀 MLX Chat App Advanced Features Test Setup"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
TEST_DIR="$SCRIPT_DIR"
CONFIG_FILE="$TEST_DIR/../../../huggingface_token.txt"

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

check_dependencies() {
    print_step "Checking dependencies..."

    # Check for required tools
    local missing_tools=()

    if ! command -v swift &> /dev/null; then
        missing_tools+=("swift")
    fi

    if ! command -v git &> /dev/null; then
        missing_tools+=("git")
    fi

    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo "Please install missing tools and try again."
        exit 1
    fi

    print_success "All dependencies are available"
}

setup_huggingface_token() {
    print_step "Setting up HuggingFace token..."

    # Check if token is already configured
    if [ -f "$CONFIG_FILE" ]; then
        print_warning "HuggingFace token file already exists at $CONFIG_FILE"
        read -p "Do you want to update it? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_success "Keeping existing token configuration"
            return
        fi
    fi

    # Prompt for token
    echo
    echo "To run comprehensive tests with real models, you need a HuggingFace token."
    echo "You can get one from: https://huggingface.co/settings/tokens"
    echo
    read -p "Enter your HuggingFace token (or press Enter to skip): " -r
    echo

    if [ -z "$REPLY" ]; then
        print_warning "No token provided - some tests will be skipped"
        return
    fi

    # Save token securely
    echo "$REPLY" > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE" # Secure permissions

    print_success "HuggingFace token saved securely"

    # Validate token
    print_step "Validating token..."
    if validate_token "$REPLY"; then
        print_success "Token is valid!"
    else
        print_error "Token validation failed"
        rm -f "$CONFIG_FILE"
        exit 1
    fi
}

validate_token() {
    local token="$1"
    local response

    response=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $token" \
        "https://huggingface.co/api/whoami-v2")

    [ "$response" = "200" ]
}

setup_test_environment() {
    print_step "Setting up test environment..."

    # Create test directories
    mkdir -p "$PROJECT_ROOT/test-models"
    mkdir -p "$PROJECT_ROOT/test-adapters"
    mkdir -p "$PROJECT_ROOT/test-results"

    # Set up environment variables for testing
    cat > "$TEST_DIR/test.env" << EOF
# MLX Chat App Test Environment Configuration
export RUN_REAL_MODEL_TESTS=true
export CI=false
export TEST_MODELS_DIR="$PROJECT_ROOT/test-models"
export TEST_ADAPTERS_DIR="$PROJECT_ROOT/test-adapters"
export TEST_RESULTS_DIR="$PROJECT_ROOT/test-results"
EOF

    print_success "Test environment configured"
}

create_test_runner() {
    print_step "Creating test runner script..."

    cat > "$TEST_DIR/run_advanced_tests.sh" << 'EOF'
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
EOF

    chmod +x "$TEST_DIR/run_advanced_tests.sh"
    print_success "Test runner script created"
}

display_setup_summary() {
    print_success "Setup complete!"
    echo
    echo "📋 Setup Summary:"
    echo "=================="
    echo "• Test configuration created"
    echo "• Environment variables configured"
    echo "• Test runner script created"
    if [ -f "$CONFIG_FILE" ]; then
        echo "• HuggingFace token configured"
    fi
    echo
    echo "🚀 To run the tests:"
    echo "   cd mlx-engine/MLXChatApp/Tests/MLXChatAppUITests"
    echo "   ./run_advanced_tests.sh"
    echo
    echo "🔧 To run tests manually:"
    echo "   cd mlx-engine"
    echo "   swift test --filter MLXChatAppAdvancedFeaturesTests"
    echo
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "⚠️  Note: Some tests require a HuggingFace token"
        echo "   Run this setup script again to configure it"
    fi
}

# Main execution
main() {
    check_dependencies
    setup_huggingface_token
    setup_test_environment
    create_test_runner
    display_setup_summary
}

# Run main function
main "$@"
