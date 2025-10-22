FROM ubuntu:24.04

LABEL org.opencontainers.image.authors="wheelybird@wheelybird.com"

RUN apt-get update && apt-get install -y --no-install-recommends wget ca-certificates gnupg curl && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
            easy-rsa \
            fail2ban \
            ipcalc \
            iptables \
            ldap-utils \
            libpam-google-authenticator \
            libpam-ldapd \
            libnss-ldapd \
            liboath0 \
            net-tools \
            nslcd \
            openssl \
            openvpn && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir /opt/easyrsa && \
    cp -rp /usr/share/easy-rsa/x509-types /opt/easyrsa/ && \
    cp -rp /usr/share/easy-rsa/easyrsa /opt/easyrsa/

# Build and install LDAP-backed TOTP PAM module from source
# PAM module maintained at: https://github.com/wheelybird/ldap-totp-pam
# This enables append mode authentication (password+OTP concatenated) with security hardening
ARG PAM_MODULE_VERSION=main
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        git \
        build-essential \
        gcc \
        make \
        libpam0g-dev \
        libldap2-dev \
        liboath-dev && \
    # Clone and build PAM module from source
    cd /tmp && \
    git clone --depth 1 --branch ${PAM_MODULE_VERSION} https://github.com/wheelybird/ldap-totp-pam.git && \
    cd ldap-totp-pam && \
    make clean && \
    make && \
    # Install the compiled module
    install -D -m 0644 pam_ldap_totp.so /lib/security/pam_ldap_totp.so && \
    # Cleanup build dependencies and source
    cd / && \
    rm -rf /tmp/ldap-totp-pam && \
    apt-get purge -y git build-essential gcc make libpam0g-dev libldap2-dev liboath-dev && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 1194/udp
EXPOSE 5555/tcp

ADD ./files/bin /usr/local/bin
RUN chmod a+x /usr/local/bin/*
ADD ./files/configuration /opt/configuration
ADD ./files/etc/pam.d/openvpn* /opt/pam.d/
ADD ./files/etc/security/pam_ldap_totp.conf /etc/security/pam_ldap_totp.conf
ADD ./files/easyrsa/* /opt/easyrsa/

VOLUME /etc/openvpn

CMD ["/usr/local/bin/entrypoint"]

