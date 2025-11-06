#!/bin/bash
# Test password-only authentication (no MFA)

set -e

echo "========================================="
echo "Test: Password-Only Authentication"
echo "========================================="
echo "User: passonly"
echo "Password: test123"
echo ""

# Test with pamtester
echo "test123" | pamtester openvpn passonly authenticate

if [ $? -eq 0 ]; then
    echo "✓ Password-only authentication PASSED"
    exit 0
else
    echo "✗ Password-only authentication FAILED"
    exit 1
fi
