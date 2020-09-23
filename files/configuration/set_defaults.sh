abort=0

show_error () {
  echo "**"
  echo
  echo " $1 is missing.  Please set it as an environmental variable when launching the container:"
  echo "  -e \"$1=your_value\""
  echo
  echo "**"
  echo
  abort=1
}

[ -z "$USE_CLIENT_CERTIFICATE" ] && export USE_CLIENT_CERTIFICATE="false"
[ -z "$OVPN_SERVER_CN" ] && show_error OVPN_SERVER_CN

if [ "$USE_CLIENT_CERTIFICATE" != "true" ]
then
  [ -z "$LDAP_URI" ]     && show_error LDAP_URI
  [ -z "$LDAP_BASE_DN" ] && show_error LDAP_BASE_DN
fi

if ([ "$OVPN_PROTOCOL" != "tcp" ] \
 && [ "$OVPN_PROTOCOL" != "tcp4" ] \
 && [ "$OVPN_PROTOCOL" != "tcp6" ] \
 && [ "$OVPN_PROTOCOL" != "udp" ] \
 && [ "$OVPN_PROTOCOL" != "udp4" ] \
 && [ "$OVPN_PROTOCOL" != "udp6" ] )
then
  export OVPN_PROTOCOL="udp4"
fi

[ "$abort" = "1" ] && exit 1

export OPENVPN_DIR="/etc/openvpn"
export CONFIGFILES="/opt/configuration"
export EASYRSA_DIR="/opt/easyrsa"
export PKI_DIR="$OPENVPN_DIR/pki"
[ -z "$LOG_DIR" ] && export LOG_DIR="$OPENVPN_DIR/logs"
[ -d "$LOG_DIR" ] || mkdir -p $LOG_DIR

default_tls_ciphers="TLS-DHE-RSA-WITH-AES-256-CBC-SHA:TLS-DHE-RSA-WITH-AES-256-CBC-SHA256:TLS-DHE-RSA-WITH-AES-256-CBC-SHA256:TLS-DHE-RSA-WITH-CAMELLIA-256-CBC-SHA:TLS-DHE-RSA-WITH-AES-128-CBC-SHA"

[ -z "$ACTIVE_DIRECTORY_COMPAT_MODE" ] && export ACTIVE_DIRECTORY_COMPAT_MODE="false"
[ -z "$DEBUG"                        ] && export DEBUG="false"
[ -z "$ENABLE_OTP"                   ] && export ENABLE_OTP="false"
[ -z "$FAIL2BAN_ENABLED"             ] && export FAIL2BAN_ENABLED="false"
[ "$FAIL2BAN_ENABLED" = "true"       ] && export LOG_TO_STDOUT="false"
[ -z "$FAIL2BAN_MAXRETRIES"          ] && export FAIL2BAN_MAXRETRIES="3"
[ -z "$KEY_LENGTH"                   ] && export KEY_LENGTH="2048"
[ -z "$LDAP_ENCRYPT_CONNECTION"      ] && export LDAP_ENCRYPT_CONNECTION="off"
[ -z "$LDAP_LOGIN_ATTRIBUTE"         ] && export LDAP_LOGIN_ATTRIBUTE="uid"
[ -z "$LDAP_TLS"                     ] && export LDAP_TLS="false"
[ "$LDAP_TLS" = 'true'               ] && export LDAP_ENCRYPT_CONNECTION="starttls"
[ -z "$LDAP_TLS_VALIDATE_CERT"       ] && export LDAP_TLS_VALIDATE_CERT="true"
[ -z "$LOG_TO_STDOUT"                ] && export LOG_TO_STDOUT="true"
[ -z "$OVPN_DEFAULT_SERVER"          ] && export OVPN_DEFAULT_SERVER="true"
[ -z "$OVPN_ENABLE_COMPRESSION"      ] && export OVPN_ENABLE_COMPRESSION="true"
[ -z "$OVPN_INTERFACE_NAME"          ] && export OVPN_INTERFACE_NAME="tun"
[ -z "$OVPN_MANAGEMENT_ENABLE"       ] && export OVPN_MANAGEMENT_ENABLE="false"
[ -z "$OVPN_MANAGEMENT_NOAUTH"       ] && export OVPN_MANAGEMENT_NOAUTH="false"
[ -z "$OVPN_NAT"                     ] && export OVPN_NAT="true"
[ -z "$OVPN_NETWORK"                 ] && export OVPN_NETWORK="10.50.50.0 255.255.255.0"
[ -z "$OVPN_REGISTER_DNS"            ] && export OVPN_REGISTER_DNS="false"
[ -z "$OVPN_TLS_CIPHERS"             ] && export OVPN_TLS_CIPHERS=$default_tls_ciphers
[ -z "$OVPN_VERBOSITY"               ] && export OVPN_VERBOSITY="3"
[ -z "$REGENERATE_CERTS"             ] && export REGENERATE_CERTS="false"

if [ "$LOG_TO_STDOUT" = "true" ]
then
  export LOG_FILE="/dev/stdout"
else
  export LOG_FILE="$LOG_DIR/openvpn.log"
fi
