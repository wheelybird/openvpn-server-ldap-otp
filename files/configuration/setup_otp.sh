# Configure the standalone PAM module for all authentication modes
# The module is used in three scenarios:
# 1. LDAP-backed MFA (MFA_BACKEND=ldap): totp_enabled=true, reads TOTP secrets from LDAP
# 2. File-based MFA (MFA_ENABLED=true, MFA_BACKEND=file): totp_enabled=false, google-authenticator
# 3. LDAP-only (MFA_ENABLED!=true): totp_enabled=false, just LDAP auth

# Configure LDAP connection settings from environment variables
configure_ldap_settings() {
  if [ -n "$LDAP_URI" ]; then
    sed -i "s|^ldap_uri .*|ldap_uri $LDAP_URI|" /etc/security/pam_ldap_totp_auth.conf
  fi

  if [ -n "$LDAP_BASE_DN" ]; then
    sed -i "s|^ldap_base .*|ldap_base $LDAP_BASE_DN|" /etc/security/pam_ldap_totp_auth.conf
  fi

  if [ -n "$LDAP_BIND_USER_DN" ]; then
    sed -i "s|^ldap_bind_dn.*|ldap_bind_dn $LDAP_BIND_USER_DN|" /etc/security/pam_ldap_totp_auth.conf
  fi

  if [ -n "$LDAP_BIND_USER_PASS" ]; then
    sed -i "s|^ldap_bind_password.*|ldap_bind_password $LDAP_BIND_USER_PASS|" /etc/security/pam_ldap_totp_auth.conf
  fi

  if [ -n "$LDAP_LOGIN_ATTRIBUTE" ]; then
    sed -i "s|^login_attribute .*|login_attribute $LDAP_LOGIN_ATTRIBUTE|" /etc/security/pam_ldap_totp_auth.conf
  fi

  # Configure TLS settings
  if [ "$LDAP_ENCRYPT_CONNECTION" == "starttls" ]; then
    sed -i "s|^tls_mode .*|tls_mode starttls|" /etc/security/pam_ldap_totp_auth.conf
  elif [ "$LDAP_ENCRYPT_CONNECTION" == "on" ]; then
    sed -i "s|^tls_mode .*|tls_mode ldaps|" /etc/security/pam_ldap_totp_auth.conf
  elif [ "$LDAP_ENCRYPT_CONNECTION" == "off" ]; then
    sed -i "s|^tls_mode .*|tls_mode none|" /etc/security/pam_ldap_totp_auth.conf
  fi

  if [ "$LDAP_TLS_VALIDATE_CERT" == "false" ]; then
    sed -i "s|^tls_verify_cert .*|tls_verify_cert false|" /etc/security/pam_ldap_totp_auth.conf
  fi

  if [ -n "$LDAP_TLS_CA_CERT" ]; then
    # Write CA cert to file
    echo "$LDAP_TLS_CA_CERT" > /etc/openvpn/ldap-ca.crt
    sed -i "s|^tls_ca_cert_file .*|tls_ca_cert_file /etc/openvpn/ldap-ca.crt|" /etc/security/pam_ldap_totp_auth.conf
  fi

  # Enable debug logging if specified
  if [ "${OTP_LDAP_DEBUG,,}" == "true" ] || [ "${DEBUG,,}" == "true" ]; then
    sed -i "s/^debug .*/debug true/" /etc/security/pam_ldap_totp_auth.conf
    echo "pam_ldap_totp_auth: debug logging enabled"
  fi
}

#Set up PAM for openvpn - with MFA if it's set as enabled
if [ "${MFA_ENABLED,,}" == "true" ]; then
  if [ "${MFA_BACKEND,,}" == "ldap" ]; then
    # Mode 1: LDAP-backed MFA using TOTP
    echo "pam: enabling LDAP-backed MFA (MFA_BACKEND=ldap, using TOTP)"
    cp -f /opt/pam.d/openvpn.with-ldap-otp /etc/pam.d/openvpn

    # Configure LDAP settings
    configure_ldap_settings

    # Enable TOTP validation
    sed -i "s/^totp_enabled .*/totp_enabled true/" /etc/security/pam_ldap_totp_auth.conf

    # Configure MFA/TOTP-specific settings
    # OpenVPN always uses append mode (password+TOTP concatenated)
    sed -i "s/^totp_mode .*/totp_mode append/" /etc/security/pam_ldap_totp_auth.conf

    if [ -n "$MFA_TOTP_ATTRIBUTE" ]; then
      sed -i "s/^totp_attribute .*/totp_attribute $MFA_TOTP_ATTRIBUTE/" /etc/security/pam_ldap_totp_auth.conf
    fi

    if [ -n "$MFA_TOTP_PREFIX" ]; then
      sed -i "s/^totp_prefix .*/totp_prefix $MFA_TOTP_PREFIX/" /etc/security/pam_ldap_totp_auth.conf
    fi

    if [ -n "$MFA_GRACE_PERIOD_DAYS" ]; then
      sed -i "s/^grace_period_days .*/grace_period_days $MFA_GRACE_PERIOD_DAYS/" /etc/security/pam_ldap_totp_auth.conf
    fi

    if [ -n "$MFA_ENFORCEMENT_MODE" ]; then
      sed -i "s/^enforcement_mode .*/enforcement_mode $MFA_ENFORCEMENT_MODE/" /etc/security/pam_ldap_totp_auth.conf
    fi

    if [ -n "$MFA_SETUP_SERVICE_DN" ]; then
      sed -i "s|^setup_service_dn .*|setup_service_dn $MFA_SETUP_SERVICE_DN|" /etc/security/pam_ldap_totp_auth.conf
    fi

  else
    # Mode 2: File-based MFA using TOTP (google-authenticator + LDAP password auth)
    echo "pam: enabling file-based MFA (MFA_BACKEND=file, using google-authenticator TOTP)"
    cp -f /opt/pam.d/openvpn.with-otp /etc/pam.d/openvpn

    # Configure LDAP settings
    configure_ldap_settings

    # Disable TOTP validation (module only does LDAP auth)
    sed -i "s/^totp_enabled .*/totp_enabled false/" /etc/security/pam_ldap_totp_auth.conf
  fi
else
  # Mode 3: LDAP-only (no MFA)
  echo "pam: enabling LDAP-only authentication (standalone module with totp_enabled=false)"
  cp -f /opt/pam.d/openvpn.without-otp /etc/pam.d/openvpn

  # Configure LDAP settings
  configure_ldap_settings

  # Disable TOTP validation
  sed -i "s/^totp_enabled .*/totp_enabled false/" /etc/security/pam_ldap_totp_auth.conf
fi
