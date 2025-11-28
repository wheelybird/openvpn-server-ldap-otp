# OpenVPN server with LDAP authentication and MFA

A Docker container providing OpenVPN with LDAP authentication and optional two-factor authentication (TOTP/MFA). Part of an integrated suite of tools for enterprise-grade VPN access with centralised user management.

## Why use this?

### Why use this

The goal of this project is to build a Docker container that provides an [OpenVPN](https://openvpn.net) server which authenticates users against an existing [OpenLDAP](https://www.openldap.org) directory, with optional two-factor authentication using TOTP (via liboath).   

[OpenVPN](https://openvpn.net) is a mature, free, and open-source VPN solution known for its strong security, flexibility, and active development since 2001. It supports a wide range of operating systems through well-maintained client applications.   

[OpenLDAP](https://www.openldap.org) is a robust open-source implementation of the Lightweight Directory Access Protocol (LDAP), widely used for centralised authentication, authorisation, and user information management. It provides a flexible, standards-based system for managing directory data across diverse environments.   

This project extends that functionality by allowing OpenVPN to verify users’ TOTP keys and related metadata directly from OpenLDAP. Managing these credentials within the same directory simplifies administration, ensures consistent access control, and improves security by keeping all authentication data in a single, authoritative source.

- **Centralised authentication**: Use your existing LDAP directory for VPN access
- **Optional MFA/2FA**: Add time-based one-time passwords (TOTP) for enhanced security
- **Enterprise ready**: Supports fail2ban, custom routing, and advanced networking
- **Docker-native**: Easy deployment with persistent configuration

## Complete solution stack

This OpenVPN server works best as part of an integrated solution:

| Component | Purpose | Repository |
|-----------|---------|------------|
| **OpenVPN server** (this project) | VPN gateway with LDAP + MFA authentication | [openvpn-server-ldap-otp](https://github.com/wheelybird/openvpn-server-ldap-otp) |
| **Luminary** | A web UI for self-service MFA enrolment | [luminary](https://github.com/wheelybird/luminary) |

**Benefits of the complete stack:**
- Users can scan QR codes and set up MFA themselves
- Admins can enforce MFA by group membership
- Grace periods allow users time to enrol before VPN access is restricted
- No need to SSH into servers to manage OTP secrets

## Quick start

### Basic setup (LDAP authentication only)

```bash
docker run \
  --name openvpn \
  --cap-add=NET_ADMIN \
  -p 1194:1194/udp \
  -v /path/to/data:/etc/openvpn \
  -e "OVPN_SERVER_CN=vpn.example.com" \
  -e "LDAP_URI=ldap://ldap.example.com" \
  -e "LDAP_BASE_DN=dc=example,dc=com" \
  -e "LDAP_BIND_USER_DN=cn=pam-totp-ldap-auth,ou=services,dc=example,dc=com" \
  -e "LDAP_BIND_USER_PASS=password" \
  -d \
  wheelybird/openvpn-ldap-otp:v2.0.0
```

**NOTE:** LDAP_BIND_USER should be the DN for an LDAP account that can access the user's LDAP attributes.  If you don't have a specific service account set up for this then you can use the administrator base DN, but this isn't recommended.  The example uses the example service account from the [LDAP TOTP schema](https://github.com/wheelybird/ldap-totp-schema) repository. 

### With MFA (recommended)

First, install the [LDAP TOTP schema](https://github.com/wheelybird/ldap-totp-schema) in your LDAP directory, then:

```bash
docker run \
  --name openvpn \
  --cap-add=NET_ADMIN \
  -p 1194:1194/udp \
  -v /path/to/data:/etc/openvpn \
  -e "OVPN_SERVER_CN=vpn.example.com" \
  -e "LDAP_URI=ldap://ldap.example.com" \
  -e "LDAP_BASE_DN=dc=example,dc=com" \
  -e "LDAP_BIND_USER_DN=cn=pam-totp-ldap-auth,ou=services,dc=example,dc=com" \
  -e "LDAP_BIND_USER_PASS=your_service_account_password" \
  -e "ENABLE_OTP=true" \
  -e "TOTP_BACKEND=ldap" \
  -d \
  wheelybird/openvpn-ldap-otp:v2.0.0
```

Deploy [Luminary](https://github.com/wheelybird/luminary) to give users a friendly web interface for MFA enrolment.

### Get client configuration

```bash
docker exec -ti openvpn show-client-config > client.ovpn
```

Distribute this `.ovpn` file to your users. When connecting with MFA enabled, users enter: `password123456` (password + 6-digit TOTP code concatenated).

## Authentication modes

**NOTE:** This container uses the (`pam_ldap_totp_auth`) PAM module for LDAP and TOTP authentication. The module can operate in three modes controlled by environment variables.

### 1. LDAP-backed TOTP (recommended)
Store TOTP secrets in LDAP for centralised management.

**Prerequisites:**
1. Install [LDAP TOTP Schema](https://github.com/wheelybird/ldap-totp-schema) in your LDAP directory
2. Optionally deploy [Luminary](https://github.com/wheelybird/luminary) for self-service

**Configuration:**
```bash
-e "ENABLE_OTP=true"
-e "TOTP_BACKEND=ldap"
```

**NOTE:** you can configure which LDAP attributes store TOTP data, so if you're unable to install the suggested schema it'll still be possible to store the data in LDAP (but not recommended).

**User experience:**
- Users enrol via web UI (scan QR code with authenticator app)
- Users enter `password123456` when connecting to VPN
- Backup codes available for emergency access

**Benefits:**
- Self-service enrolment via web interface
- Admin oversight of MFA adoption
- Group-based MFA requirements
- Grace periods for new users
- Backup codes stored in LDAP
- Standalone PAM module with direct LDAP integration

See [AUTHENTICATION_MODES.md](AUTHENTICATION_MODES.md) for detailed information.

---

### 2. File-based TOTP (traditional)

Uses google-authenticator with file-based secret storage. The `pam_ldap_totp_auth` module handles LDAP password authentication (set `totp_enabled=false`).

**Configuration:**
```bash
-e "ENABLE_OTP=true"
# TOTP_BACKEND defaults to 'file' if not set
```

**Setup:** `docker exec -ti openvpn add-otp-user username`

**User experience:** Users enter `password123456` (password + TOTP code).

**How it works:**
- `pam_google_authenticator` validates the TOTP code from file
- `pam_ldap_totp_auth` (with TOTP disabled) validates LDAP password
- Both must succeed

---

### 3. LDAP password only (No MFA)

Simple LDAP password authentication without two-factor. Uses the `pam_ldap_totp_auth` module with `totp_enabled=false`.

**Configuration:**
```bash
-e "LDAP_URI=ldap://ldap.example.com"
-e "LDAP_BASE_DN=dc=example,dc=com"
# Do NOT set ENABLE_OTP=true
```

**Note:** Not recommended for production. Enable MFA for security.

---

### 4. Client certificate authentication

Traditional X.509 certificate-based authentication (no LDAP required).

**Configuration:**
```bash
-e "USE_CLIENT_CERTIFICATE=true"
```

**User experience:** Users connect with certificate, no password needed.

**Use case:** Development, testing, or traditional certificate-based deployments.

## Configuration

### Required settings

| Variable | Description | Example |
|----------|-------------|---------|
| `OVPN_SERVER_CN` | Server hostname (must be resolvable by clients) | `vpn.example.com` |

### LDAP settings

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `LDAP_URI` | Yes* | LDAP server URI | `ldap://ldap.example.com` or `ldaps://ldap.example.com:636` |
| `LDAP_BASE_DN` | Yes* | Base DN for user searches | `dc=example,dc=com` |
| `LDAP_BIND_USER_DN` | Recommended | DN for bind user (if anonymous bind disabled) | `cn=readonly,dc=example,dc=com` |
| `LDAP_BIND_USER_PASS` | Recommended | Password for bind user | `supersecret` |
| `LDAP_FILTER` | No | Additional LDAP filter | `(memberOf=cn=vpn-users,ou=groups,dc=example,dc=com)` |
| `LDAP_LOGIN_ATTRIBUTE` | No | Attribute to match username (default: `uid`) | `sAMAccountName` for AD |
| `LDAP_ENCRYPT_CONNECTION` | No | TLS mode: `on`, `starttls`, or `off` | `starttls` |
| `LDAP_TLS_VALIDATE_CERT` | No | Validate TLS certificate (default: `true`) | `false` for self-signed |
| `LDAP_TLS_CA_CERT` | No | CA certificate contents for TLS | Contents of CA cert file |

*Not required if `USE_CLIENT_CERTIFICATE=true`

**Active Directory users:** Set `-e "ACTIVE_DIRECTORY_COMPAT_MODE=true"` to automatically configure appropriate settings.

### MFA/TOTP settings

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_OTP` | `false` | Enable two-factor authentication |
| `TOTP_BACKEND` | `file` | TOTP storage backend: `ldap` or `file` |
| `LDAP_TOTP_ATTRIBUTE` | `totpSecret` | LDAP attribute storing TOTP secret (LDAP backend only) |
| `TOTP_MODE` | `append` | Authentication mode (`append` only for OpenVPN) |
| `MFA_GRACE_PERIOD_DAYS` | `7` | Days before enforcing MFA for new users |
| `MFA_ENFORCEMENT_MODE` | `graceful` | Enforcement: `strict`, `graceful`, `warn_only` |

### Network Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `OVPN_PORT` | `1194` | OpenVPN listen port (update Docker `-p` to match) |
| `OVPN_PROTOCOL` | `udp` | Protocol: `udp` or `tcp` |
| `OVPN_NETWORK` | `10.50.50.0 255.255.255.0` | VPN network address and netmask |
| `OVPN_ROUTES` | All traffic | Routes to push to clients (format: `192.168.1.0 255.255.255.0,10.0.0.0 255.255.0.0`) |
| `OVPN_NAT` | `true` | Enable NAT/masquerading for client traffic |
| `OVPN_DNS_SERVERS` | None | DNS servers to push (comma-separated) |
| `OVPN_DNS_SEARCH_DOMAIN` | None | DNS search domains (comma-separated) |

### Security settings

| Variable | Default | Description |
|----------|---------|-------------|
| `KEY_LENGTH` | `2048` | Certificate key length (higher = more secure, slower) |
| `OVPN_TLS_CIPHERS` | Modern ciphers | TLS 1.2 cipher list |
| `OVPN_TLS_CIPHERSUITES` | Modern suites | TLS 1.3 cipher suites |
| `OVPN_IDLE_TIMEOUT` | None | Disconnect idle connections (seconds) |
| `REGENERATE_CERTS` | `false` | Force certificate regeneration |

### Fail2ban protection

| Variable | Default | Description |
|----------|---------|-------------|
| `FAIL2BAN_ENABLED` | `false` | Enable brute-force protection |
| `FAIL2BAN_MAXRETRIES` | `3` | Failed attempts before ban |

### Management interface

| Variable | Default | Description |
|----------|---------|-------------|
| `OVPN_MANAGEMENT_ENABLE` | `false` | Enable TCP management interface on port 5555 |
| `OVPN_MANAGEMENT_NOAUTH` | `false` | Allow access without authentication |
| `OVPN_MANAGEMENT_PASSWORD` | None | Management interface password |

### Advanced settings

| Variable | Default | Description |
|----------|---------|-------------|
| `OVPN_DEFAULT_SERVER` | `true` | Auto-generate server network config |
| `OVPN_EXTRA` | None | Additional OpenVPN config directives (raw text) |
| `OVPN_VERBOSITY` | `4` | Log verbosity (0-11) |
| `DEBUG` | `false` | Enable debug logging |
| `LOG_TO_STDOUT` | `true` | Send OpenVPN logs to stdout |

**Note:** You can add any extra server configuration for OpenVPN using `OVPN_EXTRA`.  This should be a string with escaped newlines and quotes.  For example: `OVPN_EXTRA="sndbuf 393216\nrcvbuf 393216\ntxqueuelen 1000"`

## Data persistence

Mount `/etc/openvpn` as a volume to persist:
- Generated certificates and keys
- Server configuration
- OTP secrets (if using file-based mode)
- Client configuration

```bash
-v /path/on/host:/etc/openvpn
```

**Important:** The first run generates certificates (2048-bit key takes 2-10 minutes). Subsequent starts are much faster.

## Security best practices

### TLS/SSL for LDAP
```bash
-e "LDAP_ENCRYPT_CONNECTION=starttls"
-e "LDAP_TLS_VALIDATE_CERT=true"
-e "LDAP_TLS_CA_CERT=$(cat /path/to/ca.crt)"
```

### Enable MFA
```bash
-e "ENABLE_OTP=true"
-e "TOTP_BACKEND=ldap"
```

Deploy [Luminary](https://github.com/wheelybird/luminary) for self-service enrolment.

### Restrict VPN access by LDAP group
```bash
-e "LDAP_FILTER=(memberOf=cn=vpn-users,ou=groups,dc=example,dc=com)"
```

### Enable Fail2ban
```bash
-e "FAIL2BAN_ENABLED=true"
-e "FAIL2BAN_MAXRETRIES=3"
```

### Session timeouts
```bash
-e "OVPN_IDLE_TIMEOUT=3600"  # 1 hour
```

## Common tasks

### View client configuration
```bash
docker exec -ti openvpn show-client-config
```

### Add file-based OTP user
```bash
docker exec -ti openvpn add-otp-user username
```

### Check container logs
```bash
docker logs -f openvpn
```

### Fail2ban administration
```bash
# Ban an IP
docker exec -ti openvpn fail2ban-client set openvpn banip 192.168.1.100

# Unban an IP
docker exec -ti openvpn fail2ban-client set openvpn unbanip 192.168.1.100

# View fail2ban logs
docker exec -ti openvpn tail -50 /var/log/fail2ban.log
```

### Force certificate regeneration
```bash
docker run ... -e "REGENERATE_CERTS=true" ...
```
**Note:** After regenerating the certificates you'll need to provide users with the new client configuration.

## Troubleshooting

### Container hangs at "Generating DH parameters"

**Cause:** Low system entropy (common on VMs).

**Solution:**
```bash
# Install entropy daemon on Docker host
apt-get install haveged
systemctl enable haveged
systemctl start haveged

# Check available entropy (should be >1000)
cat /proc/sys/kernel/random/entropy_avail
```

Alternatively, wait longer (can take 30+ minutes on low-entropy systems) or use a lower key length (not recommended for production):
```bash
-e "KEY_LENGTH=2048"
```

### LDAP authentication fails

**Check LDAP connectivity:**
```bash
docker exec -ti openvpn ldapsearch -x -H "${LDAP_URI}" -b "${LDAP_BASE_DN}" -D "${LDAP_BIND_USER_DN}" -w "${LDAP_BIND_USER_PASS}"
```

**Common issues:**
- Bind user lacks search permissions
- LDAP filter too restrictive
- TLS certificate validation failing (try `LDAP_TLS_VALIDATE_CERT=false` temporarily)
- Wrong base DN or bind credentials

### MFA/OTP not working

**File-based TOTP:**
- Check OTP file exists: `docker exec -ti openvpn ls /etc/openvpn/otp/`
- Ensure time synchronization with NTP

**LDAP-backed TOTP:**
- Verify LDAP schema installed: [ldap-totp-schema](https://github.com/wheelybird/ldap-totp-schema)
- Check user has `totpSecret` attribute populated
- Verify PAM module config: `docker exec -ti openvpn cat /etc/security/pam_ldap_totp_auth.conf`
- Enable debug: `-e "DEBUG=true"`

**Time synchronisation critical for TOTP:**
```bash
# Check time on the host
date
```

Install NTP/chrony on the host.

### Clients can't reach internal networks

**Issue:** VPN connects but can't access internal resources.

**Solutions:**

1. **Enable NAT** (easiest):
   ```bash
   -e "OVPN_NAT=true"
   ```

2. **Add return routes** on internal gateways pointing the VPN network (e.g. `10.50.50.0/24`) to the OpenVPN server IP

3. **Check routing**:
   ```bash
   docker exec -ti openvpn ip route
   docker exec -ti openvpn iptables -t nat -L -n -v
   ```

## Documentation

- **[AUTHENTICATION_MODES.md](AUTHENTICATION_MODES.md)** - Detailed authentication mode documentation
- **[LDAP TOTP Schema](https://github.com/wheelybird/ldap-totp-schema)** - Schema installation guide
- **[Luminary](https://github.com/wheelybird/luminary)** - The Luminary LDAP account manager with self-service password/MFA support
- **[LDAP TOTP PAM Module](https://github.com/wheelybird/pam-ldap-totp-auth)** - PAM module documentation

## Support

- **Issues:** https://github.com/wheelybird/openvpn-server-ldap-otp/issues
- **Pull Requests:** Welcome!

## Licence

See LICENCE file for details.

## Credits

Built on top of:
- [OpenVPN](https://openvpn.net/)
- [OATH toolkit](https://www.nongnu.org/oath-toolkit/) - TOTP validation
- [OpenLDAP libraries](https://www.openldap.org/) - LDAP connectivity
- [Easy-RSA](https://github.com/OpenVPN/easy-rsa/) - Certificate management

Custom components:
| Component | Purpose | Repository |
| [LDAP TOTP schema](https://github.com/wheelybird/ldap-totp-schema) - An LDAP schema that allows the storage of MFA/TOTP keys and metadata in LDAP
- [LDAP TOTP PAM module](https://github.com/wheelybird/pam-ldap-totp-auth) - A Linux Pluggable-Authentication-Module that authenticates LDAP accounts and can authenticate One-Time-Passwords when LDAP uses the LDAP TOTP schema

Part of the wheelybird LDAP MFA suite.
