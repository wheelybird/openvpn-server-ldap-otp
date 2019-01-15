LDAP_CONFIG="/etc/ldap_openvpn.conf"

echo "ldap: creating LDAP configuration"

cat <<EoLDAP >$LDAP_CONFIG

uri $LDAP_URI

base $LDAP_BASE_DN
scope sub

ldap_version 3
pam_crypt local

EoLDAP

if [ "${LDAP_TLS}" == "true" ] ; then
 echo "ssl start_tls" >> $LDAP_CONFIG
fi

if [ "${LDAP_TLS_CA_CERT}x" != "x" ] ; then

 echo "$LDAP_TLS_CA_CERT" > $OPENVPN_DIR/ldap-ca.crt
 echo "tls_cacertfile ${OPENVPN_DIR}/ldap-ca.crt" >> $LDAP_CONFIG

fi

if [ "${LDAP_FILTER}x" != "x" ] ; then
 echo "pam_filter $LDAP_FILTER" >> $LDAP_CONFIG
fi

if [ "${LDAP_LOGIN_ATTRIBUTE}x" != "x" ] ; then
 echo "pam_login_attribute $LDAP_LOGIN_ATTRIBUTE" >> $LDAP_CONFIG
fi

if [ "${LDAP_BIND_USER_DN}x" != "x" ] ; then

 echo "binddn $LDAP_BIND_USER_DN" >> $LDAP_CONFIG
 echo "bindpw $LDAP_BIND_USER_PASS" >> $LDAP_CONFIG

fi
