# =============================================================================
# Build Stage: Compile PAM LDAP TOTP module from GitHub release
# =============================================================================
FROM ubuntu:24.04 AS builder

ARG PAM_MODULE_VERSION=0.1.3

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
        build-essential \
        gcc \
        make \
        libpam0g-dev \
        libldap2-dev \
        liboath-dev && \
    rm -rf /var/lib/apt/lists/*

RUN wget -O /tmp/pam-ldap-totp-auth.tar.gz \
        "https://github.com/wheelybird/pam-ldap-totp-auth/archive/refs/tags/v${PAM_MODULE_VERSION}.tar.gz" && \
    tar -xzf /tmp/pam-ldap-totp-auth.tar.gz -C /tmp && \
    cd /tmp/pam-ldap-totp-auth-${PAM_MODULE_VERSION} && \
    make clean && \
    make && \
    install -D -m 0644 pam_ldap_totp_auth.so /build/pam_ldap_totp_auth.so

# =============================================================================
# Runtime Stage: OpenVPN server with compiled PAM module
# =============================================================================
FROM ubuntu:24.04

LABEL org.opencontainers.image.authors="wheelybird@wheelybird.com"
LABEL org.opencontainers.image.description="OpenVPN server with LDAP and TOTP authentication"
LABEL org.opencontainers.image.source="https://github.com/wheelybird/openvpn-server-ldap-otp"

# Install runtime dependencies only (no build tools)
# Note: liboath0 was renamed to liboath0t64 on some architectures (Debian's 64-bit time_t transition)
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
        gnupg \
        curl \
        easy-rsa \
        fail2ban \
        ipcalc \
        iptables \
        ldap-utils \
        libpam-google-authenticator \
        net-tools \
        openssl \
        openvpn \
        pamtester && \
    (apt-get install -y --no-install-recommends liboath0 || \
     apt-get install -y --no-install-recommends liboath0t64) && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir /opt/easyrsa && \
    cp -rp /usr/share/easy-rsa/x509-types /opt/easyrsa/ && \
    cp -rp /usr/share/easy-rsa/easyrsa /opt/easyrsa/

COPY --from=builder /build/pam_ldap_totp_auth.so /lib/security/pam_ldap_totp_auth.so

EXPOSE 1194/udp
EXPOSE 5555/tcp

ADD ./files/bin /usr/local/bin
RUN chmod a+x /usr/local/bin/*
ADD ./files/configuration /opt/configuration
ADD ./files/etc/pam.d/openvpn* /opt/pam.d/
ADD ./files/etc/security/pam_ldap_totp_auth.conf /etc/security/pam_ldap_totp_auth.conf
ADD ./files/easyrsa/* /opt/easyrsa/

VOLUME /etc/openvpn

CMD ["/usr/local/bin/entrypoint"]
