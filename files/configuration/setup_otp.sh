#Set up PAM for openvpn - with OTP if it's set as enabled
if [ "$ENABLE_OTP" == "true" ]; then
  if [ "$ENABLE_PAM_LDAP_OTP" == "true" ]; then
    echo "pam: enabling LDAP & LDAP-backed OTP"
    cp -f /opt/pam.d/openvpn.with-ldap-otp /etc/pam.d/openvpn

    # PAM LDAP TOTP configuration is already installed at /etc/security/pam_ldap_totp.conf
    # (copied during Docker build)

    # Configure TOTP mode based on TOTP_MODE environment variable
    # append (default) - password+OTP concatenated
    # challenge - server prompts for OTP after password (not supported by OpenVPN clients)
    if [ -n "$TOTP_MODE" ]; then
      sed -i "s/^totp_mode .*/totp_mode $TOTP_MODE/" /etc/security/pam_ldap_totp.conf
    fi

    # Configure TOTP attribute if specified
    if [ -n "$LDAP_TOTP_ATTRIBUTE" ]; then
      sed -i "s/^totp_attribute .*/totp_attribute $LDAP_TOTP_ATTRIBUTE/" /etc/security/pam_ldap_totp.conf
    fi

    # Configure TOTP prefix if specified
    if [ -n "$LDAP_TOTP_PREFIX" ]; then
      sed -i "s/^totp_prefix .*/totp_prefix $LDAP_TOTP_PREFIX/" /etc/security/pam_ldap_totp.conf
    fi

    # Configure grace period if specified
    if [ -n "$MFA_GRACE_PERIOD_DAYS" ]; then
      sed -i "s/^grace_period_days .*/grace_period_days $MFA_GRACE_PERIOD_DAYS/" /etc/security/pam_ldap_totp.conf
    fi

    # Configure enforcement mode if specified
    if [ -n "$MFA_ENFORCEMENT_MODE" ]; then
      sed -i "s/^enforcement_mode .*/enforcement_mode $MFA_ENFORCEMENT_MODE/" /etc/security/pam_ldap_totp.conf
    fi

    # Configure setup service DN if specified
    if [ -n "$MFA_SETUP_SERVICE_DN" ]; then
      sed -i "s|^setup_service_dn .*|setup_service_dn $MFA_SETUP_SERVICE_DN|" /etc/security/pam_ldap_totp.conf
    fi

    # Enable debug logging if specified
    # Accepts: OTP_LDAP_DEBUG=true or DEBUG=true (for backwards compatibility)
    if [ "$OTP_LDAP_DEBUG" == "true" ] || [ "$DEBUG" == "true" ]; then
      sed -i "s/^debug .*/debug true/" /etc/security/pam_ldap_totp.conf
      echo "pam_ldap_totp: debug logging enabled"
    fi
  else
    echo "pam: enabling LDAP & file-based OTP"
    cp -f /opt/pam.d/openvpn.with-otp /etc/pam.d/openvpn
  fi
else
  echo "pam: enabling LDAP"
  cp -f /opt/pam.d/openvpn.without-otp /etc/pam.d/openvpn
fi
