CONFIG_FILE="${OPENVPN_DIR}/server.conf"

echo "openvpn: creating server config"

cat <<Part01 >$CONFIG_FILE
# OpenVPN server configuration

server $OVPN_NETWORK

port 1194
proto $OVPN_PROTOCOL
dev tun

ca $PKI_DIR/ca.crt
cert $PKI_DIR/issued/${OVPN_SERVER_CN}.crt
key $PKI_DIR/private/${OVPN_SERVER_CN}.key
dh $PKI_DIR/dh.pem

Part01

if [ "${OVPN_DNS_SERVERS}x" != "x" ] ; then

 nameservers=(${OVPN_DNS_SERVERS//,/ })
 
 for this_dns_server in "${nameservers[@]}" ; do
  echo "push \"dhcp-option DNS $this_dns_server\"" >> $CONFIG_FILE
 done

fi

if [ "${OVPN_DNS_SEARCH_DOMAIN}x" != "x" ]; then
 echo "push \"dhcp-option DOMAIN $OVPN_DNS_SEARCH_DOMAIN\"" >> $CONFIG_FILE
fi

cat /tmp/routes_config.txt >> $CONFIG_FILE

cat <<Part02 >>$CONFIG_FILE

# As we're using LDAP, each client can use the same certificate
duplicate-cn

keepalive 10 120

tls-auth $PKI_DIR/ta.key 0 
tls-cipher $OVPN_TLS_CIPHERS
auth SHA512
cipher AES-256-CBC

comp-lzo

user nobody
group nobody

persist-key
persist-tun

status $OPENVPN_DIR/openvpn-status.log
log-append $LOG_FILE
verb $OVPN_VERBOSITY

# Do not force renegotiation of client
reneg-sec 0

Part02

if [ "${USE_CLIENT_CERTIFICATE}" != "true" ] ; then

cat <<Part03 >>$CONFIG_FILE
plugin /usr/lib64/openvpn/plugins/openvpn-plugin-auth-pam.so openvpn
verify-client-cert optional
username-as-common-name

Part03

fi

if [ "${OVPN_MANAGEMENT_ENABLE}x" == "true" ]; then
 if [ "${OVPN_MANAGEMENT_NOAUTH}x" == "true" ]; then
  if [ "${OVPN_MANAGEMENT_PASSWORD}x" != "x" ]; then
   echo "openvpn: warning: management password is set, but authentication is disabled"
  fi
  echo "management 0.0.0.0 5555" >> $CONFIG_FILE
 else
  if [ "${OVPN_MANAGEMENT_PASSWORD}x" != "x" ]; then
   PW_FILE="${OPENVPN_DIR}/management_pw"
   echo "$OVPN_MANAGEMENT_PASSWORD" > $PW_FILE
   echo "management 0.0.0.0 5555 $PW_FILE" >> $CONFIG_FILE
  else
   echo "openvpn: warning: management password is not set, but authentication is enabled. management interface will not be enabled"
  fi
 fi
fi
