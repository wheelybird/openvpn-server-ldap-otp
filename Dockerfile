FROM centos:6.8

MAINTAINER Brian Lycett <brian@wheelybird.com>

RUN yum -y install epel-release iptables bash nss-pam-ldapd ca-certificates
RUN yum -y install openvpn whatmask fail2ban

EXPOSE 1194/udp

ADD ./files/bin /usr/local/bin
RUN chmod a+x /usr/local/bin/*

ADD ./files/configuration /opt/configuration

# Copy openvpn PAM modules (with and without OTP)
ADD ./files/etc/pam.d/openvpn* /opt/
ADD ./files/easyrsa /opt/easyrsa

# GoOglEs
ADD ./files/google-authenticator/lib64/security/pam_google_authenticator.so /lib64/security/pam_google_authenticator.so
ADD ./files/google-authenticator/usr/bin/google-authenticator /usr/bin/google-authenticator

# Use a volume for data persistence
VOLUME /etc/openvpn

CMD ["/usr/local/bin/entrypoint"]
