docker run --name openvpn --volume openvpn-data:/etc/openvpn --detach=true -p 1194:1194/udp -e "OVPN_SERVER_CN=vpn.mgmt.sonet.local" -e "LDAP_URI=ldap://172.31.45.7" -e "LDAP_BASE_DN=dc=testad,dc=sonet,dc=local" -e "LDAP_LOGIN_ATTRIBUTE=sAMAccountName" -e "LDAP_BIND_USER_DN=CN=Admin,OU=Users,OU=testad,DC=testad,DC=sonet,DC=local" -e 'LDAP_BIND_USER_PASS=P4ssw0rd!!' -e "ENABLE_OTP=true" -e "OVPN_DNS_SERVERS=172.31.0.2" --cap-add=NET_ADMIN gitlab.mgmt.sonet.local:4567/testing/openvpn:latest

Admin user should be replaced with a read only ldapbind service account in AD.
Users must then be added into sonets active directory
LDAP_FILTER should also be set to limit users to a group ie memberOf=cn=vpnusers,cn=groups,cn=testad,dc=testad,dc=sonet,dc=local
OVPN_DNS_SERVERS needs setting to point to the AWS resolvers
OVPN_DNS_SEARCH_DOMAIN needs setting so short name resolution works
OVPN_ROUTES should be set and OVPN_NAT set to true for split tunnel, otherwise allow 'internet' access for VPN clients

openvpn-data volume needs to be backed up and available to any docker host the container may run on



openvpn connect client on mac doesnt look to work, by default it tries to talk to 443/tcp to download the config...if you export the config and import, its missing some option...tunnelblick and pritunl work so looks to be the client



docker run --name openvpn --volume openvpn-data:/etc/openvpn --detach=true -p 1194:1194/udp -e "OVPN_SERVER_CN=vpn.mgmt.sonet.local" -e "LDAP_URI=ldap://172.31.45.7" -e "LDAP_BASE_DN=dc=testad,dc=sonet,dc=local" -e "LDAP_LOGIN_ATTRIBUTE=sAMAccountName" -e "LDAP_BIND_USER_DN=CN=Admin,OU=Users,OU=testad,DC=testad,DC=sonet,DC=local" -e 'LDAP_BIND_USER_PASS=P4ssw0rd!!' -e "ENABLE_OTP=true" -e "OVPN_DNS_SERVERS=172.31.0.2" -e 'LDAP_FILTER=(&(objectClass=user)(!(objectClass=computer)))' --cap-add=NET_ADMIN gitlab.mgmt.sonet.local:4567/testing/openvpn:centos72
