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

if [ "${USE_CLIENT_CERTIFICATE}x" == "x" ]; then export USE_CLIENT_CERTIFICATE="false"; fi

if [ "${OVPN_SERVER_CN}x" == "x" ]; then show_error OVPN_SERVER_CN ; fi

if [ "${USE_CLIENT_CERTIFICATE}" != "true" ]; then
 if [ "${LDAP_URI}x" == "x" ]; then show_error LDAP_URI ; fi
 if [ "${LDAP_BASE_DN}x" == "x" ]; then show_error LDAP_BASE_DN ; fi
fi

if [ "$abort" == "1" ]; then exit 1 ; fi

export OPENVPN_DIR="/etc/openvpn"
export CONFIGFILES="/opt/configuration"
export EASYRSA_DIR="/opt/easyrsa"
export PKI_DIR="${OPENVPN_DIR}/pki"
export LOG_DIR="${OPENVPN_DIR}/logs"
if [ ! -d "$LOG_DIR" ]; then
 mkdir -p $LOG_DIR
fi

default_tls_ciphers="TLS-DHE-RSA-WITH-AES-256-CBC-SHA:TLS-DHE-RSA-WITH-AES-256-CBC-SHA256:TLS-DHE-RSA-WITH-AES-256-CBC-SHA256:TLS-DHE-RSA-WITH-CAMELLIA-256-CBC-SHA:TLS-DHE-RSA-WITH-AES-128-CBC-SHA"

if [ "${OVPN_TLS_CIPHERS}x" == "x" ];             then export OVPN_TLS_CIPHERS=$default_tls_ciphers;      fi
if [ "${OVPN_PROTOCOL}x" == "x" ];                then export OVPN_PROTOCOL="udp";                        fi
if [ "${OVPN_NETWORK}x" == "x" ];                 then export OVPN_NETWORK="10.50.50.0 255.255.255.0";    fi
if [ "${OVPN_VERBOSITY}x" == "x" ];               then export OVPN_VERBOSITY="3";                         fi
if [ "${OVPN_NAT}x" == "x" ];                     then export OVPN_NAT="true";                            fi
if [ "${OVPN_REGISTER_DNS}x" == "x" ];            then export OVPN_REGISTER_DNS="false";                  fi
if [ "${OVPN_ENABLE_COMPRESSION}x" == "x" ];      then export OVPN_ENABLE_COMPRESSION="true";             fi
if [ "${REGENERATE_CERTS}x" == "x" ];             then export REGENERATE_CERTS="false";                   fi
if [ "${OVPN_MANAGEMENT_ENABLE}x" == "x" ];       then export OVPN_MANAGEMENT_ENABLE="false";             fi
if [ "${OVPN_MANAGEMENT_NOAUTH}x" == "x" ];       then export OVPN_MANAGEMENT_NOAUTH="false";             fi
if [ "${DEBUG}x" == "x" ];                        then export DEBUG="false";                              fi
if [ "${LOG_TO_STDOUT}x" == "x" ];                then export LOG_TO_STDOUT="true";                       fi
if [ "${ENABLE_OTP}x" == "x" ];                   then export ENABLE_OTP="false";                         fi
if [ "${LDAP_LOGIN_ATTRIBUTE}x" == "x" ];         then export LDAP_LOGIN_ATTRIBUTE="uid";                 fi
if [ "${LDAP_ENCRYPT_CONNECTION}x" == "x" ];      then export LDAP_ENCRYPT_CONNECTION="off";              fi
if [ "${LDAP_TLS}x" == "x" ];                     then export LDAP_TLS="false";                           fi
if [ "${LDAP_TLS}" == 'true' ];                   then export LDAP_ENCRYPT_CONNECTION="starttls";         fi
if [ "${LDAP_TLS_VALIDATE_CERT}x" == "x" ];       then export LDAP_TLS_VALIDATE_CERT="true";              fi
if [ "${KEY_LENGTH}x" == "x" ];                   then export KEY_LENGTH="2048";                          fi
if [ "${FAIL2BAN_ENABLED}x" == "x" ];             then export FAIL2BAN_ENABLED="false";                   fi
if [ "${FAIL2BAN_MAXRETRIES}x" == "x" ];          then export FAIL2BAN_MAXRETRIES="3";                    fi
if [ "${ACTIVE_DIRECTORY_COMPAT_MODE}x" == "x" ]; then export ACTIVE_DIRECTORY_COMPAT_MODE="false";       fi

if [ "$FAIL2BAN_ENABLED" == "true" ];             then export LOG_TO_STDOUT="false";                      fi
if [ "$LOG_TO_STDOUT" == "true" ]; then
 LOG_FILE="/proc/1/fd/1"
else
 LOG_FILE="${LOG_DIR}/openvpn.log"
fi



