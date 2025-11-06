if [ ! -f "$PKI_DIR/issued/$OVPN_SERVER_CN.crt" ] || [ "$REGENERATE_CERTS" == 'true' ]; then

 echo "easyrsa: creating server certs"
 sed -i 's/^RANDFILE/#RANDFILE/g' /opt/easyrsa/openssl-easyrsa.cnf
 EASYCMD="/opt/easyrsa/easyrsa"
 . /opt/easyrsa/pki_vars
 $EASYCMD init-pki

 $EASYCMD build-ca nopass

 $EASYCMD gen-dh
 openvpn --genkey secret $PKI_DIR/ta.key

 $EASYCMD gen-req "$OVPN_SERVER_CN" nopass
 $EASYCMD sign-req server "$OVPN_SERVER_CN"

 if [ "${USE_CLIENT_CERTIFICATE}" == "true" ] ; then
  echo "easyrsa: creating client certs"
  $EASYCMD build-client-full client nopass
 fi

 # Fix permissions for OpenVPN running as nobody:nogroup
 # Private keys stay 600 (root only), but other files need to be readable
 echo "easyrsa: setting permissions for unprivileged operation"
 chmod 644 $PKI_DIR/ca.crt
 chmod 644 $PKI_DIR/dh.pem
 chmod 644 $PKI_DIR/ta.key
 chmod 644 $PKI_DIR/issued/$OVPN_SERVER_CN.crt
 # Keep private key secure (root only)
 chmod 600 $PKI_DIR/private/$OVPN_SERVER_CN.key

else
 # Certificates already exist - ensure permissions are correct for unprivileged operation
 echo "easyrsa: certificates exist, fixing permissions for unprivileged operation"
 if [ -f "$PKI_DIR/ca.crt" ]; then chmod 644 $PKI_DIR/ca.crt; fi
 if [ -f "$PKI_DIR/dh.pem" ]; then chmod 644 $PKI_DIR/dh.pem; fi
 if [ -f "$PKI_DIR/ta.key" ]; then chmod 644 $PKI_DIR/ta.key; fi
 if [ -f "$PKI_DIR/issued/$OVPN_SERVER_CN.crt" ]; then chmod 644 $PKI_DIR/issued/$OVPN_SERVER_CN.crt; fi
 if [ -f "$PKI_DIR/private/$OVPN_SERVER_CN.key" ]; then chmod 600 $PKI_DIR/private/$OVPN_SERVER_CN.key; fi
fi
