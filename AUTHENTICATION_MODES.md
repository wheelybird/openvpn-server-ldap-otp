# OpenVPN Authentication Modes

This document explains the different authentication modes available for this OpenVPN container.

## LDAP Schema Requirement for LDAP-Backed TOTP

If you want to use **LDAP-backed TOTP** (mode 3 below), you must first install the LDAP TOTP schema in your LDAP directory:

**LDAP TOTP Schema:** https://github.com/wheelybird/ldap-totp-schema

This schema adds the necessary LDAP attributes (`totpSecret`, `totpStatus`, `totpScratchCode`, etc.) and object classes (`totpUser`, `mfaGroup`) for storing TOTP secrets and managing MFA policies in LDAP.

**Benefits of LDAP-backed TOTP:**
- Centralised TOTP secret management
- Self-service user enrolment via web interface (using [LDAP User Manager](https://github.com/wheelybird/ldap-user-manager))
- Group-based MFA policy enforcement
- Grace period management for new users
- Backup code storage in LDAP

---

## Authentication Mode Priority

The authentication mode is determined by environment variables in the following priority:

### 1. Certificate-Based Authentication (Highest Priority)
If `USE_CLIENT_CERTIFICATE=true`, no PAM authentication is used.
- **Environment Variable:** `USE_CLIENT_CERTIFICATE=true`
- **Authentication:** X.509 client certificates only
- **Use Case:** Traditional OpenVPN with per-client certificates

---

### 2. LDAP Password Only (No OTP)
If `ENABLE_OTP` is not set or `ENABLE_OTP=false`, only LDAP password authentication is used.
- **Environment Variables:**
  - `ENABLE_OTP=false` (or not set)
- **Authentication:** LDAP password only
- **PAM Configuration:** `/etc/pam.d/openvpn.without-otp`
- **PAM Modules:** `pam_ldap.so`
- **Use Case:** Simple LDAP authentication without MFA

---

### 3. LDAP-Backed TOTP (Recommended for MFA)
If `ENABLE_OTP=true` AND `TOTP_BACKEND=ldap`, TOTP secrets are stored in LDAP.
- **Environment Variables:**
  - `ENABLE_OTP=true`
  - `TOTP_BACKEND=ldap`
  - `LDAP_TOTP_ATTRIBUTE=totpSecret` (default)
- **Authentication:** LDAP password + LDAP-stored TOTP (append mode)
- **PAM Configuration:** `/etc/pam.d/openvpn.with-ldap-otp`
- **PAM Modules:** `pam_ldap_totp_auth.so` (standalone module)
- **PAM Module:** https://github.com/wheelybird/pam-ldap-totp-auth
- **Use Case:** Centralised MFA management in LDAP directory

**How it works:**
- Users concatenate password and OTP code: `mypassword123456`
- PAM module extracts last 6 digits as OTP
- Remaining characters validated as LDAP password
- TOTP secret retrieved from LDAP and validated
- Works with all OpenVPN clients (no special client support needed)

---

### 4. File-Based TOTP (Default When OTP Enabled)
If `ENABLE_OTP=true` but `TOTP_BACKEND=file` (or not set), file-based TOTP is used.
- **Environment Variables:**
  - `ENABLE_OTP=true`
  - `TOTP_BACKEND=file` (default)
- **Authentication:** LDAP password + file-based TOTP (append mode)
- **PAM Configuration:** `/etc/pam.d/openvpn.with-otp`
- **PAM Modules:** `pam_google_authenticator.so` + `pam_ldap.so`
- **TOTP Storage:** `/etc/openvpn/otp/<username>.google_authenticator`
- **Use Case:** Traditional google-authenticator setup, backwards compatibility

**How to set up:**
```bash
docker exec -ti openvpn add-otp-user <username>
```

---

## Configuration Selection Logic

```bash
if [ "${USE_CLIENT_CERTIFICATE}" == "true" ]; then
  # No PAM authentication
  echo "Using certificate-based authentication"
elif [ "$ENABLE_OTP" != "true" ]; then
  # LDAP password only
  echo "Using LDAP password authentication (no OTP)"
  cp -f /opt/pam.d/openvpn.without-otp /etc/pam.d/openvpn
elif [ "$TOTP_BACKEND" == "ldap" ]; then
  # LDAP-backed TOTP
  echo "Using LDAP password + LDAP-backed OTP"
  cp -f /opt/pam.d/openvpn.with-ldap-otp /etc/pam.d/openvpn
else
  # File-based TOTP (default when OTP enabled)
  echo "Using LDAP password + file-based OTP (google-authenticator)"
  cp -f /opt/pam.d/openvpn.with-otp /etc/pam.d/openvpn
fi
```

## Quick Start Examples

### Example 1: LDAP Password Only (No MFA)
```bash
docker run \
  -e "OVPN_SERVER_CN=vpn.example.com" \
  -e "LDAP_URI=ldap://ldap.example.com:389" \
  -e "LDAP_BASE_DN=dc=example,dc=com" \
  -e "LDAP_BIND_USER_DN=cn=binduser,dc=example,dc=com" \
  -e "LDAP_BIND_USER_PASS=password" \
  --volume /path/to/openvpn_data:/etc/openvpn \
  -p 1194:1194/udp \
  --cap-add=NET_ADMIN \
  ghcr.io/wheelybird/openvpn-server-ldap-otp:latest
```
- No OTP/MFA
- LDAP password authentication only
- Not recommended for production

### Example 2: File-Based TOTP (Default OTP Mode)
```bash
docker run \
  -e "OVPN_SERVER_CN=vpn.example.com" \
  -e "ENABLE_OTP=true" \
  -e "LDAP_URI=ldap://ldap.example.com:389" \
  -e "LDAP_BASE_DN=dc=example,dc=com" \
  -e "LDAP_BIND_USER_DN=cn=binduser,dc=example,dc=com" \
  -e "LDAP_BIND_USER_PASS=password" \
  --volume /path/to/openvpn_data:/etc/openvpn \
  -p 1194:1194/udp \
  --cap-add=NET_ADMIN \
  ghcr.io/wheelybird/openvpn-server-ldap-otp:latest
```
- Users need `.google_authenticator` files in `/etc/openvpn/otp/`
- Standard google-authenticator setup
- Set up users: `docker exec -ti openvpn add-otp-user username`

### Example 3: LDAP-Backed TOTP (Recommended)
```bash
docker run \
  -e "OVPN_SERVER_CN=vpn.example.com" \
  -e "ENABLE_OTP=true" \
  -e "TOTP_BACKEND=ldap" \
  -e "LDAP_URI=ldap://ldap.example.com:389" \
  -e "LDAP_BASE_DN=dc=example,dc=com" \
  -e "LDAP_BIND_USER_DN=cn=binduser,dc=example,dc=com" \
  -e "LDAP_BIND_USER_PASS=password" \
  -e "LDAP_TOTP_ATTRIBUTE=totpSecret" \
  --volume /path/to/openvpn_data:/etc/openvpn \
  -p 1194:1194/udp \
  --cap-add=NET_ADMIN \
  ghcr.io/wheelybird/openvpn-server-ldap-otp:latest
```
- TOTP secrets stored in LDAP `totpSecret` attribute
- Users enter password+OTP concatenated (e.g., `mypassword123456`)
- Requires LDAP TOTP schema: https://github.com/wheelybird/ldap-totp-schema
- Manage users via LDAP User Manager: https://github.com/wheelybird/ldap-user-manager

### Example 4: Client Certificate Only
```bash
docker run \
  -e "OVPN_SERVER_CN=vpn.example.com" \
  -e "USE_CLIENT_CERTIFICATE=true" \
  --volume /path/to/openvpn_data:/etc/openvpn \
  -p 1194:1194/udp \
  --cap-add=NET_ADMIN \
  ghcr.io/wheelybird/openvpn-server-ldap-otp:latest
```
- X.509 certificate authentication only
- No LDAP or OTP required
- Suitable for development/testing

## Advanced Configuration

### PAM Module Configuration

When using LDAP-backed TOTP (`TOTP_BACKEND=ldap`), the PAM module can be configured via `/etc/security/pam_ldap_totp_auth.conf`:

```ini
# TOTP mode (only append mode supported in OpenVPN)
totp_mode append

# LDAP attribute containing TOTP secret
totp_attribute totpSecret

# TOTP validation parameters
time_step 30
window_size 3
digits 6

# Grace period for new users (days)
grace_period_days 7

# Enforcement mode
enforcement_mode graceful

# Debug logging
debug false
```

See the [PAM module documentation](https://github.com/wheelybird/pam-ldap-totp-auth) for all configuration options.

### Environment Variables for LDAP-Backed TOTP

| Variable | Default | Description |
|----------|---------|-------------|
| `TOTP_BACKEND` | file | TOTP storage backend: `ldap` or `file` |
| `LDAP_TOTP_ATTRIBUTE` | totpSecret | LDAP attribute for TOTP secret |
| `TOTP_MODE` | append | Always `append` for OpenVPN |
| `TOTP_WINDOW` | 3 | Time window tolerance (±steps) |
| `TOTP_GRACE_PERIOD_DAYS` | 7 | Grace period for new users |

## Related Projects

This OpenVPN container integrates with several related projects for complete LDAP-backed MFA:

- **[LDAP TOTP Schema](https://github.com/wheelybird/ldap-totp-schema)** - LDAP schema for TOTP attributes
- **[LDAP TOTP PAM](https://github.com/wheelybird/pam-ldap-totp-auth)** - PAM module for LDAP-backed TOTP (built from source)
- **[LDAP User Manager](https://github.com/wheelybird/ldap-user-manager)** - Web UI for self-service MFA enrolment

## Related Files

- **PAM Configurations:** `files/etc/pam.d/`
  - `openvpn.without-otp` - LDAP only
  - `openvpn.with-otp` - LDAP + google-authenticator
  - `openvpn.with-ldap-otp` - LDAP + pam_ldap_totp_auth (standalone module)

- **Setup Script:** `files/configuration/setup_otp.sh`
  - Contains the logic for selecting PAM configuration

- **PAM Module Config:** `/etc/security/pam_ldap_totp_auth.conf`
  - Configuration for pam_ldap_totp_auth.so module
  - Controls TOTP parameters, grace period, etc.
