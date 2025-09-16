#!/usr/bin/env bash

# Test script for OpenVPN installation script
# This script validates the functionality without performing actual installation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENVPN_SCRIPT="$SCRIPT_DIR/install-openvpn.sh"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Test logging function
test_log() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        "PASS")
            echo -e "${GREEN}[PASS]${NC} $message"
            ((TESTS_PASSED++))
            ;;
        "FAIL")
            echo -e "${RED}[FAIL]${NC} $message"
            ((TESTS_FAILED++))
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
    esac
    ((TESTS_TOTAL++))
}

# Test if script exists and is executable
test_script_exists() {
    test_log "INFO" "Testing script existence and permissions..."
    
    if [[ -f "$OPENVPN_SCRIPT" ]]; then
        test_log "PASS" "Script file exists: $OPENVPN_SCRIPT"
    else
        test_log "FAIL" "Script file not found: $OPENVPN_SCRIPT"
        return 1
    fi
    
    if [[ -x "$OPENVPN_SCRIPT" ]]; then
        test_log "PASS" "Script is executable"
    else
        test_log "FAIL" "Script is not executable"
        return 1
    fi
}

# Test help functionality
test_help_functionality() {
    test_log "INFO" "Testing help functionality..."
    
    if "$OPENVPN_SCRIPT" --help >/dev/null 2>&1; then
        test_log "PASS" "Help option works correctly"
    else
        test_log "FAIL" "Help option failed"
        return 1
    fi
    
    # Check if help output contains expected sections
    local help_output
    help_output=$("$OPENVPN_SCRIPT" --help 2>&1)
    
    if echo "$help_output" | grep -q "Usage:"; then
        test_log "PASS" "Help contains usage information"
    else
        test_log "FAIL" "Help missing usage information"
    fi
    
    if echo "$help_output" | grep -q "OPTIONS:"; then
        test_log "PASS" "Help contains options section"
    else
        test_log "FAIL" "Help missing options section"
    fi
    
    if echo "$help_output" | grep -q "EXAMPLES:"; then
        test_log "PASS" "Help contains examples section"
    else
        test_log "FAIL" "Help missing examples section"
    fi
}

# Test dry-run functionality
test_dry_run() {
    test_log "INFO" "Testing dry-run functionality..."
    
    # Capture dry-run output
    local dry_run_output
    if dry_run_output=$("$OPENVPN_SCRIPT" --dry-run 2>&1); then
        test_log "PASS" "Dry-run mode executes without errors"
    else
        test_log "FAIL" "Dry-run mode failed to execute"
        return 1
    fi
    
    # Check for dry-run markers in output
    if echo "$dry_run_output" | grep -q "\[DRY RUN\]"; then
        test_log "PASS" "Dry-run output contains proper markers"
    else
        test_log "FAIL" "Dry-run output missing markers"
    fi
    
    # Verify key steps are mentioned
    local expected_steps=(
        "Checking privileges"
        "Detecting operating system"
        "Checking internet connectivity"
        "Installing OpenVPN"
        "Creating OpenVPN directories"
        "Setting directory permissions"
    )
    
    for step in "${expected_steps[@]}"; do
        if echo "$dry_run_output" | grep -q "$step"; then
            test_log "PASS" "Dry-run includes step: $step"
        else
            test_log "FAIL" "Dry-run missing step: $step"
        fi
    done
}

# Test invalid arguments
test_invalid_arguments() {
    test_log "INFO" "Testing invalid argument handling..."
    
    # Test unknown option
    if "$OPENVPN_SCRIPT" --invalid-option >/dev/null 2>&1; then
        test_log "FAIL" "Script should reject invalid options"
    else
        test_log "PASS" "Script correctly rejects invalid options"
    fi
    
    # Test missing config file argument
    if "$OPENVPN_SCRIPT" --config >/dev/null 2>&1; then
        test_log "FAIL" "Script should require argument for --config"
    else
        test_log "PASS" "Script correctly requires argument for --config"
    fi
}

# Test script syntax
test_script_syntax() {
    test_log "INFO" "Testing script syntax..."
    
    if bash -n "$OPENVPN_SCRIPT"; then
        test_log "PASS" "Script syntax is valid"
    else
        test_log "FAIL" "Script has syntax errors"
        return 1
    fi
}

# Test verbose mode
test_verbose_mode() {
    test_log "INFO" "Testing verbose mode..."
    
    local verbose_output
    if verbose_output=$("$OPENVPN_SCRIPT" --dry-run --verbose 2>&1); then
        test_log "PASS" "Verbose mode executes successfully"
    else
        test_log "FAIL" "Verbose mode failed"
        return 1
    fi
    
    # Check for debug output
    if echo "$verbose_output" | grep -q "\[DEBUG\]"; then
        test_log "PASS" "Verbose mode produces debug output"
    else
        test_log "FAIL" "Verbose mode missing debug output"
    fi
}

# Test configuration file handling
test_config_file_handling() {
    test_log "INFO" "Testing configuration file handling..."
    
    # Create a temporary config file
    local temp_config="/tmp/test-openvpn-config.ovpn"
    echo "# Test OpenVPN configuration" > "$temp_config"
    
    # Test with valid config file
    local config_output
    if config_output=$("$OPENVPN_SCRIPT" --dry-run --config "$temp_config" 2>&1); then
        test_log "PASS" "Script accepts valid config file"
        
        if echo "$config_output" | grep -q "Processing custom configuration"; then
            test_log "PASS" "Script processes custom configuration"
        else
            test_log "FAIL" "Script doesn't process custom configuration"
        fi
    else
        test_log "FAIL" "Script rejects valid config file"
    fi
    
    # Test with non-existent config file
    if "$OPENVPN_SCRIPT" --dry-run --config "/nonexistent/file.ovpn" >/dev/null 2>&1; then
        test_log "FAIL" "Script should reject non-existent config file"
    else
        test_log "PASS" "Script correctly rejects non-existent config file"
    fi
    
    # Cleanup
    rm -f "$temp_config"
}

# Main test execution
main() {
    echo -e "${BLUE}=============================================="
    echo "     OpenVPN Installation Script Tests"
    echo "=============================================="
    echo -e "${NC}"
    
    # Run all tests
    test_script_exists || exit 1
    test_script_syntax || exit 1
    test_help_functionality
    test_dry_run
    test_verbose_mode
    test_invalid_arguments
    test_config_file_handling
    
    # Display results
    echo
    echo -e "${BLUE}=============================================="
    echo "               Test Results"
    echo -e "===============================================${NC}"
    echo -e "Total Tests: ${TESTS_TOTAL}"
    echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
    echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi