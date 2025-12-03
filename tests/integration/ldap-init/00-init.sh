#!/bin/bash
# Initialize LDAP test data
# This script runs inside the OpenLDAP container

set -e

LDAP_URI="ldap://openldap:389"
ADMIN_DN="cn=admin,dc=test,dc=local"
ADMIN_PASS="admin123"

echo "Waiting for LDAP to be ready..."
for i in {1..30}; do
    if ldapsearch -x -H "$LDAP_URI" -D "$ADMIN_DN" -w "$ADMIN_PASS" -b "dc=test,dc=local" &>/dev/null; then
        echo "LDAP is ready"
        break
    fi
    echo "Attempt $i/30..."
    sleep 2
done

# Add TOTP schema
echo "Adding TOTP schema..."
ldapadd -Y EXTERNAL -H ldapi:/// -f /ldap-init/01-totp-schema.ldif || echo "Schema already exists"

# Add test users
echo "Adding test users..."
ldapadd -x -H "$LDAP_URI" -D "$ADMIN_DN" -w "$ADMIN_PASS" -f /ldap-init/02-test-users.ldif || echo "Users already exist"

# Set passwords using ldappasswd (this generates proper SSHA hashes)
echo "Setting user passwords..."
for user in passonly totpuser scratchuser googleuser; do
    echo "Setting password for $user..."
    ldappasswd -x -H "$LDAP_URI" -D "$ADMIN_DN" -w "$ADMIN_PASS" \
        -s test123 "uid=$user,ou=people,dc=test,dc=local" || echo "Failed to set password for $user"
done

# Setup google-authenticator file for legacy testing
echo "Setting up google-authenticator file for googleuser..."
mkdir -p /home/googleuser
cp /ldap-init/google_authenticator_file /home/googleuser/.google_authenticator
chmod 600 /home/googleuser/.google_authenticator
chown 10004:10004 /home/googleuser/.google_authenticator 2>/dev/null || true

echo "LDAP initialization complete"
