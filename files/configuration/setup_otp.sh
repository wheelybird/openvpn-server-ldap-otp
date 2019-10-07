#Set up PAM for openvpn - with OTP if it's set as enabled
if [ "$ENABLE_OTP" == "true" ]; then
  echo "pam: enabling LDAP & OTP"
  cp -f /opt/openvpn.with-otp /etc/pam.d/openvpn
else
  echo "pam: enabling LDAP"
  cp -f /opt/openvpn.without-otp /etc/pam.d/openvpn
fi
