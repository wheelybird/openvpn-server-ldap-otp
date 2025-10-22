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

fi
