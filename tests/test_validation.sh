#!/bin/bash
# Test script for environment variable validation
# This script tests the validate_env.sh script with various invalid inputs

set +e  # Don't exit on errors (we expect errors)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATION_SCRIPT="$SCRIPT_DIR/../files/configuration/validate_env.sh"
SET_DEFAULTS_SCRIPT="$SCRIPT_DIR/../files/configuration/set_defaults.sh"

# Colour codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

# Test helper function
test_validation() {
  local test_name="$1"
  local should_fail="$2"  # "fail" or "pass"

  echo -e "\n${YELLOW}TEST: $test_name${NC}"

  # Source set_defaults to get default values
  source "$SET_DEFAULTS_SCRIPT" 2>/dev/null

  # Run validation
  output=$("$VALIDATION_SCRIPT" 2>&1)
  exit_code=$?

  if [ "$should_fail" == "fail" ]; then
    if [ $exit_code -ne 0 ]; then
      echo -e "${GREEN}✓ PASS${NC} - Validation failed as expected"
      echo "$output" | grep "ERROR:"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      echo -e "${RED}✗ FAIL${NC} - Validation should have failed but passed"
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  else
    if [ $exit_code -eq 0 ]; then
      echo -e "${GREEN}✓ PASS${NC} - Validation passed as expected"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      echo -e "${RED}✗ FAIL${NC} - Validation should have passed but failed"
      echo "$output"
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  fi

  # Clean up environment
  unset $(env | grep -E '^(MFA_|LDAP_|OVPN_|ENABLE_)' | cut -d= -f1)
}

echo "========================================="
echo "Testing Environment Variable Validation"
echo "========================================="

# ============================================================================
# Valid configurations
# ============================================================================

export OVPN_SERVER_CN="vpn.example.com"
export LDAP_URI="ldap://ldap.example.com"
export LDAP_BASE_DN="dc=example,dc=com"
test_validation "Valid minimal configuration" "pass"

export OVPN_SERVER_CN="vpn.example.com"
export LDAP_URI="ldap://ldap.example.com"
export LDAP_BASE_DN="dc=example,dc=com"
export MFA_ENABLED="true"
export MFA_BACKEND="ldap"
test_validation "Valid MFA configuration" "pass"

# ============================================================================
# Invalid MFA_BACKEND
# ============================================================================

export OVPN_SERVER_CN="vpn.example.com"
export LDAP_URI="ldap://ldap.example.com"
export LDAP_BASE_DN="dc=example,dc=com"
export MFA_BACKEND="invalid"
test_validation "Invalid MFA_BACKEND value" "fail"

# ============================================================================
# Invalid MFA_ENABLED (not boolean)
# ============================================================================

export OVPN_SERVER_CN="vpn.example.com"
export LDAP_URI="ldap://ldap.example.com"
export LDAP_BASE_DN="dc=example,dc=com"
export MFA_ENABLED="yes"
test_validation "Invalid MFA_ENABLED value (not boolean)" "fail"

# ============================================================================
# Invalid LDAP_URI format
# ============================================================================

export OVPN_SERVER_CN="vpn.example.com"
export LDAP_URI="http://ldap.example.com"
export LDAP_BASE_DN="dc=example,dc=com"
test_validation "Invalid LDAP_URI protocol" "fail"

# ============================================================================
# Invalid LDAP_BASE_DN format
# ============================================================================

export OVPN_SERVER_CN="vpn.example.com"
export LDAP_URI="ldap://ldap.example.com"
export LDAP_BASE_DN="not-a-valid-dn"
test_validation "Invalid LDAP_BASE_DN format" "fail"

# ============================================================================
# Invalid port number
# ============================================================================

export OVPN_SERVER_CN="vpn.example.com"
export LDAP_URI="ldap://ldap.example.com"
export LDAP_BASE_DN="dc=example,dc=com"
export OVPN_PORT="99999"
test_validation "Invalid OVPN_PORT (too high)" "fail"

export OVPN_SERVER_CN="vpn.example.com"
export LDAP_URI="ldap://ldap.example.com"
export LDAP_BASE_DN="dc=example,dc=com"
export OVPN_PORT="abc"
test_validation "Invalid OVPN_PORT (not numeric)" "fail"

# ============================================================================
# Invalid protocol
# ============================================================================

export OVPN_SERVER_CN="vpn.example.com"
export LDAP_URI="ldap://ldap.example.com"
export LDAP_BASE_DN="dc=example,dc=com"
export OVPN_PROTOCOL="sctp"
test_validation "Invalid OVPN_PROTOCOL" "fail"

# ============================================================================
# Invalid MFA_ENFORCEMENT_MODE
# ============================================================================

export OVPN_SERVER_CN="vpn.example.com"
export LDAP_URI="ldap://ldap.example.com"
export LDAP_BASE_DN="dc=example,dc=com"
export MFA_ENFORCEMENT_MODE="lenient"
test_validation "Invalid MFA_ENFORCEMENT_MODE" "fail"

# ============================================================================
# Invalid LDAP_ENCRYPT_CONNECTION
# ============================================================================

export OVPN_SERVER_CN="vpn.example.com"
export LDAP_URI="ldap://ldap.example.com"
export LDAP_BASE_DN="dc=example,dc=com"
export LDAP_ENCRYPT_CONNECTION="tls"
test_validation "Invalid LDAP_ENCRYPT_CONNECTION" "fail"

# ============================================================================
# Command injection attempts
# ============================================================================

export OVPN_SERVER_CN="vpn.example.com"
export LDAP_URI="ldap://ldap.example.com"
export LDAP_BASE_DN="dc=example,dc=com"
export LDAP_BIND_USER_PASS="password;rm -rf /"
test_validation "Command injection in password" "fail"

export OVPN_SERVER_CN="vpn.example.com"
export LDAP_URI="ldap://ldap.example.com"
export LDAP_BASE_DN="dc=example,dc=com"
export MFA_TOTP_ATTRIBUTE="totpSecret\`whoami\`"
test_validation "Command injection in attribute name" "fail"

# ============================================================================
# Missing required variables
# ============================================================================

unset OVPN_SERVER_CN
export LDAP_URI="ldap://ldap.example.com"
export LDAP_BASE_DN="dc=example,dc=com"
test_validation "Missing OVPN_SERVER_CN" "fail"

export OVPN_SERVER_CN="vpn.example.com"
unset LDAP_URI
export LDAP_BASE_DN="dc=example,dc=com"
test_validation "Missing LDAP_URI" "fail"

# ============================================================================
# Valid with client certificate (LDAP not required)
# ============================================================================

export OVPN_SERVER_CN="vpn.example.com"
export USE_CLIENT_CERTIFICATE="true"
unset LDAP_URI
unset LDAP_BASE_DN
test_validation "Valid with USE_CLIENT_CERTIFICATE=true" "pass"

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
  exit 1
else
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
fi
