
if [ ! -f "$PKI_DIR/issued/$OVPN_SERVER_CN.key" ] || [ "$REGENERATE_CERTS" == 'true' ]; then

 EASYCMD="/opt/easyrsa/easyrsa --vars=/opt/easyrsa/vars"
 $EASYCMD init-pki

 $EASYCMD build-ca nopass

 $EASYCMD gen-dh
 openvpn --genkey --secret $PKI_DIR/ta.key

 $EASYCMD build-server-full "$OVPN_SERVER_CN" nopass

fi
