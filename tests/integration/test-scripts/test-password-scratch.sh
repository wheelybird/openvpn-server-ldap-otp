#!/bin/bash
# Test password + scratch code authentication

set -e

echo "========================================="
echo "Test: Password + Scratch Code Authentication"
echo "========================================="
echo "User: scratchuser"
echo "Password: test123"
echo "Scratch Codes: 12345678, 87654321, 99999999"
echo ""

# Test with first scratch code
echo "Testing with scratch code: 12345678"
echo "test12312345678" | pamtester openvpn scratchuser authenticate

if [ $? -eq 0 ]; then
    echo "✓ Password + Scratch code authentication PASSED"
    echo ""
    echo "Note: Scratch code 12345678 has been used and should not work again"
    exit 0
else
    echo "✗ Password + Scratch code authentication FAILED"
    exit 1
fi
