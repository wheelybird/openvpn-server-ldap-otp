#!/bin/bash
# Test google-authenticator legacy file-based authentication

set -e

echo "========================================="
echo "Test: Google Authenticator Legacy (File-Based)"
echo "========================================="
echo "User: googleuser"
echo "Password: test123"
echo "TOTP Secret (from file): JBSWY3DPEHPK3PXP"
echo ""

# Generate current TOTP code
TOTP_CODE=$(oathtool --totp --base32 JBSWY3DPEHPK3PXP)
echo "Current TOTP code: $TOTP_CODE"
echo ""

# Create PAM configuration for google-authenticator testing
cat > /etc/pam.d/openvpn-google <<'EOF'
# Google Authenticator legacy authentication test
auth required pam_ldap.so use_first_pass
auth required pam_google_authenticator.so forward_pass
account required pam_ldap.so
EOF

echo "Testing with file-based google-authenticator..."
# Test with pamtester (append mode: password+code)
echo "test123${TOTP_CODE}" | pamtester openvpn-google googleuser authenticate

if [ $? -eq 0 ]; then
    echo "✓ Google Authenticator legacy authentication PASSED"
    exit 0
else
    echo "✗ Google Authenticator legacy authentication FAILED"
    exit 1
fi
