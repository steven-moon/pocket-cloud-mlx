#!/bin/bash

# MLX Chat App Test Results Analyzer
# Analyzes and displays comprehensive test results

set -e

echo "📊 MLX Chat App Test Results Analyzer"
echo "====================================="

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/test-results"
MODELS_DIR="$PROJECT_ROOT/test-models"
ADAPTERS_DIR="$PROJECT_ROOT/test-adapters"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Functions
print_header() {
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}$(printf '%.0s=' {1..${#1}})${NC}"
}

print_section() {
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}$(printf '%.0s-' {1..${#1}})${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${PURPLE}ℹ️  $1${NC}"
}

analyze_test_summary() {
    print_header "Test Execution Summary"

    # Check if we have test results
    if [ ! -d "$RESULTS_DIR" ]; then
        print_warning "No test results directory found"
        return
    fi

    # Analyze Swift test output if available
    if [ -f "$RESULTS_DIR/test_output.txt" ]; then
        echo "Test execution results:"
        echo

        # Count tests
        total_tests=$(grep -c "Test Case" "$RESULTS_DIR/test_output.txt" || echo "0")
        passed_tests=$(grep -c "passed" "$RESULTS_DIR/test_output.txt" || echo "0")
        failed_tests=$(grep -c "failed\|error" "$RESULTS_DIR/test_output.txt" || echo "0")

        if [ "$total_tests" -gt 0 ]; then
            success_rate=$((passed_tests * 100 / total_tests))

            if [ "$success_rate" -ge 90 ]; then
                print_success "Tests Passed: $passed_tests/$total_tests ($success_rate%)"
            elif [ "$success_rate" -ge 70 ]; then
                print_warning "Tests Passed: $passed_tests/$total_tests ($success_rate%)"
            else
                print_error "Tests Passed: $passed_tests/$total_tests ($success_rate%)"
            fi

            if [ "$failed_tests" -gt 0 ]; then
                print_error "Failed Tests: $failed_tests"
                echo "Failed test details:"
                grep -A 2 -B 2 "failed\|error" "$RESULTS_DIR/test_output.txt" | head -20
            fi
        fi
        echo
    fi
}

analyze_model_downloads() {
    print_section "Model Download Analysis"

    if [ ! -d "$MODELS_DIR" ]; then
        print_info "No test models directory found"
        return
    fi

    # Count downloaded models
    model_count=$(find "$MODELS_DIR" -maxdepth 1 -type d | wc -l)
    model_count=$((model_count - 1)) # Subtract the directory itself

    if [ "$model_count" -gt 0 ]; then
        print_success "Downloaded Models: $model_count"

        # List models with sizes
        echo "Model details:"
        for model_dir in "$MODELS_DIR"/*/; do
            if [ -d "$model_dir" ]; then
                model_name=$(basename "$model_dir")
                model_size=$(du -sh "$model_dir" 2>/dev/null | cut -f1)
                file_count=$(find "$model_dir" -type f \( -name "*.safetensors" -o -name "*.bin" -o -name "*.gguf" \) | wc -l)

                echo "  📥 $model_name ($model_size, $file_count files)"
            fi
        done
    else
        print_info "No models downloaded during testing"
    fi
    echo
}

analyze_adapter_downloads() {
    print_section "LoRA Adapter Analysis"

    if [ ! -d "$ADAPTERS_DIR" ]; then
        print_info "No test adapters directory found"
        return
    fi

    # Count downloaded adapters
    adapter_count=$(find "$ADAPTERS_DIR" -maxdepth 1 -type d | wc -l)
    adapter_count=$((adapter_count - 1)) # Subtract the directory itself

    if [ "$adapter_count" -gt 0 ]; then
        print_success "Downloaded Adapters: $adapter_count"

        # List adapters with sizes
        echo "Adapter details:"
        for adapter_dir in "$ADAPTERS_DIR"/*/; do
            if [ -d "$adapter_dir" ]; then
                adapter_name=$(basename "$adapter_dir")
                adapter_size=$(du -sh "$adapter_dir" 2>/dev/null | cut -f1)
                file_count=$(find "$adapter_dir" -name "*.safetensors" | wc -l)

                echo "  🔌 $adapter_name ($adapter_size, $file_count files)"
            fi
        done
    else
        print_info "No adapters downloaded during testing"
    fi
    echo
}

analyze_performance_data() {
    print_section "Performance Analysis"

    # Look for performance data files
    perf_files=$(find "$RESULTS_DIR" -name "*performance*" -o -name "*benchmark*" 2>/dev/null || echo "")

    if [ -z "$perf_files" ]; then
        print_info "No performance data found"
        return
    fi

    echo "Performance metrics:"

    for perf_file in $perf_files; do
        echo "📊 $(basename "$perf_file"):"

        # Extract key metrics (this would be more sophisticated in production)
        if grep -q "Cold start time\|Response time\|Memory usage\|Throughput" "$perf_file"; then
            grep "Cold start time\|Response time\|Memory usage\|Throughput\|Average\|Min\|Max" "$perf_file" | head -10
        else
            echo "  (Raw performance data available in file)"
        fi
        echo
    done
}

analyze_feature_coverage() {
    print_section "Feature Coverage Analysis"

    # Check what features were tested
    features_tested=()

    # Check for LoRA adapter tests
    if [ -d "$ADAPTERS_DIR" ] && [ "$(ls -A "$ADAPTERS_DIR" 2>/dev/null)" ]; then
        features_tested+=("LoRA Adapter Management")
    fi

    # Check for model tests
    if [ -d "$MODELS_DIR" ] && [ "$(ls -A "$MODELS_DIR" 2>/dev/null)" ]; then
        features_tested+=("Real Model Integration")
    fi

    # Check for streaming tests (look for streaming in output)
    if [ -f "$RESULTS_DIR/test_output.txt" ] && grep -q "streaming\|Streaming" "$RESULTS_DIR/test_output.txt"; then
        features_tested+=("Streaming Chat")
    fi

    # Check for document processing tests
    if [ -f "$RESULTS_DIR/test_output.txt" ] && grep -q "document\|Document" "$RESULTS_DIR/test_output.txt"; then
        features_tested+=("Document Processing")
    fi

    if [ ${#features_tested[@]} -gt 0 ]; then
        print_success "Features Successfully Tested:"
        for feature in "${features_tested[@]}"; do
            echo "  ✅ $feature"
        done
    else
        print_warning "No specific features identified in test results"
    fi
    echo
}

generate_recommendations() {
    print_section "Recommendations & Next Steps"

    recommendations=()

    # Check test coverage
    if [ ! -d "$MODELS_DIR" ] || [ ! "$(ls -A "$MODELS_DIR" 2>/dev/null)" ]; then
        recommendations+=("Consider running tests with real model downloads for complete validation")
    fi

    if [ ! -d "$ADAPTERS_DIR" ] || [ ! "$(ls -A "$ADAPTERS_DIR" 2>/dev/null)" ]; then
        recommendations+=("Test LoRA adapter functionality with real adapters")
    fi

    # Check performance
    if [ ! -f "$RESULTS_DIR/performance_baseline.json" ]; then
        recommendations+=("Establish performance baselines for future regression testing")
    fi

    recommendations+=("Monitor memory usage patterns during extended usage")
    recommendations+=("Test with different model sizes for comprehensive coverage")
    recommendations+=("Validate adapter compatibility across different model architectures")

    if [ ${#recommendations[@]} -gt 0 ]; then
        echo "Suggested improvements:"
        for rec in "${recommendations[@]}"; do
            echo "  💡 $rec"
        done
    fi
    echo
}

generate_summary() {
    print_header "Test Results Summary"

    # Overall assessment
    local score=0
    local max_score=100

    # Scoring based on different criteria
    if [ -d "$MODELS_DIR" ] && [ "$(ls -A "$MODELS_DIR" 2>/dev/null)" ]; then
        score=$((score + 30))
    fi

    if [ -d "$ADAPTERS_DIR" ] && [ "$(ls -A "$ADAPTERS_DIR" 2>/dev/null)" ]; then
        score=$((score + 25))
    fi

    if [ -f "$RESULTS_DIR/test_output.txt" ]; then
        if grep -q "passed" "$RESULTS_DIR/test_output.txt"; then
            score=$((score + 25))
        fi
    fi

    # Performance bonus
    if [ -f "$RESULTS_DIR/performance_data.json" ]; then
        score=$((score + 10))
    fi

    # Documentation bonus
    if [ -f "$RESULTS_DIR/feature_coverage.txt" ]; then
        score=$((score + 10))
    fi

    # Display score
    if [ "$score" -ge 80 ]; then
        print_success "Overall Score: $score/$max_score - Excellent!"
    elif [ "$score" -ge 60 ]; then
        print_success "Overall Score: $score/$max_score - Good!"
    elif [ "$score" -ge 40 ]; then
        print_warning "Overall Score: $score/$max_score - Fair"
    else
        print_error "Overall Score: $score/$max_score - Needs Improvement"
    fi

    echo
    echo "Scoring breakdown:"
    echo "  • Real Model Testing: $([ -d "$MODELS_DIR" ] && [ "$(ls -A "$MODELS_DIR" 2>/dev/null)" ] && echo "✅" || echo "❌")"
    echo "  • LoRA Adapter Testing: $([ -d "$ADAPTERS_DIR" ] && [ "$(ls -A "$ADAPTERS_DIR" 2>/dev/null)" ] && echo "✅" || echo "❌")"
    echo "  • Test Execution: $([ -f "$RESULTS_DIR/test_output.txt" ] && grep -q "passed" "$RESULTS_DIR/test_output.txt" && echo "✅" || echo "❌")"
    echo "  • Performance Analysis: $([ -f "$RESULTS_DIR/performance_data.json" ] && echo "✅" || echo "❌")"
    echo "  • Feature Coverage: $([ -f "$RESULTS_DIR/feature_coverage.txt" ] && echo "✅" || echo "❌")"
}

main() {
    # Create results directory if it doesn't exist
    mkdir -p "$RESULTS_DIR"

    echo "Analyzing test results from: $RESULTS_DIR"
    echo

    analyze_test_summary
    analyze_model_downloads
    analyze_adapter_downloads
    analyze_performance_data
    analyze_feature_coverage
    generate_recommendations
    generate_summary

    print_header "Analysis Complete"

    echo "📁 Test artifacts preserved at:"
    echo "   Models: $MODELS_DIR"
    echo "   Adapters: $ADAPTERS_DIR"
    echo "   Results: $RESULTS_DIR"
    echo
    echo "🔄 Run './analyze_test_results.sh' again to update analysis"
    echo "🧹 Run 'rm -rf test-models test-adapters test-results' to clean up"
}

# Run main function
main "$@"
