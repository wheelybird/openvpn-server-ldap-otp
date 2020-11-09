LDAP_CONFIG="/etc/nslcd.conf"

echo "ldap: creating LDAP configuration"

cat <<EoLDAP >$LDAP_CONFIG

uid nslcd
gid ldap

uri $LDAP_URI

base $LDAP_BASE_DN
scope sub

ldap_version 3

EoLDAP

if [ "$LDAP_ENCRYPT_CONNECTION" = "starttls" ]
then
  echo "ssl start_tls" >> $LDAP_CONFIG
elif [ "$LDAP_ENCRYPT_CONNECTION" = "on" ]
then
  echo "ssl on" >> $LDAP_CONFIG
fi

if [ "$LDAP_TLS_VALIDATE_CERT" = "false" ]
then
  echo "tls_reqcert no" >> $LDAP_CONFIG
fi

if [ -n "$LDAP_TLS_CA_CERT" ]
then
  echo "$LDAP_TLS_CA_CERT" > $OPENVPN_DIR/ldap-ca.crt
  echo "tls_cacertfile $OPENVPN_DIR/ldap-ca.crt" >> $LDAP_CONFIG
else
  echo "tls_cacertfile /etc/pki/tls/certs/ca-bundle.crt" >> $LDAP_CONFIG
fi

if [ "$ACTIVE_DIRECTORY_COMPAT_MODE" = "true" ]
then

  echo "filter passwd (objectClass=user)" >> $LDAP_CONFIG
  echo "map passwd uid sAMAccountName" >> $LDAP_CONFIG

else

  if [ -n "$LDAP_FILTER" ]
  then
    echo "filter passwd $LDAP_FILTER" >> $LDAP_CONFIG
  fi

  if [ -n "$LDAP_LOGIN_ATTRIBUTE" ]
  then
    echo "map passwd uid $LDAP_LOGIN_ATTRIBUTE" >> $LDAP_CONFIG
  fi

fi

if [ -n "$LDAP_BIND_USER_DN" ]
then

  echo "binddn $LDAP_BIND_USER_DN" >> $LDAP_CONFIG

  if [ -n "$LDAP_BIND_USER_PASS" ]
  then
    echo "bindpw $LDAP_BIND_USER_PASS" >> $LDAP_CONFIG
  elif [ -n "$LDAP_BIND_USER_PASS_FILE" ]
  then
    echo "bindpw "$(cat $LDAP_BIND_USER_PASS_FILE) >> $LDAP_CONFIG
  fi

fi
