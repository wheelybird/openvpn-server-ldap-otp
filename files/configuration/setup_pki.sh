
if [ ! -f "$EASYRSA_PKI/.certs_generated" ] || [ $REGENERATE_CERTS == 'true' ]; then

 EASYCMD="/opt/easyrsa/easyrsa --vars=/opt/easyrsa/vars"
 $EASYCMD init-pki

 $EASYCMD build-ca nopass

 $EASYCMD gen-dh
 openvpn --genkey --secret $PKI_DIR/ta.key

 $EASYCMD build-server-full "$OVPN_SERVER_CN" nopass

 touch $EASYRSA_PKI/.certs_generated
 
fi
