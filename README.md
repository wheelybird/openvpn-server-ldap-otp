# OpenVPN Server with LDAP Authentication and MFA

A Docker container providing OpenVPN with LDAP authentication and optional two-factor authentication (TOTP/MFA). Part of an integrated suite of tools for enterprise-grade VPN access with centralised user management.

## Why Use This?

- **Centralised Authentication**: Use your existing LDAP directory for VPN access
- **Optional MFA/2FA**: Add time-based one-time passwords (TOTP) for enhanced security
- **Self-Service Management**: Users can enrol and manage their own MFA via web interface
- **Enterprise Ready**: Supports fail2ban, custom routing, and advanced networking
- **Docker Native**: Easy deployment with persistent configuration

## Complete Solution Stack

This OpenVPN server works best as part of an integrated solution:

| Component | Purpose | Repository |
|-----------|---------|------------|
| **OpenVPN Server** (this project) | VPN gateway with LDAP + MFA authentication | [openvpn-server-ldap-otp](https://github.com/wheelybird/openvpn-server-ldap-otp) |
| **LDAP User Manager** | Web UI for self-service MFA enrolment | [ldap-user-manager](https://github.com/wheelybird/ldap-user-manager) |
| **LDAP TOTP Schema** | LDAP schema for storing TOTP secrets | [ldap-totp-schema](https://github.com/wheelybird/ldap-totp-schema) |
| **LDAP TOTP PAM Module** | PAM authentication module (built automatically) | [ldap-totp-pam](https://github.com/wheelybird/ldap-totp-pam) |

**Benefits of the complete stack:**
- Users can scan QR codes and set up MFA themselves
- Admins can enforce MFA by group membership
- Grace periods allow users time to enrol before VPN access is restricted
- Backup codes stored in LDAP for account recovery
- No need to SSH into servers to manage OTP secrets

## Quick Start

### Basic Setup (LDAP Authentication Only)

```bash
docker run \
  --name openvpn \
  --cap-add=NET_ADMIN \
  -p 1194:1194/udp \
  -v /path/to/data:/etc/openvpn \
  -e "OVPN_SERVER_CN=vpn.example.com" \
  -e "LDAP_URI=ldap://ldap.example.com" \
  -e "LDAP_BASE_DN=dc=example,dc=com" \
  -e "LDAP_BIND_USER_DN=cn=readonly,dc=example,dc=com" \
  -e "LDAP_BIND_USER_PASS=password" \
  -d \
  wheelybird/openvpn-ldap-otp:latest
```

### With MFA (Recommended)

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
  -e "LDAP_BIND_USER_DN=cn=readonly,dc=example,dc=com" \
  -e "LDAP_BIND_USER_PASS=password" \
  -e "ENABLE_OTP=true" \
  -e "ENABLE_PAM_LDAP_OTP=true" \
  -d \
  wheelybird/openvpn-ldap-otp:latest
```

Deploy the [LDAP User Manager](https://github.com/wheelybird/ldap-user-manager) to give users a friendly web interface for MFA enrolment.

### Get Client Configuration

```bash
docker exec -ti openvpn show-client-config > client.ovpn
```

Distribute this `.ovpn` file to your users. When connecting with MFA enabled, users enter: `password123456` (password + 6-digit TOTP code concatenated).

## Authentication Modes

### 1. LDAP Password Only
Simple LDAP authentication without MFA.

**Configuration:**
```bash
-e "LDAP_URI=ldap://ldap.example.com"
-e "LDAP_BASE_DN=dc=example,dc=com"
```

**User Experience:** Users enter just their LDAP password.

---

### 2. File-Based TOTP (Traditional)
Use google-authenticator with file-based secret storage.

**Configuration:**
```bash
-e "ENABLE_OTP=true"
```

**Setup:** `docker exec -ti openvpn add-otp-user username`

**User Experience:** Users enter `password123456` (password + TOTP code).

---

### 3. LDAP-Backed TOTP (Recommended)
Store TOTP secrets in LDAP for centralised management.

**Prerequisites:**
1. Install [LDAP TOTP Schema](https://github.com/wheelybird/ldap-totp-schema) in your LDAP directory
2. Optionally deploy [LDAP User Manager](https://github.com/wheelybird/ldap-user-manager) for self-service

**Configuration:**
```bash
-e "ENABLE_OTP=true"
-e "ENABLE_PAM_LDAP_OTP=true"
```

**User Experience:**
- Users enrol via web UI (scan QR code with authenticator app)
- Users enter `password123456` when connecting to VPN
- Backup codes available for emergency access

**Benefits:**
- Self-service enrolment via web interface
- Admin oversight of MFA adoption
- Group-based MFA requirements
- Grace periods for new users
- Backup codes stored in LDAP

See [AUTHENTICATION_MODES.md](AUTHENTICATION_MODES.md) for detailed information.

---

### 4. Client Certificate Authentication
Traditional X.509 certificate-based authentication (no LDAP required).

**Configuration:**
```bash
-e "USE_CLIENT_CERTIFICATE=true"
```

**User Experience:** Users connect with certificate, no password needed.

**Use Case:** Development, testing, or traditional certificate-based deployments.

## Configuration

### Required Settings

| Variable | Description | Example |
|----------|-------------|---------|
| `OVPN_SERVER_CN` | Server hostname (must be resolvable by clients) | `vpn.example.com` |

### LDAP Settings

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

**Active Directory Users:** Set `-e "ACTIVE_DIRECTORY_COMPAT_MODE=true"` to automatically configure appropriate settings.

### MFA/TOTP Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_OTP` | `false` | Enable two-factor authentication |
| `ENABLE_PAM_LDAP_OTP` | `false` | Use LDAP-backed TOTP (requires LDAP schema) |
| `LDAP_TOTP_ATTRIBUTE` | `totpSecret` | LDAP attribute storing TOTP secret |
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
| `OVPN_REGISTER_DNS` | `false` | Force DNS on Windows clients |

### Security Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `KEY_LENGTH` | `2048` | Certificate key length (higher = more secure, slower) |
| `OVPN_TLS_CIPHERS` | Modern ciphers | TLS 1.2 cipher list |
| `OVPN_TLS_CIPHERSUITES` | Modern suites | TLS 1.3 cipher suites |
| `OVPN_IDLE_TIMEOUT` | None | Disconnect idle connections (seconds) |
| `REGENERATE_CERTS` | `false` | Force certificate regeneration |

### Fail2ban Protection

| Variable | Default | Description |
|----------|---------|-------------|
| `FAIL2BAN_ENABLED` | `false` | Enable brute-force protection |
| `FAIL2BAN_MAXRETRIES` | `3` | Failed attempts before ban |

### Management Interface

| Variable | Default | Description |
|----------|---------|-------------|
| `OVPN_MANAGEMENT_ENABLE` | `false` | Enable TCP management interface on port 5555 |
| `OVPN_MANAGEMENT_NOAUTH` | `false` | Allow access without authentication |
| `OVPN_MANAGEMENT_PASSWORD` | None | Management interface password |

### Advanced Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `OVPN_DEFAULT_SERVER` | `true` | Auto-generate server network config |
| `OVPN_EXTRA` | None | Additional OpenVPN config directives (raw text) |
| `OVPN_VERBOSITY` | `4` | Log verbosity (0-11) |
| `DEBUG` | `false` | Enable debug logging |
| `LOG_TO_STDOUT` | `true` | Send OpenVPN logs to stdout |

## Data Persistence

Mount `/etc/openvpn` as a volume to persist:
- Generated certificates and keys
- Server configuration
- OTP secrets (if using file-based mode)
- Client configuration

```bash
-v /path/on/host:/etc/openvpn
```

**Important:** The first run generates certificates (2048-bit key takes 2-10 minutes). Subsequent starts are much faster.

## Security Best Practices

### TLS/SSL for LDAP
```bash
-e "LDAP_ENCRYPT_CONNECTION=starttls"
-e "LDAP_TLS_VALIDATE_CERT=true"
-e "LDAP_TLS_CA_CERT=$(cat /path/to/ca.crt)"
```

### Enable MFA
```bash
-e "ENABLE_OTP=true"
-e "ENABLE_PAM_LDAP_OTP=true"
```

Deploy [LDAP User Manager](https://github.com/wheelybird/ldap-user-manager) for self-service enrolment.

### Restrict VPN Access by LDAP Group
```bash
-e "LDAP_FILTER=(memberOf=cn=vpn-users,ou=groups,dc=example,dc=com)"
```

### Enable Fail2ban
```bash
-e "FAIL2BAN_ENABLED=true"
-e "FAIL2BAN_MAXRETRIES=3"
```

### Session Timeouts
```bash
-e "OVPN_IDLE_TIMEOUT=3600"  # 1 hour
```

## Common Tasks

### View Client Configuration
```bash
docker exec -ti openvpn show-client-config
```

### Add File-Based OTP User
```bash
docker exec -ti openvpn add-otp-user username
```

### Check Container Logs
```bash
docker logs -f openvpn
```

### Fail2ban Administration
```bash
# Ban an IP
docker exec -ti openvpn fail2ban-client set openvpn banip 192.168.1.100

# Unban an IP
docker exec -ti openvpn fail2ban-client set openvpn unbanip 192.168.1.100

# View fail2ban logs
docker exec -ti openvpn tail -50 /var/log/fail2ban.log
```

### Force Certificate Regeneration
```bash
docker run ... -e "REGENERATE_CERTS=true" ...
```

## Troubleshooting

### Container Hangs at "Generating DH parameters"

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

### LDAP Authentication Fails

**Check LDAP connectivity:**
```bash
docker exec -ti openvpn ldapsearch -x -H "${LDAP_URI}" -b "${LDAP_BASE_DN}" -D "${LDAP_BIND_USER_DN}" -w "${LDAP_BIND_USER_PASS}"
```

**Common issues:**
- Bind user lacks search permissions
- LDAP filter too restrictive
- TLS certificate validation failing (try `LDAP_TLS_VALIDATE_CERT=false` temporarily)
- Wrong base DN or bind credentials

### MFA/OTP Not Working

**File-based TOTP:**
- Check OTP file exists: `docker exec -ti openvpn ls /etc/openvpn/otp/`
- Ensure time synchronization with NTP

**LDAP-backed TOTP:**
- Verify LDAP schema installed: [ldap-totp-schema](https://github.com/wheelybird/ldap-totp-schema)
- Check user has `totpSecret` attribute populated
- Verify PAM module config: `docker exec -ti openvpn cat /etc/security/pam_ldap_totp.conf`
- Enable debug: `-e "DEBUG=true"`

**Time synchronization critical for TOTP:**
```bash
# Check time on host and container
date
docker exec -ti openvpn date
```

Install NTP/chrony on both.

### Clients Can't Reach Internal Networks

**Issue:** VPN connects but can't access internal resources.

**Solutions:**

1. **Enable NAT** (easiest):
   ```bash
   -e "OVPN_NAT=true"
   ```

2. **Add return routes** on internal gateways pointing VPN network (`10.50.50.0/24`) to OpenVPN server IP

3. **Check routing**:
   ```bash
   docker exec -ti openvpn ip route
   docker exec -ti openvpn iptables -t nat -L -n -v
   ```

## Documentation

- **[AUTHENTICATION_MODES.md](AUTHENTICATION_MODES.md)** - Detailed authentication mode documentation
- **[SECURITY_UPDATE.md](SECURITY_UPDATE.md)** - Recent security improvements
- **[LDAP TOTP Schema](https://github.com/wheelybird/ldap-totp-schema)** - Schema installation guide
- **[LDAP User Manager](https://github.com/wheelybird/ldap-user-manager)** - Self-service MFA web UI
- **[LDAP TOTP PAM Module](https://github.com/wheelybird/ldap-totp-pam)** - PAM module documentation

## Support

- **Issues:** https://github.com/wheelybird/openvpn-server-ldap-otp/issues
- **Pull Requests:** Welcome!

## Licence

See LICENCE file for details.

## Credits

Built on top of:
- [OpenVPN](https://openvpn.net/)
- [nslcd/libpam-ldapd](https://arthurdejong.org/nss-pam-ldapd/)
- [OATH Toolkit](https://www.nongnu.org/oath-toolkit/)
- [Easy-RSA](https://github.com/OpenVPN/easy-rsa)

Part of the wheelybird LDAP MFA suite.
