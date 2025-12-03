# OpenVPN LDAP+TOTP Integration Tests

This directory contains integration tests for the OpenVPN server with LDAP authentication and TOTP support.

## Overview

These tests verify that the `pam_ldap_totp_auth.so` module correctly handles various authentication scenarios:

1. **Password-only authentication** - Users without MFA configured
2. **Password + TOTP** - Users with TOTP secrets stored in LDAP
3. **Password + Scratch codes** - Backup authentication using one-time codes
4. **Legacy Google Authenticator** - File-based TOTP authentication

## Architecture

The test environment consists of two Docker containers:

- **ovpn-test-ldap** - OpenLDAP 1.5.0 server with custom TOTP schema
- **ovpn-test-server** - OpenVPN server with PAM authentication module

### Network Configuration

- LDAP: `ldap://openldap:389` (container network)
- LDAP (host): `ldap://localhost:11389`
- OpenVPN: UDP port `11194` (mapped to host)

### Test Data Location

All test data is stored in `/tmp/openvpn-test/` to keep the repository clean:
- `/tmp/openvpn-test/ldap-data` - LDAP database files
- `/tmp/openvpn-test/ldap-config` - LDAP configuration
- `/tmp/openvpn-test/openvpn-config` - OpenVPN configuration

## Directory Structure

```
tests/integration/
├── README.md                    # This file
├── docker-compose.yml           # Container orchestration
├── ldap-init/                   # LDAP initialization files
│   ├── 00-init.sh              # Initialization script
│   ├── 01-totp-schema.ldif     # TOTP LDAP schema
│   ├── 02-test-users.ldif      # Test user definitions
│   └── google_authenticator_file  # Google Authenticator config
└── test-scripts/                # Test scripts
    ├── test-password-only.sh    # Test #1: Password-only
    ├── test-password-totp.sh    # Test #2: Password + TOTP
    ├── test-password-scratch.sh # Test #3: Password + Scratch code
    ├── test-google-authenticator.sh  # Test #4: Google Auth legacy
    └── run-all-tests.sh         # Master test runner
```

## Test Users

All test users have the password: `test123`

### 1. passonly (Password-Only)
- **Username:** passonly
- **Password:** test123
- **MFA:** None
- **Purpose:** Test authentication without TOTP requirement

### 2. totpuser (Password + TOTP)
- **Username:** totpuser
- **Password:** test123
- **TOTP Secret:** JBSWY3DPEHPK3PXP (Base32)
- **Purpose:** Test LDAP-backed TOTP authentication in append mode

### 3. scratchuser (Password + Scratch Codes)
- **Username:** scratchuser
- **Password:** test123
- **TOTP Secret:** JBSWY3DPEHPK3PXP
- **Scratch Codes:** 12345678, 87654321, 99999999
- **Purpose:** Test backup code authentication

### 4. googleuser (Google Authenticator Legacy)
- **Username:** googleuser
- **Password:** test123
- **TOTP Secret:** JBSWY3DPEHPK3PXP (stored in ~/.google_authenticator)
- **Purpose:** Test file-based TOTP authentication (backward compatibility)

## Running Tests

### Prerequisites

- Docker and docker-compose installed
- At least 2GB free disk space
- Ports 11389 and 11194 available on host

### Quick Start

```bash
# Navigate to integration test directory
cd tests/integration

# Clean up any previous test data
rm -rf /tmp/openvpn-test

# Start test environment
docker compose up -d --build

# Wait for containers to be healthy
docker compose ps

# Initialize LDAP (schema and test users)
# Note: Schema must be loaded in LDAP container
docker exec ovpn-test-ldap ldapadd -Y EXTERNAL -H ldapi:/// -f /ldap-init/01-totp-schema.ldif

# Add test users and set passwords
docker exec ovpn-test-server bash -c 'cat << "EOF" | ldapadd -x -H ldap://openldap:389 -D "cn=admin,dc=test,dc=local" -w admin123
[... user LDIF content ...]
EOF'

# Run all tests
docker exec ovpn-test-server bash /test/run-all-tests.sh

# Run individual test
docker exec ovpn-test-server bash /test/test-password-totp.sh
```

### Cleanup

```bash
# Stop and remove containers
docker compose down

# Remove test data
rm -rf /tmp/openvpn-test
```

## Configuration

### PAM Module Configuration

Location: `/etc/security/pam_ldap_totp_auth.conf`

Key settings for test environment:
```conf
ldap_uri ldap://openldap:389
ldap_base dc=test,dc=local
ldap_bind_dn cn=admin,dc=test,dc=local
ldap_bind_password admin123
tls_mode none
totp_mode append
```

### PAM Service Configuration

Location: `/etc/pam.d/openvpn`

```
auth required pam_ldap_totp_auth.so
account required pam_permit.so
```

## Test Implementation Details

### Test 1: Password-Only Authentication

**File:** `test-password-only.sh`

**Tests:** User without MFA can authenticate with password alone

**Expected behavior:**
- PAM module validates password via LDAP bind
- No TOTP secret found for user
- Authentication succeeds (MFA optional)

**Command:**
```bash
echo "test123" | pamtester openvpn passonly authenticate
```

### Test 2: Password + TOTP Authentication

**File:** `test-password-totp.sh`

**Tests:** User with LDAP-stored TOTP secret authenticates with password+code

**Expected behavior:**
- Generate current TOTP code using oathtool
- Combine password and TOTP code (append mode)
- PAM module validates both via LDAP
- Authentication succeeds

**Command:**
```bash
TOTP_CODE=$(oathtool --totp --base32 JBSWY3DPEHPK3PXP)
echo "test123${TOTP_CODE}" | pamtester openvpn totpuser authenticate
```

### Test 3: Password + Scratch Code Authentication

**File:** `test-password-scratch.sh`

**Tests:** User can authenticate using backup scratch codes

**Expected behavior:**
- Combine password and 8-digit scratch code
- PAM module validates password and scratch code
- Scratch code is marked as used (single-use)
- Authentication succeeds

**Command:**
```bash
echo "test12312345678" | pamtester openvpn scratchuser authenticate
```

### Test 4: Google Authenticator Legacy

**File:** `test-google-authenticator.sh`

**Tests:** Backward compatibility with file-based google-authenticator

**Expected behavior:**
- Read TOTP secret from `~/.google_authenticator` file
- Generate and validate TOTP code
- Authentication succeeds using legacy PAM modules

**Note:** Uses separate PAM service config with `pam_google_authenticator.so`

## Troubleshooting

### LDAP Connection Issues

**Symptom:** "LDAP connection failed"

**Solution:**
1. Check LDAP container is healthy: `docker compose ps`
2. Test LDAP connection: `docker exec ovpn-test-server ldapsearch -x -H ldap://openldap:389 -D "cn=admin,dc=test,dc=local" -w admin123 -b "dc=test,dc=local"`
3. Ensure `tls_mode none` is set in PAM config

### Schema Loading Failures

**Symptom:** "objectClass: value #3 invalid per syntax"

**Solution:**
Schema must be loaded inside the LDAP container using `ldapi:///`:
```bash
docker exec ovpn-test-ldap ldapadd -Y EXTERNAL -H ldapi:/// -f /ldap-init/01-totp-schema.ldif
```

### TOTP Code Generation

**Symptom:** "Invalid TOTP code"

**Solution:**
1. Ensure system time is synchronized
2. Verify TOTP secret in LDAP: `ldapsearch ... totpSecret`
3. Test code generation: `oathtool --totp --base32 JBSWY3DPEHPK3PXP`
4. Check time window settings (default ±90 seconds)

### Debug Mode

Enable detailed logging:
```bash
docker exec ovpn-test-server bash -c 'sed -i "s/debug false/debug true/" /etc/security/pam_ldap_totp_auth.conf'
```

View logs:
```bash
docker exec ovpn-test-server tail -f /var/log/auth.log
```

## Known Issues

### Password-Only Authentication Failure

**Status:** Investigation needed

**Description:** Users without `totpUser` objectClass are failing authentication even though they have valid passwords. The PAM module reports "No TOTP secret found" and fails, but should allow password-only authentication when MFA is not configured.

**Debug output:**
```
[PAM_LDAP_TOTP] Password authentication successful for user 'passonly'
[PAM_LDAP_TOTP] No TOTP secret found for user 'passonly'
[PAM_LDAP_TOTP:DEBUG] Checking grace period status
pamtester: Authentication failure
```

**Expected behavior:** Users without totpUser objectClass should authenticate successfully with password alone.

**Workaround:** None currently. Requires PAM module code review.

## CI/CD Integration

These tests are designed to run in CI pipelines:

### GitHub Actions Example

```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run integration tests
        run: |
          cd tests/integration
          docker compose up -d --build
          docker exec ovpn-test-ldap ldapadd -Y EXTERNAL -H ldapi:/// -f /ldap-init/01-totp-schema.ldif
          # ... initialization steps ...
          docker exec ovpn-test-server bash /test/run-all-tests.sh

      - name: Cleanup
        if: always()
        run: |
          cd tests/integration
          docker compose down
          rm -rf /tmp/openvpn-test
```

## Development Notes

### Adding New Tests

1. Create test script in `test-scripts/`
2. Make it executable: `chmod +x test-scripts/new-test.sh`
3. Follow naming convention: `test-<feature>.sh`
4. Add to `run-all-tests.sh`
5. Document in this README

### Modifying Test Users

Edit `ldap-init/02-test-users.ldif` and reinitialize:
```bash
docker compose down -v
rm -rf /tmp/openvpn-test
docker compose up -d
# Re-run initialization
```

### Updating PAM Module

The PAM module is built from GitHub during Docker build:
```dockerfile
RUN git clone https://github.com/wheelybird/pam-ldap-totp-auth.git /tmp/pam-ldap-totp-auth && \
    cd /tmp/pam-ldap-totp-auth && \
    make && \
    install -D -m 0644 pam_ldap_totp_auth.so /lib/security/pam_ldap_totp_auth.so
```

To test local changes, modify the Dockerfile to COPY from local directory instead.

## References

- [PAM LDAP TOTP Auth Module](https://github.com/wheelybird/pam-ldap-totp-auth)
- [OpenLDAP Docker Image](https://github.com/osixia/docker-openldap)
- [RFC 6238 - TOTP](https://tools.ietf.org/html/rfc6238)
- [OpenVPN PAM Plugin](https://openvpn.net/community-resources/using-alternative-authentication-methods/)

## Support

For issues related to:
- **PAM module:** https://github.com/wheelybird/pam-ldap-totp-auth/issues
- **OpenVPN integration:** https://github.com/wheelybird/openvpn-server-ldap-otp/issues
- **Test suite:** Contact maintainer

## License

Same as parent project.
