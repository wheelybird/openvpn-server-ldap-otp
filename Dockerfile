FROM ubuntu:22.04

MAINTAINER Brian Lycett <brian@wheelybird.com>

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
            easy-rsa \
            fail2ban \
            ipcalc \
            iptables \
            libpam-google-authenticator \
            libpam-ldapd \
            net-tools \
            nslcd \
            openssl \
            openvpn && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir /opt/easyrsa && \
    cp -rp /usr/share/easy-rsa/x509-types /opt/easyrsa/ && \
    cp -rp /usr/share/easy-rsa/easyrsa /opt/easyrsa/

EXPOSE 1194/udp
EXPOSE 5555/tcp

ADD ./files/bin /usr/local/bin
RUN chmod a+x /usr/local/bin/*
ADD ./files/configuration /opt/configuration
ADD ./files/etc/pam.d/openvpn* /opt/
ADD ./files/easyrsa/* /opt/easyrsa/

# Use a volume for data persistence
VOLUME /etc/openvpn

CMD ["/usr/local/bin/entrypoint"]

