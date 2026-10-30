# Configure the standalone PAM module for all authentication modes
# The module is used in three scenarios:
# 1. LDAP-backed MFA (MFA_BACKEND=ldap): totp_enabled=true, reads TOTP secrets from LDAP
# 2. File-based MFA (MFA_ENABLED=true, MFA_BACKEND=file): totp_enabled=false, google-authenticator
# 3. LDAP-only (MFA_ENABLED!=true): totp_enabled=false, just LDAP auth

# Values go through ENVIRON rather than sed, so "&", "|" and "\" in them are kept literally
PAM_CONF="${PAM_CONF:-/etc/security/pam_ldap_totp_auth.conf}"
set_pam_conf() {
  KEY="$1" VALUE="$2" awk '$1 == ENVIRON["KEY"] { print ENVIRON["KEY"] " " ENVIRON["VALUE"]; next } { print }' \
    "$PAM_CONF" > "$PAM_CONF.tmp" && cat "$PAM_CONF.tmp" > "$PAM_CONF" && rm -f "$PAM_CONF.tmp"
}

# Configure LDAP connection settings from environment variables
configure_ldap_settings() {
  if [ -n "$LDAP_URI" ]; then
    set_pam_conf ldap_uri "$LDAP_URI"
  fi

  if [ -n "$LDAP_BASE_DN" ]; then
    set_pam_conf ldap_base "$LDAP_BASE_DN"
  fi

  if [ -n "$LDAP_BIND_USER_DN" ]; then
    set_pam_conf ldap_bind_dn "$LDAP_BIND_USER_DN"
  fi

  if [ -n "$LDAP_BIND_USER_PASS" ]; then
    set_pam_conf ldap_bind_password "$LDAP_BIND_USER_PASS"
  fi

  if [ -n "$LDAP_LOGIN_ATTRIBUTE" ]; then
    set_pam_conf login_attribute "$LDAP_LOGIN_ATTRIBUTE"
  fi

  # Configure LDAP filter for group-based access control (v0.2.0+)
  if [ -n "$LDAP_FILTER" ]; then
    set_pam_conf ldap_filter "$LDAP_FILTER"
    echo "pam_ldap_totp_auth: LDAP filter enabled: $LDAP_FILTER"
  fi

  # Configure TLS settings
  if [ "$LDAP_ENCRYPT_CONNECTION" == "starttls" ]; then
    set_pam_conf tls_mode "starttls"
  elif [ "$LDAP_ENCRYPT_CONNECTION" == "on" ]; then
    set_pam_conf tls_mode "ldaps"
  elif [ "$LDAP_ENCRYPT_CONNECTION" == "off" ]; then
    set_pam_conf tls_mode "none"
  fi

  if [ "$LDAP_TLS_VALIDATE_CERT" == "false" ]; then
    set_pam_conf tls_verify_cert "false"
  fi

  if [ -n "$LDAP_TLS_CA_CERT" ]; then
    # Write CA cert to file
    echo "$LDAP_TLS_CA_CERT" > /etc/openvpn/ldap-ca.crt
    set_pam_conf tls_ca_cert_file "/etc/openvpn/ldap-ca.crt"
  fi

  # Enable debug logging if specified
  if [ "${OTP_LDAP_DEBUG,,}" == "true" ] || [ "${DEBUG,,}" == "true" ]; then
    set_pam_conf debug "true"
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
    set_pam_conf totp_enabled "true"

    # Configure MFA/TOTP-specific settings
    # OpenVPN always uses append mode (password+TOTP concatenated)
    set_pam_conf totp_mode "append"

    if [ -n "$MFA_TOTP_ATTRIBUTE" ]; then
      set_pam_conf totp_attribute "$MFA_TOTP_ATTRIBUTE"
    fi

    if [ -n "$MFA_TOTP_PREFIX" ]; then
      set_pam_conf totp_prefix "$MFA_TOTP_PREFIX"
    fi

    if [ -n "$MFA_GRACE_PERIOD_DAYS" ]; then
      set_pam_conf grace_period_days "$MFA_GRACE_PERIOD_DAYS"
    fi

    if [ -n "$MFA_ENFORCEMENT_MODE" ]; then
      set_pam_conf enforcement_mode "$MFA_ENFORCEMENT_MODE"
    fi

    if [ -n "$MFA_SETUP_SERVICE_DN" ]; then
      set_pam_conf setup_service_dn "$MFA_SETUP_SERVICE_DN"
    fi

  else
    # Mode 2: File-based MFA using TOTP (google-authenticator + LDAP password auth)
    echo "pam: enabling file-based MFA (MFA_BACKEND=file, using google-authenticator TOTP)"
    cp -f /opt/pam.d/openvpn.with-otp /etc/pam.d/openvpn

    # Configure LDAP settings
    configure_ldap_settings

    # Disable TOTP validation (module only does LDAP auth)
    set_pam_conf totp_enabled "false"
  fi
else
  # Mode 3: LDAP-only (no MFA)
  echo "pam: enabling LDAP-only authentication (standalone module with totp_enabled=false)"
  cp -f /opt/pam.d/openvpn.without-otp /etc/pam.d/openvpn

  # Configure LDAP settings
  configure_ldap_settings

  # Disable TOTP validation
  set_pam_conf totp_enabled "false"
fi
