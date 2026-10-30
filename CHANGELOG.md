# Changelog

## [2.2.0] - 2026-10-30

### Added

- `LDAP_LOGIN_ATTRIBUTE` accepts a comma-separated list, so users can log in with any of several attributes, e.g. `LDAP_LOGIN_ATTRIBUTE=uid,mail` to accept a username or an e-mail address ([pam-ldap-totp-auth#4](https://github.com/wheelybird/pam-ldap-totp-auth/issues/4)). A login that matches more than one entry is rejected when several attributes are listed.

### Changed

- Updated to pam-ldap-totp-auth v0.3.0

## [2.1.1] - 2026-10-30

### Fixed

- **[#94](https://github.com/wheelybird/openvpn-server-ldap-otp/issues/94)** - Configuration values containing `&` or `|` are no longer mangled when written to the PAM module's config. `setup_otp.sh` used `sed` substitutions, so an AND filter in `LDAP_FILTER` had the matched text inserted in place of `&` and an OR filter broke the `sed` command outright, failing every login. Every value `setup_otp.sh` writes to that file is now written literally, not only `LDAP_FILTER`.
- E-mail addresses can be used as usernames with `LDAP_LOGIN_ATTRIBUTE=mail` again, as they could in v1.8 ([pam-ldap-totp-auth#2](https://github.com/wheelybird/pam-ldap-totp-auth/issues/2)).

### Changed

- Updated to pam-ldap-totp-auth v0.2.1

## [2.1.0] - 2025-01-24

### Added

- **LDAP Filter Support**: New `LDAP_FILTER` environment variable for group-based and attribute-based access control
  - Restrict VPN access to specific LDAP groups using memberOf filters
  - Support for complex filters (OR, AND, NOT combinations)
  - Requires pam-ldap-totp-auth v0.2.0+
  - Fully backward compatible (empty filter = no restrictions)

### Changed

- Updated to pam-ldap-totp-auth v0.2.0
- Updated documentation with LDAP_FILTER examples and usage

### Example

```bash
# Restrict to vpn-users group
-e "LDAP_FILTER=(memberOf=cn=vpn-users,ou=groups,dc=example,dc=com)"

# Allow multiple groups
-e "LDAP_FILTER=(|(memberOf=cn=vpn-users,ou=groups,dc=example,dc=com)(memberOf=cn=admins,ou=groups,dc=example,dc=com))"
```

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
