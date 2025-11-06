#!/bin/bash
# Generate SSHA password hash using standard shell tools

password="$1"
if [ -z "$password" ]; then
    echo "Usage: $0 <password>"
    exit 1
fi

# Generate 4 bytes of random salt
salt=$(dd if=/dev/urandom bs=4 count=1 2>/dev/null | base64)

# Create SHA1 hash of password+salt, then append salt and base64 encode
hash=$(printf '%s%s' "$password" "$salt" | openssl dgst -binary -sha1 | cat - <(echo -n "$salt") | base64)

echo "{SSHA}$hash"
