# Test Deployment Guide

This directory contains scripts to deploy the complete LDAP + Luminary + OpenVPN stack for testing.

## Quick Start

```bash
# Set your server hostname (optional, defaults to localhost)
export LUMINARY_SERVER_HOSTNAME="vpn.example.com"

# Run the deployment script
./deploy-test.sh
```

## What Gets Deployed

1. **OpenLDAP** with STARTTLS support
   - TOTP/MFA schema auto-loaded via bootstrap (from ldap-totp-schema repo)
   - TOTP ACLs auto-configured during container initialization
   - Test organizational units (people, groups)
   - Sample admin group with MFA requirement
   - Test user account

2. **Luminary v2.0.0** (LDAP User Manager)
   - HTTPS with self-signed certificate
   - MFA/TOTP self-service enrollment
   - Unicode username support
   - All bug fixes from GitHub issues

3. **OpenVPN with LDAP+OTP**
   - TOTP authentication in append mode
   - Web auth portal for deferred authentication
   - Grace period support

## Accessing Services

| Service | URL/Port | Credentials |
|---------|----------|-------------|
| Luminary (HTTPS) | https://localhost:8443 | Create during first setup |
| Luminary (HTTP) | http://localhost:8080 | Same as above |
| OpenLDAP | ldap://localhost:389 | admin / admin_password_change_me |
| OpenVPN | udp://localhost:1194 | testuser / testpassword123 + TOTP |
| Web Auth Portal | https://localhost:8444 | Browser-based auth |

## Testing MFA Enrollment

1. **Initial Setup**
   ```bash
   # Visit Luminary
   open https://localhost:8443

   # Accept self-signed certificate warning
   # Create admin account on first visit
   ```

2. **Enable MFA for Test User**
   ```bash
   # Login as admin
   # Navigate to: Users > testuser
   # Note: testuser is in 'admins' group which requires MFA
   ```

3. **Self-Service MFA Enrollment**
   ```bash
   # Logout and login as testuser (password: testpassword123)
   # You'll see MFA required warning with grace period countdown
   # Click "Manage MFA" in navigation
   # Click "Set Up Multi-Factor Authentication"
   # Scan QR code with Google Authenticator or Authy
   # Enter first TOTP code
   # Wait 35+ seconds for time window to change
   # Enter second TOTP code
   # Save the 10 backup codes displayed
   # MFA is now active!
   ```

4. **Test VPN Authentication**
   ```bash
   # OpenVPN will prompt for username and password
   # Enter: testuser
   # Enter: testpassword123456 (password + current TOTP code)
   # Example: if password is "testpassword123" and code is "456789"
   #          enter "testpassword123456789"
   ```

## Username Format Testing

The deployment uses `{first_name_initial}{last_name}` format. Test with different names:

- **John Smith** → `jsmith`
- **Jean-Paul Dubois** → `jpauldubois` (hyphens removed)
- **José García** → `josegarcia` (with Unicode support)
- **Madonna** (mononym) → `madonna` (graceful handling)

## Troubleshooting

### View Logs
```bash
docker logs openldap
docker logs luminary
docker logs openvpn-test
```

### Restart Services
```bash
docker restart openldap luminary openvpn-test
```

### Test LDAP Connectivity
```bash
# Test STARTTLS connection
docker exec openldap ldapsearch -x -H ldap://localhost -ZZ \
  -D "cn=admin,dc=example,dc=com" -w admin_password_change_me \
  -b "dc=example,dc=com" "(objectClass=*)"
```

### Reset Everything
```bash
docker stop openldap luminary openvpn-test
docker rm openldap luminary openvpn-test
rm -rf data/
./deploy-test.sh
```

## Security Notes

⚠️ **For Testing Only** ⚠️

This deployment uses:
- Self-signed certificates
- Default passwords
- No firewall restrictions
- Allow TLS cert validation bypass

**DO NOT use these settings in production!**

For production deployment:
- Use proper CA-signed certificates
- Generate strong random passwords
- Configure firewall rules
- Enable strict TLS verification
- Use secrets management
- Enable audit logging

## Environment Variables

Customize the deployment by setting these before running the script:

```bash
# Server hostname (for certificate generation)
export LUMINARY_SERVER_HOSTNAME="vpn.yourdomain.com"

# To change defaults, edit the script variables:
LDAP_DOMAIN="example.com"
LDAP_BASE_DN="dc=example,dc=com"
LDAP_ADMIN_PASSWORD="your_secure_password"
LDAP_READONLY_USER_PASSWORD="another_secure_password"
```

## Architecture

```
┌─────────────────┐
│   Luminary      │  Port 8443 (HTTPS)
│   v2.0.0        │  Port 8080 (HTTP)
└────────┬────────┘
         │ STARTTLS
         ▼
┌─────────────────┐
│   OpenLDAP      │  Port 389 (LDAP)
│   with TOTP     │  Port 636 (LDAPS)
│   Schema        │
└────────┬────────┘
         │ Read-only user
         ▼
┌─────────────────┐
│   OpenVPN       │  Port 1194 (UDP)
│   + PAM TOTP    │  Port 8444 (Web Auth)
└─────────────────┘
```

**Schema Bootstrap Process:**

The TOTP schema is automatically loaded during OpenLDAP container initialization using osixia/openldap's bootstrap mechanism:

1. `deploy-test.sh` copies LDIF files from `ldap-totp-schema` repo to `data/ldif/`
2. ACLs are customized with the correct base DN using `sed`
3. Files are mounted into container at:
   - `/container/service/slapd/assets/config/bootstrap/schema/custom/totp-schema.ldif`
   - `/container/service/slapd/assets/config/bootstrap/ldif/custom/totp-acls.ldif`
4. On first start, the container automatically loads all files from these bootstrap directories
5. Schema and ACLs are persisted in the LDAP config database

## Files Created

```
data/
├── ldap/
│   ├── database/    # LDAP database files
│   └── config/      # LDAP configuration
├── ldif/
│   ├── totp-schema.ldif  # TOTP schema (auto-loaded on first start)
│   └── totp-acls.ldif    # TOTP ACLs (customized with base DN)
├── certs/
│   ├── luminary.crt # Self-signed certificate
│   └── luminary.key # Private key
└── openvpn/         # OpenVPN configuration
```

## Bug Fixes Included

This deployment includes fixes for:
- #215, #169 - User deletion cleanup
- #230 - Group creation GID issues
- #214 - JavaScript username generation
- #213, #171 - Mononym user support
- #186 - Multiple first names handling
- #234, #181, #167 - Unicode/umlaut support

Plus the complete MFA/TOTP implementation!

## Next Steps

After testing, you can:
1. Push the confirmed working images to Docker Hub
2. Update the main documentation
3. Create a GitHub release
4. Close the fixed GitHub issues
5. Announce the v2.0.0 release with MFA support
