#!/bin/bash
# Environment variable validation script
# Validates all environment variables before container startup

set -e

# Colour codes for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

VALIDATION_ERRORS=0

# Print error message
error() {
  echo -e "${RED}ERROR: $1${NC}" >&2
  VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
}

# Print warning message
warn() {
  echo -e "${YELLOW}WARNING: $1${NC}" >&2
}

# Print info message
info() {
  echo -e "${GREEN}INFO: $1${NC}"
}

# Validate enum value
validate_enum() {
  local var_name="$1"
  local var_value="$2"
  shift 2
  local valid_values=("$@")

  if [ -z "$var_value" ]; then
    return 0  # Empty value is okay (will use default)
  fi

  for valid in "${valid_values[@]}"; do
    if [ "$var_value" == "$valid" ]; then
      return 0
    fi
  done

  error "$var_name has invalid value '$var_value'. Valid values: ${valid_values[*]}"
  return 1
}

# Validate boolean value
validate_boolean() {
  local var_name="$1"
  local var_value="$2"

  if [ -z "$var_value" ]; then
    return 0  # Empty value is okay (will use default)
  fi

  # Convert to lowercase for comparison
  local var_lower="${var_value,,}"

  if [ "$var_lower" != "true" ] && [ "$var_lower" != "false" ]; then
    error "$var_name must be 'true' or 'false' (case-insensitive), got '$var_value'"
    return 1
  fi

  return 0
}

# Validate numeric value with optional range
validate_numeric() {
  local var_name="$1"
  local var_value="$2"
  local min="${3:-}"
  local max="${4:-}"

  if [ -z "$var_value" ]; then
    return 0  # Empty value is okay (will use default)
  fi

  if ! [[ "$var_value" =~ ^[0-9]+$ ]]; then
    error "$var_name must be numeric, got '$var_value'"
    return 1
  fi

  if [ -n "$min" ] && [ "$var_value" -lt "$min" ]; then
    error "$var_name must be >= $min, got $var_value"
    return 1
  fi

  if [ -n "$max" ] && [ "$var_value" -gt "$max" ]; then
    error "$var_name must be <= $max, got $var_value"
    return 1
  fi

  return 0
}

# Validate LDAP URI format
validate_ldap_uri() {
  local var_name="$1"
  local var_value="$2"

  if [ -z "$var_value" ]; then
    return 0
  fi

  if ! [[ "$var_value" =~ ^ldaps?:// ]]; then
    error "$var_name must start with 'ldap://' or 'ldaps://', got '$var_value'"
    return 1
  fi

  return 0
}

# Validate DN format (basic check)
validate_dn() {
  local var_name="$1"
  local var_value="$2"

  if [ -z "$var_value" ]; then
    return 0
  fi

  if ! [[ "$var_value" =~ ^[a-zA-Z]+=.+ ]]; then
    error "$var_name doesn't look like a valid DN (should be like 'cn=user,dc=example,dc=com'), got '$var_value'"
    return 1
  fi

  return 0
}

# Validate hostname/FQDN
validate_hostname() {
  local var_name="$1"
  local var_value="$2"

  if [ -z "$var_value" ]; then
    return 0
  fi

  # Basic hostname validation (allows alphanumeric, dots, hyphens)
  # Must start with alphanumeric, can contain dots and hyphens, must end with alphanumeric
  if ! [[ "$var_value" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
    error "$var_name has invalid hostname format, got '$var_value'"
    return 1
  fi

  # Additional check: no consecutive dots, no hyphens at start/end of labels
  if [[ "$var_value" =~ \.\. ]] || [[ "$var_value" =~ \.- ]] || [[ "$var_value" =~ -\. ]]; then
    error "$var_name has invalid hostname format (consecutive dots or invalid hyphens), got '$var_value'"
    return 1
  fi

  return 0
}

# Validate network address format
validate_network() {
  local var_name="$1"
  local var_value="$2"

  if [ -z "$var_value" ]; then
    return 0
  fi

  # Should be "IP NETMASK" format like "10.50.50.0 255.255.255.0"
  if ! [[ "$var_value" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\ [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    error "$var_name must be in format 'IP NETMASK' (e.g., '10.50.50.0 255.255.255.0'), got '$var_value'"
    return 1
  fi

  return 0
}

# Sanitise string to prevent command injection
sanitise_string() {
  local var_name="$1"
  local var_value="$2"

  if [ -z "$var_value" ]; then
    return 0
  fi

  # Check for dangerous characters that could be used for injection
  if [[ "$var_value" =~ [\;\|\&\$\`] ]]; then
    error "$var_name contains potentially dangerous characters (;|&\$\`), got '$var_value'"
    return 1
  fi

  return 0
}

info "Starting environment variable validation..."

# ============================================================================
# REQUIRED VARIABLES
# ============================================================================

if [ "${USE_CLIENT_CERTIFICATE,,}" != "true" ]; then
  if [ -z "$OVPN_SERVER_CN" ]; then
    error "OVPN_SERVER_CN is required"
  else
    validate_hostname "OVPN_SERVER_CN" "$OVPN_SERVER_CN"
  fi

  if [ -z "$LDAP_URI" ]; then
    error "LDAP_URI is required when not using client certificates"
  fi

  if [ -z "$LDAP_BASE_DN" ]; then
    error "LDAP_BASE_DN is required when not using client certificates"
  fi
else
  if [ -z "$OVPN_SERVER_CN" ]; then
    error "OVPN_SERVER_CN is required"
  fi
fi

# ============================================================================
# MFA SETTINGS
# ============================================================================

validate_boolean "MFA_ENABLED" "$MFA_ENABLED"
validate_boolean "ENABLE_OTP" "$ENABLE_OTP"  # Backwards compat
validate_enum "MFA_BACKEND" "$MFA_BACKEND" "ldap" "file"
validate_enum "MFA_ENFORCEMENT_MODE" "$MFA_ENFORCEMENT_MODE" "strict" "graceful" "warn_only"
validate_numeric "MFA_GRACE_PERIOD_DAYS" "$MFA_GRACE_PERIOD_DAYS" 0 365

# Validate TOTP attribute name (should be alphanumeric)
if [ -n "$MFA_TOTP_ATTRIBUTE" ]; then
  if ! [[ "$MFA_TOTP_ATTRIBUTE" =~ ^[a-zA-Z][a-zA-Z0-9]*$ ]]; then
    error "MFA_TOTP_ATTRIBUTE must be alphanumeric starting with a letter, got '$MFA_TOTP_ATTRIBUTE'"
  fi
fi

# ============================================================================
# LDAP SETTINGS
# ============================================================================

validate_ldap_uri "LDAP_URI" "$LDAP_URI"
validate_dn "LDAP_BASE_DN" "$LDAP_BASE_DN"
validate_dn "LDAP_BIND_USER_DN" "$LDAP_BIND_USER_DN"

# Validate LDAP login attribute (should be alphanumeric)
if [ -n "$LDAP_LOGIN_ATTRIBUTE" ]; then
  if ! [[ "$LDAP_LOGIN_ATTRIBUTE" =~ ^[a-zA-Z][a-zA-Z0-9]*$ ]]; then
    error "LDAP_LOGIN_ATTRIBUTE must be alphanumeric starting with a letter, got '$LDAP_LOGIN_ATTRIBUTE'"
  fi
fi

validate_enum "LDAP_ENCRYPT_CONNECTION" "$LDAP_ENCRYPT_CONNECTION" "on" "starttls" "off"
validate_boolean "LDAP_TLS" "$LDAP_TLS"
validate_boolean "LDAP_TLS_VALIDATE_CERT" "$LDAP_TLS_VALIDATE_CERT"

# Warn if LDAP password is passed but might be visible in process list
if [ -n "$LDAP_BIND_USER_PASS" ]; then
  # This is actually okay for Docker env vars, just checking it's not empty
  sanitise_string "LDAP_BIND_USER_PASS" "$LDAP_BIND_USER_PASS"
fi

# ============================================================================
# OPENVPN SETTINGS
# ============================================================================

validate_numeric "OVPN_PORT" "$OVPN_PORT" 1 65535
validate_enum "OVPN_PROTOCOL" "$OVPN_PROTOCOL" "udp" "tcp"
validate_network "OVPN_NETWORK" "$OVPN_NETWORK"
validate_numeric "OVPN_VERBOSITY" "$OVPN_VERBOSITY" 0 11
validate_boolean "OVPN_NAT" "$OVPN_NAT"
validate_boolean "OVPN_ENABLE_COMPRESSION" "$OVPN_ENABLE_COMPRESSION"
validate_boolean "OVPN_DEFAULT_SERVER" "$OVPN_DEFAULT_SERVER"
validate_numeric "OVPN_IDLE_TIMEOUT" "$OVPN_IDLE_TIMEOUT" 0

# ============================================================================
# SECURITY SETTINGS
# ============================================================================

validate_numeric "KEY_LENGTH" "$KEY_LENGTH" 1024 8192
validate_boolean "REGENERATE_CERTS" "$REGENERATE_CERTS"
validate_boolean "USE_CLIENT_CERTIFICATE" "$USE_CLIENT_CERTIFICATE"

# Validate TLS cipher strings (basic check - just ensure no injection attempts)
if [ -n "$OVPN_TLS_CIPHERS" ]; then
  if [[ "$OVPN_TLS_CIPHERS" =~ [\;\|\&\$\`] ]]; then
    error "OVPN_TLS_CIPHERS contains invalid characters"
  fi
fi

if [ -n "$OVPN_TLS_CIPHERSUITES" ]; then
  if [[ "$OVPN_TLS_CIPHERSUITES" =~ [\;\|\&\$\`] ]]; then
    error "OVPN_TLS_CIPHERSUITES contains invalid characters"
  fi
fi

# ============================================================================
# FAIL2BAN SETTINGS
# ============================================================================

validate_boolean "FAIL2BAN_ENABLED" "$FAIL2BAN_ENABLED"
validate_numeric "FAIL2BAN_MAXRETRIES" "$FAIL2BAN_MAXRETRIES" 1 100

# ============================================================================
# MANAGEMENT INTERFACE
# ============================================================================

validate_boolean "OVPN_MANAGEMENT_ENABLE" "$OVPN_MANAGEMENT_ENABLE"
validate_boolean "OVPN_MANAGEMENT_NOAUTH" "$OVPN_MANAGEMENT_NOAUTH"

# ============================================================================
# OTHER SETTINGS
# ============================================================================

validate_boolean "DEBUG" "$DEBUG"
validate_boolean "LOG_TO_STDOUT" "$LOG_TO_STDOUT"
validate_boolean "ACTIVE_DIRECTORY_COMPAT_MODE" "$ACTIVE_DIRECTORY_COMPAT_MODE"

# ============================================================================
# SECURITY WARNINGS
# ============================================================================

# Warn about insecure configurations
if [ "${MFA_ENABLED,,}" != "true" ] && [ "${USE_CLIENT_CERTIFICATE,,}" != "true" ]; then
  warn "MFA is disabled - consider enabling MFA for production use"
fi

if [ "$LDAP_ENCRYPT_CONNECTION" == "off" ]; then
  warn "LDAP encryption is disabled - credentials will be sent in clear text"
fi

if [ "$LDAP_TLS_VALIDATE_CERT" == "false" ]; then
  warn "LDAP TLS certificate validation is disabled - vulnerable to MITM attacks"
fi

if [ "${OVPN_MANAGEMENT_NOAUTH,,}" == "true" ]; then
  warn "OpenVPN management interface has authentication disabled - security risk"
fi

# ============================================================================
# FINAL VALIDATION
# ============================================================================

if [ $VALIDATION_ERRORS -gt 0 ]; then
  error "Found $VALIDATION_ERRORS validation error(s). Container startup aborted."
  echo ""
  echo "Please fix the errors above and try again."
  exit 1
fi

info "Environment variable validation successful!"
exit 0
