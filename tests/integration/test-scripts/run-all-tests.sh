#!/bin/bash
# Run all OpenVPN authentication tests
# This script runs inside the openvpn container

set -e

echo "========================================="
echo "OpenVPN Authentication Test Suite"
echo "========================================="
echo "Starting tests at $(date)"
echo ""

# Initialize LDAP if needed
if [ -f /ldap-init/00-init.sh ]; then
    echo "Running LDAP initialization..."
    bash /ldap-init/00-init.sh
    echo ""
fi

# Track test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
FAILED_TEST_NAMES=()

# Function to run a test
run_test() {
    local test_script="$1"
    local test_name=$(basename "$test_script" .sh)

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo ""
    echo "========================================="
    echo "Running: $test_name"
    echo "========================================="

    if bash "$test_script"; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        echo "✓ $test_name: PASSED"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("$test_name")
        echo "✗ $test_name: FAILED"
    fi
}

# Run all test scripts
TEST_DIR="/test"
if [ -d "$TEST_DIR" ]; then
    # Run tests in specific order
    run_test "$TEST_DIR/test-password-only.sh"
    run_test "$TEST_DIR/test-password-totp.sh"
    run_test "$TEST_DIR/test-password-scratch.sh"
    run_test "$TEST_DIR/test-google-authenticator.sh"
else
    echo "ERROR: Test directory $TEST_DIR not found"
    exit 1
fi

# Print summary
echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Total Tests:  $TOTAL_TESTS"
echo "Passed:       $PASSED_TESTS"
echo "Failed:       $FAILED_TESTS"
echo ""

if [ $FAILED_TESTS -gt 0 ]; then
    echo "Failed tests:"
    for test_name in "${FAILED_TEST_NAMES[@]}"; do
        echo "  - $test_name"
    done
    echo ""
    exit 1
else
    echo "All tests passed! ✓"
    echo ""
    exit 0
fi
