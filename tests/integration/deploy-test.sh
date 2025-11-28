#!/bin/bash
set -e

echo "================================================"
echo "Luminary v2.0.0 + OpenVPN LDAP OTP Test Deployment"
echo "================================================"

# Configuration
NETWORK_NAME="ldap-test-net"
LDAP_DOMAIN="example.com"
LDAP_BASE_DN="dc=example,dc=com"
LDAP_ADMIN_PASSWORD="admin_password_change_me"
LDAP_READONLY_USER_PASSWORD="readonly_password_change_me"
LUMINARY_SERVER_HOSTNAME="${LUMINARY_SERVER_HOSTNAME:-localhost}"

# Create network if it doesn't exist
echo ""
echo "Creating Docker network..."
docker network create ${NETWORK_NAME} 2>/dev/null || echo "Network ${NETWORK_NAME} already exists"

# Create directories for volumes
echo ""
echo "Creating directory structure..."
mkdir -p data/ldap/database
mkdir -p data/ldap/config
mkdir -p data/certs
mkdir -p data/openvpn
mkdir -p data/ldif

# Generate self-signed certificate for Luminary
echo ""
echo "Generating self-signed SSL certificates for Luminary..."
if [ ! -f data/certs/luminary.crt ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout data/certs/luminary.key \
        -out data/certs/luminary.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=${LUMINARY_SERVER_HOSTNAME}" \
        -addext "subjectAltName=DNS:${LUMINARY_SERVER_HOSTNAME},DNS:localhost,IP:127.0.0.1"
    echo "Certificates generated successfully"
else
    echo "Certificates already exist, skipping generation"
fi

# Prepare TOTP schema LDIF files
echo ""
echo "Preparing TOTP schema LDIF files..."
if [ ! -f data/ldif/totp-schema.ldif ]; then
    cp ../../../../ldap-totp-schema/totp-schema.ldif data/ldif/totp-schema.ldif
    echo "TOTP schema LDIF copied"
else
    echo "TOTP schema LDIF already exists"
fi

if [ ! -f data/ldif/totp-acls.ldif ]; then
    # Copy and customize ACLs with correct base DN
    sed "s/dc=example,dc=com/${LDAP_BASE_DN}/g" ../../../../ldap-totp-schema/totp-acls.ldif > data/ldif/totp-acls.ldif
    echo "TOTP ACLs LDIF copied and customized"
else
    echo "TOTP ACLs LDIF already exists"
fi

# Stop and remove existing containers
echo ""
echo "Cleaning up existing containers..."
docker stop openldap luminary openvpn-test 2>/dev/null || true
docker rm openldap luminary openvpn-test 2>/dev/null || true

# Deploy OpenLDAP with STARTTLS
echo ""
echo "================================================"
echo "Deploying OpenLDAP with STARTTLS..."
echo "================================================"
docker run -d \
    --name openldap \
    --network ${NETWORK_NAME} \
    -p 389:389 \
    -p 636:636 \
    -e LDAP_ORGANISATION="Test Organization" \
    -e LDAP_DOMAIN="${LDAP_DOMAIN}" \
    -e LDAP_BASE_DN="${LDAP_BASE_DN}" \
    -e LDAP_ADMIN_PASSWORD="${LDAP_ADMIN_PASSWORD}" \
    -e LDAP_CONFIG_PASSWORD="${LDAP_ADMIN_PASSWORD}" \
    -e LDAP_READONLY_USER=true \
    -e LDAP_READONLY_USER_USERNAME="readonly" \
    -e LDAP_READONLY_USER_PASSWORD="${LDAP_READONLY_USER_PASSWORD}" \
    -e LDAP_TLS=true \
    -e LDAP_TLS_CRT_FILENAME=ldap.crt \
    -e LDAP_TLS_KEY_FILENAME=ldap.key \
    -e LDAP_TLS_CA_CRT_FILENAME=ca.crt \
    -e LDAP_TLS_VERIFY_CLIENT=never \
    -v $(pwd)/data/ldap/database:/var/lib/ldap \
    -v $(pwd)/data/ldap/config:/etc/ldap/slapd.d \
    -v $(pwd)/data/ldif/totp-schema.ldif:/container/service/slapd/assets/config/bootstrap/schema/custom/totp-schema.ldif:ro \
    -v $(pwd)/data/ldif/totp-acls.ldif:/container/service/slapd/assets/config/bootstrap/ldif/custom/totp-acls.ldif:ro \
    --restart unless-stopped \
    osixia/openldap:1.5.0

echo "Waiting for OpenLDAP to start and bootstrap schema..."
sleep 15

# Add initial test data
echo ""
echo "Adding initial test data..."
cat > /tmp/init-data.ldif << EOF
# Create organizational units
dn: ou=people,${LDAP_BASE_DN}
objectClass: organizationalUnit
ou: people

dn: ou=groups,${LDAP_BASE_DN}
objectClass: organizationalUnit
ou: groups

# Create admin group with MFA requirement
dn: cn=admins,ou=groups,${LDAP_BASE_DN}
objectClass: posixGroup
objectClass: mfaGroup
cn: admins
gidNumber: 5000
mfaRequired: TRUE
mfaGracePeriodDays: 7

# Create test user
dn: uid=testuser,ou=people,${LDAP_BASE_DN}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: testuser
cn: Test User
givenName: Test
sn: User
mail: testuser@${LDAP_DOMAIN}
uidNumber: 10000
gidNumber: 5000
homeDirectory: /home/testuser
loginShell: /bin/bash
userPassword: {SSHA}testpassword123

# Add test user to admins group
dn: cn=admins,ou=groups,${LDAP_BASE_DN}
changetype: modify
add: memberUid
memberUid: testuser
EOF

docker exec openldap ldapadd -x -D "cn=admin,${LDAP_BASE_DN}" -w "${LDAP_ADMIN_PASSWORD}" -f /tmp/init-data.ldif 2>/dev/null || echo "Test data may already exist"

# Deploy Luminary (LDAP User Manager) with HTTPS
echo ""
echo "================================================"
echo "Deploying Luminary v2.0.0 with HTTPS..."
echo "================================================"
docker run -d \
    --name luminary \
    --network ${NETWORK_NAME} \
    -p 8443:443 \
    -p 8080:80 \
    -e SERVER_HOSTNAME="${LUMINARY_SERVER_HOSTNAME}" \
    -e LDAP_URI="ldap://openldap" \
    -e LDAP_BASE_DN="${LDAP_BASE_DN}" \
    -e LDAP_ADMIN_BIND_DN="cn=admin,${LDAP_BASE_DN}" \
    -e LDAP_ADMIN_BIND_PWD="${LDAP_ADMIN_PASSWORD}" \
    -e LDAP_USES_NIS_SCHEMA="true" \
    -e LDAP_STARTTLS="TRUE" \
    -e LDAP_TLS_CACERT="/etc/ssl/certs/ca-certificates.crt" \
    -e LDAP_TLS_REQCERT="allow" \
    -e USERNAME_FORMAT="{first_name_initial}{last_name}" \
    -e USERNAME_REGEX="^[\p{L}\p{N}_.-]{2,64}$" \
    -e ORGANISATION_NAME="Test Organization" \
    -e EMAIL_DOMAIN="${LDAP_DOMAIN}" \
    -e MFA_ENABLED="true" \
    -e MFA_REQUIRED_GROUPS="admins" \
    -e MFA_GRACE_PERIOD_DAYS="7" \
    -e MFA_TOTP_ISSUER="Test Organization" \
    -v $(pwd)/data/certs/luminary.crt:/etc/ssl/certs/luminary.crt:ro \
    -v $(pwd)/data/certs/luminary.key:/etc/ssl/private/luminary.key:ro \
    --restart unless-stopped \
    wheelybird/luminary:v2.0.0

# Deploy OpenVPN with LDAP+OTP
echo ""
echo "================================================"
echo "Deploying OpenVPN with LDAP+OTP..."
echo "================================================"
docker run -d \
    --name openvpn-test \
    --network ${NETWORK_NAME} \
    -p 1194:1194/udp \
    -p 8444:8443 \
    -e OVPN_SERVER_CN="vpn.${LDAP_DOMAIN}" \
    -e LDAP_URI="ldap://openldap" \
    -e LDAP_BASE_DN="${LDAP_BASE_DN}" \
    -e LDAP_BIND_USER_DN="cn=readonly,${LDAP_BASE_DN}" \
    -e LDAP_BIND_USER_PASS="${LDAP_READONLY_USER_PASSWORD}" \
    -e LDAP_FILTER="(&(objectClass=posixAccount)(uid=%u))" \
    -e TOTP_ENABLED="true" \
    -e TOTP_MODE="append" \
    -e TOTP_ATTRIBUTE="totpSecret" \
    -e TOTP_GRACE_PERIOD_DAYS="7" \
    -e WEB_AUTH_ENABLED="true" \
    -e WEB_AUTH_PORT="8443" \
    -e WEB_AUTH_HOST="openvpn-test" \
    --cap-add=NET_ADMIN \
    --device /dev/net/tun \
    -v $(pwd)/data/openvpn:/etc/openvpn \
    --restart unless-stopped \
    wheelybird/openvpn-ldap-otp:testv2

# Wait for services to be ready
echo ""
echo "================================================"
echo "Waiting for services to start..."
echo "================================================"
sleep 5

# Check service status
echo ""
echo "Checking service status..."
docker ps --filter "name=openldap" --filter "name=luminary" --filter "name=openvpn-test" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Display connection information
echo ""
echo "================================================"
echo "Deployment Complete!"
echo "================================================"
echo ""
echo "Services:"
echo "  - OpenLDAP (STARTTLS):     ldap://localhost:389"
echo "  - Luminary (HTTPS):        https://localhost:8443"
echo "  - Luminary (HTTP):         http://localhost:8080"
echo "  - OpenVPN (UDP):           udp://localhost:1194"
echo "  - Web Auth Portal:         https://localhost:8444"
echo ""
echo "Default Credentials:"
echo "  - LDAP Admin:     cn=admin,${LDAP_BASE_DN}"
echo "  - LDAP Password:  ${LDAP_ADMIN_PASSWORD}"
echo "  - Test User:      testuser / testpassword123"
echo ""
echo "Luminary Admin Setup:"
echo "  1. Visit https://localhost:8443 (accept self-signed cert warning)"
echo "  2. Create admin account during first-time setup"
echo "  3. Login and navigate to 'Manage MFA' to set up 2FA"
echo ""
echo "Testing MFA:"
echo "  1. Login to Luminary as testuser"
echo "  2. Go to 'Manage MFA' page"
echo "  3. Scan QR code with Google Authenticator or Authy"
echo "  4. Complete enrollment with two consecutive codes"
echo "  5. Save backup codes"
echo "  6. Test VPN connection with: password + TOTP code"
echo ""
echo "View logs:"
echo "  docker logs openldap"
echo "  docker logs luminary"
echo "  docker logs openvpn-test"
echo ""
echo "Stop all services:"
echo "  docker stop openldap luminary openvpn-test"
echo ""
echo "Remove all services and data:"
echo "  docker rm openldap luminary openvpn-test"
echo "  rm -rf data/"
echo ""
