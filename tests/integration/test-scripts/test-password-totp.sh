#!/bin/bash
# Test password + TOTP authentication (append mode)

set -e

echo "========================================="
echo "Test: Password + TOTP Authentication"
echo "========================================="
echo "User: totpuser"
echo "Password: test123"
echo "TOTP Secret: JBSWY3DPEHPK3PXP"
echo ""

# Generate current TOTP code
TOTP_CODE=$(oathtool --totp --base32 JBSWY3DPEHPK3PXP)
echo "Current TOTP code: $TOTP_CODE"
echo ""

# Test with pamtester (append mode: password+code)
echo "test123${TOTP_CODE}" | pamtester openvpn totpuser authenticate

if [ $? -eq 0 ]; then
    echo "✓ Password + TOTP authentication PASSED"
    exit 0
else
    echo "✗ Password + TOTP authentication FAILED"
    exit 1
fi
