#!/bin/bash
# Build OpenVPN Server with LDAP TOTP Authentication
#
# The PAM module (pam-ldap-totp-auth) is automatically cloned from GitHub
# during the Docker build process.
#
# Repository: https://github.com/wheelybird/pam-ldap-totp-auth

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "========================================="
echo "Building OpenVPN LDAP TOTP Docker Image"
echo "========================================="
echo ""
echo "Build context: $SCRIPT_DIR"
echo "Dockerfile: $SCRIPT_DIR/Dockerfile"
echo ""
echo "PAM module will be cloned from:"
echo "  https://github.com/wheelybird/pam-ldap-totp-auth"
echo ""

# Build from this directory
cd "$SCRIPT_DIR"

echo "Building Docker image..."
docker build \
    -f Dockerfile \
    -t openvpn-server-ldap-otp:latest \
    .

echo ""
echo "========================================="
echo "Build complete!"
echo "========================================="
echo ""
echo "Image: openvpn-server-ldap-otp:latest"
echo ""
echo "To run the container, use:"
echo "  cd docker/openvpn-server-ldap-otp"
echo "  ./run-openvpn.sh"
echo ""
