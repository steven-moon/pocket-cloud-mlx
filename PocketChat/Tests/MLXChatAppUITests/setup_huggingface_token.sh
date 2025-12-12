#!/bin/bash

# Secure HuggingFace Token Setup for MLX Chat App Tests
# This script securely stores your HuggingFace token for testing

set -e

echo "🔐 HuggingFace Token Setup for MLX Chat App Tests"
echo "=================================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN_FILE="$SCRIPT_DIR/../../../huggingface_token.txt"
BACKUP_DIR="$HOME/.mlx-engine-test-backups"

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

validate_token() {
    local token="$1"

    if [ -z "$token" ]; then
        print_error "Token cannot be empty"
        return 1
    fi

    if [ ${#token} -lt 20 ]; then
        print_error "Token appears to be too short (should be ~40 characters)"
        return 1
    fi

    # Test token with HuggingFace API
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $token" \
        "https://huggingface.co/api/whoami-v2" 2>/dev/null)

    if [ "$response" = "200" ]; then
        print_success "Token validated successfully!"
        return 0
    else
        print_error "Token validation failed (HTTP $response)"
        print_error "Please check your token and try again"
        return 1
    fi
}

backup_existing_token() {
    if [ -f "$TOKEN_FILE" ]; then
        print_step "Backing up existing token..."

        mkdir -p "$BACKUP_DIR"
        local backup_file="$BACKUP_DIR/huggingface_token_$(date +%Y%m%d_%H%M%S).txt"
        cp "$TOKEN_FILE" "$backup_file"
        chmod 600 "$backup_file"

        print_success "Existing token backed up to: $backup_file"
    fi
}

save_token_securely() {
    local token="$1"

    # Create backup if file exists
    backup_existing_token

    # Save new token
    echo "$token" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"

    print_success "Token saved securely to: $TOKEN_FILE"
    print_success "Permissions set to 600 (owner read/write only)"
}

create_token_from_input() {
    echo
    echo "Enter your HuggingFace token below:"
    echo "(You can get one from: https://huggingface.co/settings/tokens)"
    echo
    read -p "Token: " -r
    echo

    if [ -z "$REPLY" ]; then
        print_error "No token provided"
        return 1
    fi

    if validate_token "$REPLY"; then
        save_token_securely "$REPLY"
        return 0
    else
        return 1
    fi
}

create_token_from_file() {
    local source_file="$1"

    if [ ! -f "$source_file" ]; then
        print_error "Source file does not exist: $source_file"
        return 1
    fi

    local token
    token=$(cat "$source_file" | tr -d '\n\r' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

    if [ -z "$token" ]; then
        print_error "Source file is empty or contains only whitespace"
        return 1
    fi

    print_step "Validating token from file..."
    if validate_token "$token"; then
        save_token_securely "$token"
        return 0
    else
        return 1
    fi
}

display_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Securely set up HuggingFace token for MLX Chat App testing"
    echo
    echo "Options:"
    echo "  -f, --file FILE     Read token from file"
    echo "  -t, --token TOKEN   Provide token directly"
    echo "  -r, --remove        Remove stored token"
    echo "  -s, --show          Show token status (masked)"
    echo "  -h, --help          Show this help message"
    echo
    echo "Examples:"
    echo "  $0                    # Interactive token entry"
    echo "  $0 -f ~/hf_token.txt # Read from file"
    echo "  $0 -t hf_xxxxxxxx    # Direct token input"
    echo "  $0 -r                # Remove stored token"
}

remove_token() {
    if [ -f "$TOKEN_FILE" ]; then
        rm -f "$TOKEN_FILE"
        print_success "Token removed successfully"
    else
        print_warning "No token file found to remove"
    fi
}

show_token_status() {
    if [ -f "$TOKEN_FILE" ]; then
        local token_length
        token_length=$(wc -c < "$TOKEN_FILE")
        local masked_token="hf_$(printf '%*s' $((token_length - 3)) '' | tr ' ' '*')"

        echo "Token Status: ✅ Configured"
        echo "Token File: $TOKEN_FILE"
        echo "Masked Token: ${masked_token:0:20}..."
        echo "Permissions: $(stat -c '%a' "$TOKEN_FILE" 2>/dev/null || stat -f '%A' "$TOKEN_FILE" 2>/dev/null)"
    else
        echo "Token Status: ❌ Not configured"
        echo "Token File: $TOKEN_FILE (does not exist)"
    fi
}

main() {
    case "${1:-}" in
        -f|--file)
            if [ -z "$2" ]; then
                print_error "Please provide a file path"
                exit 1
            fi
            create_token_from_file "$2"
            ;;
        -t|--token)
            if [ -z "$2" ]; then
                print_error "Please provide a token"
                exit 1
            fi
            if validate_token "$2"; then
                save_token_securely "$2"
            else
                exit 1
            fi
            ;;
        -r|--remove)
            remove_token
            ;;
        -s|--show)
            show_token_status
            ;;
        -h|--help)
            display_usage
            ;;
        *)
            if [ $# -gt 0 ]; then
                print_error "Unknown option: $1"
                echo
                display_usage
                exit 1
            fi
            create_token_from_input
            ;;
    esac
}

# Run main function
main "$@"
