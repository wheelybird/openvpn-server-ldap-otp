## OpenVPN container

This will create an OpenVPN server. You can either use LDAP for authentication (with optional 2FA provided by Google Auth) or create a client certificate.   
The container will automatically generate the certificates on the first run (using a 2048 bit key) which means that *the initial run could take several minutes* whilst keys are generated.  The client configuration will be output in the logs.
A volume is created for data persistence.

Configuration is via environmental variables.  Here's a list, along with the default value in brackets:

#### Mandatory settings:

 * `OVPN_SERVER_CN`:  The CN that will be used to generate the certificate and the endpoint hostname the client will use to connect to the OpenVPN server. e.g. `openvpn.example.org`.

#### Mandatory when `USE_CLIENT_CERTIFICATE` is false (the default):

 * `LDAP_URI`: The URI used to connect to the LDAP server.  e.g. `ldap://ldap.example.org`.
 * `LDAP_BASE_DN`: The base DN used for LDAP lookups. e.g. `dc=example,dc=org`.


#### Optional settings:

 * `USE_CLIENT_CERTIFICATE` (_false_): If this is set to `true` then the container will generate a client key and certificate and won't use LDAP (or OTP) for authentication.  See _Using a client certificate_ below for more information.
 
 * `LDAP_BIND_USER_DN` (_undefined_):  If your LDAP server doesn't allow anonymous binds, use this to specify a user DN to use for lookups.
 * `LDAP_BIND_USER_PASS` (_undefined_): The password for the bind user.
 * `LDAP_FILTER` (_undefined_): A filter to apply to LDAP lookups.  This allows you to limit the lookup results and thereby who will be authenticated.  e.g. `memberOf=cn=staff,cn=groups,cn=accounts,dc=example,dc=org`
 * `LDAP_SEARCH_ATTRIBUTE` (uid):  The LDAP attribute used for the authentication lookup, i.e. which attribute is matched to the username when you log into the OpenVPN server.
 * `LDAP_TLS` (false):  Set to 'true' to enable a TLS connection to the LDAP server.
 * `LDAP_TLS_CA_CERT` (_undefined_): The contents of the CA certificate file for the LDAP server.  You'll need this to enable TLS if using self-signed certificates.

 * `OVPN_TLS_CIPHERS` (TLS-DHE-RSA-WITH-AES-256-CBC-SHA): Determines which ciphers will be set for `tls-config` in the openvpn config file.
 * `OVPN_PROTOCOL` (udp):  The protocol OpenVPN uses.  Either `udp` or `tcp`.
 * `OVPN_NETWORK` (10.50.50.0 255.255.255.0):  The network that will be used the the VPN in `network_address netmask` format.
 * `OVPN_ROUTES` (_undefined_):  A comma-separated list of routes that OpenVPN will push to the client, in `network_address netmask` format.  e.g. `172.16.10.0 255.255.255.0,172.17.20.0 255.255.255.0`.  If NAT isn't enabled then you'll need to ensure that destinations on the network have the return route set for the OpenVPN network.  The default is to pass all traffic through the VPN tunnel (which will also enable NAT).
 * `OVPN_NAT` (true):  If set to true then the client traffic will be masqueraded by the OpenVPN server.  This allows you to connect to targets on the other side of the tunnel without needing to add return routes to those targets (the targets will see the OpenVPN server's IP rather than the client's).
 * `OVPN_DNS_SERVERS` (_undefined_):  A comma-separated list of DNS nameservers to push to the client.  Set this if the remote network has its own DNS or if you route all traffic through the VPN and the remote side blocks access to external name servers.  Note that not all OpenVPN clients will automatically use these nameservers.  e.g. `8.8.8.8,8.8.4.4`
 * `OVPN_DNS_SEARCH_DOMAIN` (_undefined_):  If using the remote network's DNS servers, push a search domain.  This will allow you to lookup by hostnames rather than fully-qualified domain names.  i.e. setting this to `example.org` will allow `ping remotehost` instead of `ping remotehost.example.org`.
 * `OVPN_VERBOSITY` (4):  The verbosity of OpenVPN's logs.

 * `REGENERATE_CERTS` (false):  Force the recreation the certificates.
 * `KEY_LENGTH` (2048):  The length of the server key in bits.  Higher is more secure, but will take longer to generate.  e.g. `4096`
 * `DEBUG` (false):  Add debugging information to the logs.
 * `ENABLE_OTP` (false):  Activate two factor authentication using Google Auth.  See _Using OTP_ below for more information.


#### Launching the OpenVPN daemon container:  
```
docker run \
           --name openvpn \
           --volume /path/on/host:/etc/openvpn \
           --detach=true \
           -p 1194:1194/udp \
           -e "OVPN_SERVER_CN=myserver.mycompany.com" \
           -e "LDAP_URI=ldap://ldap.mycompany.com" \
           -e "LDAP_BASE_DN=dc=mycompany,dc=com" \
           --cap-add=NET_ADMIN \
           wheelybird/openvpn-ldap-otp
```

* `--cap-add=NET_ADMIN` is necessary; the container needs to create the tunnel device and create iptable rules.

* Extract the client configuration (along with embedded certificates) from the running container:
`docker exec -ti openvpn show-client-config`


#### Using OTP

If you set `ENABLE_OTP=true` then OpenVPN will be configured to use two-factor authentication: you'll need your LDAP password and a passcode in order to connect.  The passcode is provided by the Google Authenticator app.  You'll need to download that from your app store.   
You need to set up each user with 2FA.  To do this you need to log into the host that's running the OpenVPN container and run   
`docker exec -ti openvpn add-otp-user <username>` where `username` matches the LDAP username.   
Give the generated URL and emergency codes to the user.  To log in the user must append the code generated by Google Authenticator to their password.  So if their password is `verysecurepassword` and the Authenticator code is `934567` then they need to enter `verysecurepassword934567` at the password prompt.   
The server-side OTP configuration is stored under /etc/openvpn, so ensure that's a volume otherwise the configuration will be lost if the container is restarted.   
Note:  OTP will only work with LDAP and can't be enabled if you're using the client certificate.

#### Using a client certificate

Set `USE_CLIENT_CERTIFICATE=true` if you want to use a client certificate instead of LDAP authentication.  This will create a single client key and certificate.  The server will be configured to accept multiple clients using the same certificate.   
This is useful for testing out your VPN server and isn't intended as an especially secure VPN setup.  If you want to use this for purposes other than development then you should read up on the downsides of sharing a single certificate amongst multiple clients.

#### Git repository

The Dockerfile and associated assets are available at:
https://github.com/wheelybird/openvpn-server-ldap-otp
