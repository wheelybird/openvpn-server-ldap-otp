# Changelog

## [2.0.0] - 2025-11-29

### Added

 - LDAP-Backed TOTP/MFA Support
 - Environment variable validation
 - Various automated/integration test scripts

### Changed

 - nslcd and libpam-ldapd have been replaced with pam-ldap-totp-auth to support both LDAP password validation and LDAP TOTP validation
 - The base container has been updated to Ubuntu 24.04

### Migration Guide

#### Upgrading from 1.x

**No configuration changes required!** The new version is fully backwards compatible.

**Current configuration:**
```bash
ENABLE_OTP=true
# (file-based TOTP)
```

**After upgrade:**
```bash
# Option 1: No changes needed - works exactly the same
ENABLE_OTP=true

# Option 2: Use new variable name (recommended)
MFA_ENABLED=true
# MFA_BACKEND=file (default)

# Option 3: Switch to LDAP-backed TOTP (new feature)
MFA_ENABLED=true
MFA_BACKEND=ldap
MFA_TOTP_ATTRIBUTE=totpSecret
LDAP_URI=ldap://ldap.example.com
LDAP_BASE_DN=dc=example,dc=com
```

#### New Optional Features

**Enable LDAP-backed TOTP:**
```bash
MFA_ENABLED=true
MFA_BACKEND=ldap
LDAP_URI=ldap://ldap.example.com
LDAP_BASE_DN=dc=example,dc=com
# Optional: customize TOTP attribute
MFA_TOTP_ATTRIBUTE=totpSecret
```

**Configure enforcement mode:**
```bash
MFA_ENABLED=true
MFA_ENFORCEMENT_MODE=graceful  # or strict, warn_only
MFA_GRACE_PERIOD_DAYS=14       # days for new users to enroll
```

**Enable validation warnings:**
```bash
# Validation automatically runs on startup
# Check logs for security warnings about configuration
```

### Technical Details

#### LDAP Schema Requirements

For LDAP-backed TOTP, your LDAP schema must support the TOTP attribute:

```ldif
# Example LDAP schema
attributetype ( 1.3.6.1.4.1.54392.1.1.1
  NAME 'totpSecret'
  DESC 'TOTP shared secret (Base32 encoded)'
  EQUALITY caseExactMatch
  SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
  SINGLE-VALUE )

objectclass ( 1.3.6.1.4.1.54392.1.2.1
  NAME 'totpUser'
  DESC 'User with TOTP/MFA capability'
  AUXILIARY
  MAY ( totpSecret $ totpEnrolledDate $ totpStatus ) )
```

See [ldap-totp-schema](https://github.com/wheelybird/ldap-totp-schema) for complete schema definitions.

#### Authentication Flow

**Append mode (OpenVPN):**
1. User enters: `password` + `TOTP_CODE`
2. Example: password is `MySecurePass123`, TOTP code is `456789`
3. User inputs: `MySecurePass123456789`
4. PAM module splits password and TOTP code for validation

**File-based backend:**
- TOTP secrets stored in `/etc/openvpn/otp/<username>`
- Uses Google Authenticator format
- Requires volume mount for persistence

**LDAP backend:**
- TOTP secrets stored in LDAP user object
- Centralized management via web UI
- No local storage required
- Supports grace periods and enforcement modes

### Contributors

- wheelybird - Original project and LDAP integration
- Community contributors - Testing and feedback

### Links

- **GitHub**: https://github.com/wheelybird/openvpn-server-ldap-otp
- **Docker Hub**: https://hub.docker.com/r/wheelybird/openvpn-ldap-otp
- **Issues**: https://github.com/wheelybird/openvpn-server-ldap-otp/issues
- **Related Projects**:
  - [Luminary](https://github.com/wheelybird/luminary) - Web UI for LDAP/MFA management
  - [ldap-totp-schema](https://github.com/wheelybird/ldap-totp-schema) - LDAP schema for TOTP attributes

---

## [1.x.x] - Previous Releases

See Git history for changes in previous versions.

### Previous Features

- OpenVPN server with LDAP authentication
- File-based Google Authenticator TOTP support
- Client certificate authentication
- Fail2ban integration
- Flexible network configuration
- TLS 1.3 support
- Management interface
