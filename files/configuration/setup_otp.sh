#Set up PAM for openvpn - with OTP if it's set as enabled
if [ "$ENABLE_OTP" == "true" ]; then
  echo "pam: enabling LDA & OTP"
  mv -f /opt/openvpn.with-otp /etc/pam.d/openvpn
else
  echo "pam: enabling LDAP"
  mv -f /opt/openvpn.without-otp /etc/pam.d/openvpn
fi
