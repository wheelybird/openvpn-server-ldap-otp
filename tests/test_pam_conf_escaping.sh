#!/bin/bash
# Test that set_pam_conf writes values containing sed metacharacters literally (#94)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_OTP="$SCRIPT_DIR/../files/configuration/setup_otp.sh"
CONF_TEMPLATE="$SCRIPT_DIR/../files/etc/security/pam_ldap_totp_auth.conf"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

eval "$(sed -n '/^set_pam_conf()/,/^}/p' "$SETUP_OTP")"

PAM_CONF="$(mktemp)"
trap 'rm -f "$PAM_CONF"' EXIT

test_value() {
  local key="$1"
  local value="$2"

  cp "$CONF_TEMPLATE" "$PAM_CONF"
  set_pam_conf "$key" "$value"

  local actual
  actual="$(grep "^$key " "$PAM_CONF")"
  if [ "$actual" == "$key $value" ] && [ "$(grep -c "^$key\b" "$PAM_CONF")" == "1" ]; then
    echo -e "${GREEN}PASS${NC}: $key $value"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}FAIL${NC}: expected '$key $value', got '$actual'"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

test_value ldap_filter '(&(objectClass=person)(memberOf=cn=vpn,ou=groups,dc=example,dc=com))'
test_value ldap_filter '(|(memberOf=cn=a,dc=example,dc=com)(memberOf=cn=b,dc=example,dc=com))'
test_value ldap_bind_password 'p&ss|w\rd/with$odd"chars'
test_value ldap_uri 'ldaps://ldap.example.com:636'
test_value totp_prefix 'TOTP-SECRET:'
test_value debug 'true'

echo
echo "Passed: $TESTS_PASSED, failed: $TESTS_FAILED"
[ "$TESTS_FAILED" == "0" ]
