CONFIG_FILE="$OPENVPN_DIR/server.conf"

echo "openvpn: creating server config"

echo "# OpenVPN server configuration" > $CONFIG_FILE

[ "$OVPN_DEFAULT_SERVER" = "true" ] && echo "server $OVPN_NETWORK" >> $CONFIG_FILE

cat <<EOF >>$CONFIG_FILE

status $LOG_DIR/openvpn-status.log
log-append $LOG_FILE
verb $OVPN_VERBOSITY

key $PKI_DIR/private/${OVPN_SERVER_CN}.key
ca $PKI_DIR/ca.crt
cert $PKI_DIR/issued/${OVPN_SERVER_CN}.crt
dh $PKI_DIR/dh.pem

key-direction 0
persist-key
persist-tun

tls-auth $PKI_DIR/ta.key
#tls-cipher $OVPN_TLS_CIPHERS
auth SHA512
cipher AES-256-CBC

port 1194
proto $OVPN_PROTOCOL
dev $OVPN_INTERFACE_NAME
#dev-type tun

# As we're using LDAP, each client can use the same certificate
duplicate-cn

user nobody
group nobody

# Do not force renegotiation of client
#reneg-sec 0
EOF

if [ -n "$OVPN_DNS_SERVERS" ]
then

  nameservers=(${OVPN_DNS_SERVERS//,/ })
 
  for this_dns_server in "${nameservers[@]}"
  do
    echo "push \"dhcp-option DNS $this_dns_server\"" >> $CONFIG_FILE
  done

fi

[ -n "$OVPN_DNS_SEARCH_DOMAIN" ] && echo "push \"dhcp-option DOMAIN $OVPN_DNS_SEARCH_DOMAIN\"" >> $CONFIG_FILE

[ "$OVPN_ENABLE_COMPRESSION" = "true" ] && echo "comp-lzo" >> $CONFIG_FILE

if ([ -n "$OVPN_IDLE_TIMEOUT" ] && [ -n "{$OVPN_IDLE_TIMEOUT##*[!0-9]*}" ])
then
  cat <<EOF >> $CONFIG_FILE

inactive $OVPN_IDLE_TIMEOUT
ping 10
ping-exit 60

push "inactive $OVPN_IDLE_TIMEOUT"
push "ping 10"
push "ping-exit 60"

EOF
else
  echo -e "keepalive 10 60\n\n" >> $CONFIG_FILE
fi


if [ "$USE_CLIENT_CERTIFICATE" != "true" ]
then

  cat <<EOF >>$CONFIG_FILE
plugin /usr/lib64/openvpn/plugins/openvpn-plugin-auth-pam.so openvpn
username-as-common-name
client-cert-not-required

EOF

fi

if [ "$OVPN_MANAGEMENT_ENABLE" = "true" ]
then
  if [ "$OVPN_MANAGEMENT_NOAUTH" = "true" ]
  then
    [ -n "$OVPN_MANAGEMENT_PASSWORD" ] && echo "openvpn: warning: management password is set, but authentication is disabled"
    echo "management 0.0.0.0 5555" >> $CONFIG_FILE
    echo "openvpn: management interface enabled without authentication"
  else
    if [ -n "$OVPN_MANAGEMENT_PASSWORD" ]
    then
      PW_FILE="$OPENVPN_DIR/management_pw"
      echo "$OVPN_MANAGEMENT_PASSWORD" > $PW_FILE
      chmod 600 $PW_FILE
      echo "management 0.0.0.0 5555 $PW_FILE" >> $CONFIG_FILE
      echo "openvpn: management interface enabled with authentication"
    else
      echo "openvpn: warning: management password is not set, but authentication is enabled"
      echo "openvpn: management interface disabled"
    fi
  fi
else
  echo "openvpn: management interface disabled"
fi

[ -f "/tmp/routes_config.txt" ] && cat /tmp/routes_config.txt >> $CONFIG_FILE

cat <<EOF >>$CONFIG_FILE

############################################################
# individual configurations
$OVPN_EXTRA
EOF
