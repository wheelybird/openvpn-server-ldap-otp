if [ ! -f "$PKI_DIR/issued/$OVPN_SERVER_CN.crt" ] || [ "$REGENERATE_CERTS" == 'true' ]; then

 echo "easyrsa: creating server certs"
 dd if=/dev/urandom of=/etc/openvpn/pki/.rnd bs=256 count=1
 EASYCMD="/opt/easyrsa/easyrsa --vars=/opt/easyrsa/vars"
 $EASYCMD init-pki

 $EASYCMD build-ca nopass

 $EASYCMD gen-dh
 openvpn --genkey --secret $PKI_DIR/ta.key

 $EASYCMD build-server-full "$OVPN_SERVER_CN" nopass

 if [ "${USE_CLIENT_CERTIFICATE}" == "true" ] ; then
  echo "easyrsa: creating client certs"
  $EASYCMD build-client-full client nopass
 fi

fi
