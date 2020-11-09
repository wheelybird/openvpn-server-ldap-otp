if [ "$REGENERATE_CERTS" = 'true' ] || [ ! -f "$PKI_DIR/issued/$OVPN_SERVER_CN.crt" ]
then

  echo "easyrsa: creating server certs"
  EASYCMD="/usr/share/easy-rsa/3/easyrsa --vars=/opt/easyrsa/vars"
  $EASYCMD init-pki
  
  $EASYCMD build-ca nopass
  
  $EASYCMD gen-dh
  openvpn --genkey --secret $PKI_DIR/ta.key
  
  $EASYCMD build-server-full "$OVPN_SERVER_CN" nopass

fi

if [ "$REGENERATE_CERTS" = 'true' ] \
|| ( [ "$USE_CLIENT_CERTIFICATE" = "true" ] \
  && ( [ ! -f "$PKI_DIR/private/client.key" ] || [ ! -f "$PKI_DIR/issued/client.crt" ] ) \
)
  then

    echo "easyrsa: creating client certs"
    $EASYCMD build-client-full client nopass

fi
