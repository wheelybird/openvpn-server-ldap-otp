LDAP_CONFIG="/etc/nslcd.conf"

echo "ldap: creating LDAP configuration"

cat <<EoLDAP >$LDAP_CONFIG

uid nslcd
gid nslcd

uri $LDAP_URI

base $LDAP_BASE_DN
scope sub

ldap_version 3

EoLDAP

if [ "${LDAP_ENCRYPT_CONNECTION}" == "starttls" ] ; then
  echo "ssl start_tls" >> $LDAP_CONFIG
elif [ "${LDAP_ENCRYPT_CONNECTION}" == "on" ] ; then
  echo "ssl on" >> $LDAP_CONFIG
fi

if [ "${LDAP_TLS_VALIDATE_CERT}" == "false" ] ; then
  echo "tls_reqcert no" >> $LDAP_CONFIG
fi

if [ "${LDAP_TLS_CA_CERT}x" != "x" ] ; then
  echo "$LDAP_TLS_CA_CERT" > $OPENVPN_DIR/ldap-ca.crt
  echo "tls_cacertfile ${OPENVPN_DIR}/ldap-ca.crt" >> $LDAP_CONFIG
else
  echo "tls_cacertfile /etc/ssl/certs/ca-certificates.crt" >> $LDAP_CONFIG
fi

if [ "${ACTIVE_DIRECTORY_COMPAT_MODE}" == "true" ]; then

  echo "filter passwd (objectClass=user)" >> $LDAP_CONFIG
  echo "map passwd uid sAMAccountName" >> $LDAP_CONFIG

else

  if [ "${LDAP_FILTER}x" != "x" ]; then
    echo "filter passwd $LDAP_FILTER" >> $LDAP_CONFIG
  fi

  if [ "${LDAP_LOGIN_ATTRIBUTE}x" != "x" ]; then
    echo "map passwd uid $LDAP_LOGIN_ATTRIBUTE" >> $LDAP_CONFIG
  fi

fi

if [ "${LDAP_BIND_USER_DN}x" != "x" ] ; then
  echo "binddn $LDAP_BIND_USER_DN" >> $LDAP_CONFIG
  echo "bindpw $LDAP_BIND_USER_PASS" >> $LDAP_CONFIG
fi

if [ "${LDAP_DISABLE_BIND_SEARCH}" == "true" ] ; then
  echo "pam_authc_search NONE" >> $LDAP_CONFIG
fi

