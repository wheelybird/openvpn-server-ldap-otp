# Changelog

## [2.0.1] - 2025-12-05

### Fixed

- Removed unnecessary certificate permission changes that caused errors when upgrading from v1.8 with existing `/etc/openvpn` volumes (issue #88)

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

For LDAP-backed TOTP, your LDAP schema must support the TOTP attribute.  See [ldap-totp-schema](https://github.com/wheelybird/ldap-totp-schema) for complete schema definitions.

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
