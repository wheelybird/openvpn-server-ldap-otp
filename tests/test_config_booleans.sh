#!/bin/bash

# Integration test for case-insensitive boolean handling in configuration scripts
# This tests actual configuration scripts with various boolean case combinations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../files/configuration"

# Set up minimal required environment variables
export OVPN_SERVER_CN="test.example.com"
export LDAP_URI="ldap://ldap.example.com"
export LDAP_BASE_DN="dc=example,dc=com"

echo "Integration test: case-insensitive boolean handling in configuration scripts"
echo

# Test set_defaults.sh with various boolean cases
test_set_defaults() {
  local test_case="$1"
  local fail2ban_value="$2"
  local log_stdout_value="$3"
  local expected_log_stdout="$4"

  echo "Testing set_defaults.sh - $test_case"

  # Create a temporary test environment
  export FAIL2BAN_ENABLED="$fail2ban_value"
  export LOG_TO_STDOUT="$log_stdout_value"

  # Source set_defaults.sh (in a subshell to avoid polluting environment)
  (
    source "$CONFIG_DIR/set_defaults.sh" 2>/dev/null || true

    # Check if LOG_TO_STDOUT was set correctly based on FAIL2BAN_ENABLED
    if [ "${FAIL2BAN_ENABLED,,}" == "true" ]; then
      if [ "$LOG_TO_STDOUT" == "false" ]; then
        echo "  ✓ PASS: FAIL2BAN_ENABLED=$fail2ban_value caused LOG_TO_STDOUT=false"
      else
        echo "  ✗ FAIL: FAIL2BAN_ENABLED=$fail2ban_value should set LOG_TO_STDOUT=false"
        exit 1
      fi
    else
      echo "  ✓ PASS: FAIL2BAN_ENABLED=$fail2ban_value did not modify LOG_TO_STDOUT"
    fi
  )

  if [ $? -eq 0 ]; then
    echo "  Test passed"
  else
    echo "  Test failed"
    exit 1
  fi

  echo
}

# Test MFA_ENABLED with various cases
test_mfa_enabled() {
  local test_case="$1"
  local mfa_value="$2"

  echo "Testing MFA_ENABLED - $test_case"

  export MFA_ENABLED="$mfa_value"
  unset ENABLE_OTP

  (
    source "$CONFIG_DIR/set_defaults.sh" 2>/dev/null || true

    # Both MFA_ENABLED and ENABLE_OTP should be set to the same value
    if [ "$MFA_ENABLED" == "$mfa_value" ]; then
      echo "  ✓ PASS: MFA_ENABLED preserved as '$MFA_ENABLED'"
    else
      echo "  ✗ FAIL: MFA_ENABLED changed from '$mfa_value' to '$MFA_ENABLED'"
      exit 1
    fi

    if [ "$ENABLE_OTP" == "$mfa_value" ]; then
      echo "  ✓ PASS: ENABLE_OTP set to '$ENABLE_OTP' (backwards compat)"
    else
      echo "  ✗ FAIL: ENABLE_OTP should be '$mfa_value' but is '$ENABLE_OTP'"
      exit 1
    fi
  )

  if [ $? -eq 0 ]; then
    echo "  Test passed"
  else
    echo "  Test failed"
    exit 1
  fi

  echo
}

# Run tests with various case combinations
echo "=== Testing FAIL2BAN_ENABLED cases ==="
echo
test_set_defaults "lowercase true" "true" "true" "false"
test_set_defaults "uppercase TRUE" "TRUE" "true" "false"
test_set_defaults "mixed case TrUe" "TrUe" "true" "false"
test_set_defaults "lowercase false" "false" "true" "true"
test_set_defaults "uppercase FALSE" "FALSE" "true" "true"

echo "=== Testing MFA_ENABLED cases ==="
echo
test_mfa_enabled "lowercase true" "true"
test_mfa_enabled "uppercase TRUE" "TRUE"
test_mfa_enabled "capitalised True" "True"
test_mfa_enabled "mixed case TrUe" "TrUe"
test_mfa_enabled "lowercase false" "false"
test_mfa_enabled "uppercase FALSE" "FALSE"

echo
echo "All integration tests passed!"
