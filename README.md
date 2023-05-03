## OpenVPN container

This will create an OpenVPN server. You can either use LDAP for authentication (with optional 2FA provided by Google Auth) or create a client certificate.   
The container will automatically generate the certificates on the first run (using a 2048 bit key) which means that *the initial run could take several minutes* whilst keys are generated.  The client configuration will be output in the logs.
A volume is created for data persistence.

### A note about compression

Compression is no longer enabled by default for backwards-compatibility.  However the backwards-compatible option `compress migrate` has been added to the server configuration.  This simply allows the server to ignore the client's request for compression.  More information on why compression is disabled can be found [on the OpenVPN website](https://community.openvpn.net/openvpn/wiki/Compression).

## Configuration

Configuration is via environmental variables.  Here's a list, along with the default value in brackets:

### Mandatory settings:

 * `OVPN_SERVER_CN`:  The CN that will be used to generate the certificate and the endpoint hostname the client will use to connect to the OpenVPN server. e.g. `openvpn.example.org`.  Note that changing this when restarting the container will cause the certificates to be regenerated, so you'll need to use the newly generated client configuration.

### Mandatory when `USE_CLIENT_CERTIFICATE` is false (the default):

 * `LDAP_URI`: The URI used to connect to the LDAP server.  e.g. `ldap://ldap.example.org`.
 * `LDAP_BASE_DN`: The base DN used for LDAP lookups. e.g. `dc=example,dc=org`.

---
**Tip**: The LDAP authentication module authenticates the user by searching for their LDAP entry and if it can't return that record authentication fails.  Many LDAP servers don't allow anonymous binds/searches, so set `LDAP_BIND_USER_DN` (and `LDAP_BIND_USER_PASS`) as a user that has permission to search the directory.

---

### Optional settings:

 * `USE_CLIENT_CERTIFICATE` (false): If this is set to `true` then the container will generate a client key and certificate and won't use LDAP (or OTP) for authentication.  See [Using a client certificate](#using_a_client_certificate) for more information.

 * `LDAP_BIND_USER_DN` (_undefined_):  If your LDAP server doesn't allow anonymous binds, use this to specify a user DN to use for lookups.
 * `LDAP_BIND_USER_PASS` (_undefined_): The password for the bind user.
 * `LDAP_FILTER` (`(objectClass=posixAccount)`): A filter to apply to LDAP lookups.  This allows you to limit the lookup results and thereby who will be authenticated.  e.g. `(memberOf=cn=staff,cn=groups,cn=accounts,dc=example,dc=org)`.  See [LDAP authentication filters](#ldap_authentication_filters) for more information.
 * `LDAP_LOGIN_ATTRIBUTE` (uid):  The LDAP attribute used for the authentication lookup, i.e. which attribute is matched to the username when you log into the OpenVPN server.
 * `LDAP_ENCRYPT_CONNECTION` (off): Options:  `on|starttls|off`. This sets the 'ssl' option in nslcd.  `on` will connect to the LDAP server over TLS (SSL).  `starttls` will initially connect unencrypted and negotiate a TLS connection if one is available.  `off` will disable SSL/TLS.
 * `LDAP_TLS` (false):  Changes (overrides) `LDAP_ENCRYPT_CONNECTION` to `starttls` (this setting is for backwards-compatibility with previous versions).
 * `LDAP_TLS_VALIDATE_CERT` (true):  Set to 'true' to ensure the TLS certificate can be validated.  'false' will ignore certificate issues - you might need this if you're using a self-signed certificate and not passing in the CA certificate.
 * `LDAP_TLS_CA_CERT` (_undefined_): The contents of the CA certificate file for the LDAP server.  You'll need this to enable TLS when using self-signed certificates.
 * `LDAP_DISABLE_BIND_SEARCH` (false): Set to 'true' to stop nslcd searching for the user using their own credentials on login. By default nslcd does this as an extra verification step but some LDAP implementations disable searches for unprivileged users by default. Note that you should ensure your LDAP server handles invalid credentials properly before enabling this.

 * `ACTIVE_DIRECTORY_COMPAT_MODE` (false): Sets `LDAP_LOGIN_ATTRIBUTE` to `sAMAccountName` and `LDAP_FILTER` to `(objectClass=user)`, which allows LDAP lookups to work with Active Directory.  This will override any value you've manually set for those settings.

 * `OVPN_TLS_CIPHERS` (TLS-ECDHE-ECDSA-WITH-CHACHA20-POLY1305-SHA256:TLS-ECDHE-RSA-WITH-CHACHA20-POLY1305-SHA256:TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256:TLS-ECDHE-RSA-WITH-AES-128-GCM-SHA256): Determines which ciphers will be set for `tls-cipher` in the openvpn config file.
 * `OVPN_TLS_CIPHERSUITES` (TLS-AES-256-GCM-SHA384:TLS-CHACHA20-POLY1305-SHA256:TLS-AES-128-GCM-SHA256:TLS-AES-128-CCM-8-SHA256:TLS-AES-128-CCM-SHA256): Determines which ciphers will be set for `tls-ciphersuites` in the openvpn config file. (Used for TLS 1.3)
 * `OVPN_PORT` (1194): Sets the port that OpenVPN listens on _inside_ the Docker container.  To get the container to listen on the port too, update the Docker `-p` argument to match (e.g., if you set `OVPN_PORT=1196`, use `-p 1196:1196`).  The client configuration will be set to connect to this port too.
 * `OVPN_PROTOCOL` (udp):  The protocol OpenVPN uses.  Either `udp` or `tcp`.
 * `OVPN_INTERFACE_NAME` (tun):  The name of the network tunnel interface OpenVPN uses.
 * `OVPN_NETWORK` (10.50.50.0 255.255.255.0):  The network that will be used the the VPN in `network_address netmask` format.
 * `OVPN_ROUTES` (_undefined_):  A comma-separated list of routes that OpenVPN will push to the client, in `network_address netmask` format.  e.g. `172.16.10.0 255.255.255.0,172.17.20.0 255.255.255.0`.  If NAT isn't enabled then you'll need to ensure that destinations on the network have the return route set for the OpenVPN network.  The default is to pass all traffic through the VPN tunnel (which will also enable NAT).
 * `OVPN_NAT` (true):  If set to true then the client traffic will be masqueraded by the OpenVPN server.  This allows you to connect to targets on the other side of the tunnel without needing to add return routes to those targets (the targets will see the OpenVPN server's IP rather than the client's).
 * `OVPN_DNS_SERVERS` (_undefined_):  A comma-separated list of DNS nameservers to push to the client.  Set this if the remote network has its own DNS or if you route all traffic through the VPN and the remote side blocks access to external name servers.  Note that not all OpenVPN clients will automatically use these nameservers.  e.g. `8.8.8.8,8.8.4.4`
 * `OVPN_DNS_SEARCH_DOMAIN` (_undefined_):  If using the remote network's DNS server then push the search domain (or domains) to the client.  This will allow the client to lookup by hostnames rather than fully-qualified domain names.  i.e. setting this to `example.org` will allow `ping remotehost` instead of `ping remotehost.example.org`.  Separate multiple domains with commas, e.g. `example.org,wheelybird.com,test.net`.
 * `OVPN_REGISTER_DNS` (false): Include `register-dns` in the client config, which is a Windows client option that can force some clients to load the DNS configuration.
 * `OVPN_IDLE_TIMEOUT` (_undefined_): The number of seconds before an idle VPN connection will be disconnected.  This also prevents the client reconnecting due to a keepalive heartbeat timeout.  You might want to use this setting for compliance reasons (e.g. PCI_DSS).  See [Keepalive settings](#keepalive_settings) for more information.
 * `OVPN_VERBOSITY` (4):  The verbosity of OpenVPN's logs.
 * `OVPN_DEFAULT_SERVER` (true): If true, the OpenVPN `server <network> <netmask>` directive will be generated in the server configuration file. If `false`, you have to configure the server yourself by using `OVPN_EXTRA`.
 * `OVPN_EXTRA` (_undefined_): Additional configuration options which will be appended verbatim to the server configuration.
 * `IPTABLES_EXTRA_FILE` (_undefined_): Path of a file containing additional network rules which will be appended to the iptables configuration. Uses the `iptables-save` / `iptables-restore` syntax.

 * `OVPN_MANAGEMENT_ENABLE` (false): Enable the TCP management interface on port 5555. This service allows raw TCP and telnet connections, check [the OpenVPN documentation](https://openvpn.net/community-resources/management-interface/) for further information.
 * `OVPN_MANAGEMENT_NOAUTH` (false): Allow access to the management interface without any authentication. Note that this option should only be enabled if the management port is not accessible to the internet.
 * `OVPN_MANAGEMENT_PASSWORD` (_undefined_): The password for the management interface. This has to be set if the interface is enabled and the `OVPN_MANAGEMENT_NOAUTH` option is not set. Note that this password is stored in clear-text internally.

 * `REGENERATE_CERTS` (false):  Force the recreation the certificates.
 * `KEY_LENGTH` (2048):  The length of the server key in bits.  Higher is more secure, but will take longer to generate.  e.g. `4096`
 * `DEBUG` (false):  Add debugging information to the logs.
 * `LOG_TO_STDOUT` (true):  Sends *OpenVPN* logs directly to stdout.  If this is set to `false` then the logs are written to `/etc/openvpn/logs/openvpn.log` first, although this file is tailed to stdout once OpenVPN has started.  If `FAIL2BAN_ENABLED` is `true` then this is set to `false` because *fail2ban* needs to be able to parse the *OpenVPN* logs. 
 * `ENABLE_OTP` (false):  Activate two factor authentication using Google Auth.  See [Using OTP](#using_otp) for more information.
 
 * `FAIL2BAN_ENABLED` (false):  Set to `true` to enable the fail2ban daemon (protection against brute force attacks). This will also set `LOG_TO_STDOUT` to `false`.
 * `FAIL2BAN_MAXRETRIES` (3):  The number of attempts that fail2ban allows before banning an ip address.

## Data persistence

Important configuration and data is kept in the container's `/etc/openvpn` directory, so this path should be mounted as a volume or a bind mount.  See the [Docker documentation](https://docs.docker.com/storage/volumes/) for more information.  In the example below, we mount it as a bind mount to a directory on the host.

## Launching the OpenVPN daemon container:  
```
docker run \
           --name openvpn \
           --volume /path/on/host:/etc/openvpn \
           --detach=true \
           -p 1194:1194/udp \
           -e "OVPN_SERVER_CN=myserver.mycompany.com" \
           -e "LDAP_URI=ldap://ldap.mycompany.com" \
           -e "LDAP_BASE_DN=dc=mycompany,dc=com" \
           -e "LDAP_BIND_USER_DN=cn=example,dc=mycompany,dc=com" \
           -e "LDAP_BIND_USER_PASS=examplepass" \
           --cap-add=NET_ADMIN \
           wheelybird/openvpn-ldap-otp:v1.7
```

* `--cap-add=NET_ADMIN` is necessary; the container needs to create the tunnel device and create iptable rules.

* Extract the client configuration (along with embedded certificates) from the running container:
`docker exec -ti openvpn show-client-config`

## Using OTP

If you set `ENABLE_OTP=true` then OpenVPN will be configured to use two-factor authentication: you'll need your LDAP password and a passcode in order to connect.  The passcode is provided by the Google Authenticator app.  You'll need to download that from your app store.   
You need to set up each user with 2FA.  To do this you need to log into the host that's running the OpenVPN container and run   
`docker exec -ti openvpn add-otp-user <username>` where `username` matches the LDAP username.   
Give the generated URL and emergency codes to the user.  To log in the user must append the code generated by Google Authenticator to their password.  So if their password is `verysecurepassword` and the Authenticator code is `934567` then they need to enter `verysecurepassword934567` at the password prompt.   
The server-side OTP configuration is stored under /etc/openvpn, so ensure that's mounted as a volume otherwise the configuration will be lost when the container is restarted.   
Note:  OTP will only work with LDAP and can't be enabled if you're using the client certificate.

## Using a client certificate

Set `USE_CLIENT_CERTIFICATE=true` if you want to use a client certificate instead of LDAP authentication.  This will create a single client key and certificate.  The server will be configured to accept multiple clients using the same certificate.   
This is useful for testing out your VPN server and isn't intended as an especially secure VPN setup.  If you want to use this for purposes other than development then you should read up on the downsides of sharing a single certificate amongst multiple clients.

## Git repository

The Dockerfile and associated assets are available at https://github.com/wheelybird/openvpn-server-ldap-otp

## Fail2ban administration

You can ban or un-ban IP addresses using the `fail2ban-client` command within the running container. For example, running `docker exec -ti openvpn fail2ban-client set openvpn <banip|unbanip> <IPV4 Address>`. You can view the ban logs by running `docker exec -ti openvpn tail -50 /var/log/fail2ban.log`.

## Keepalive settings

The OpenVPN server is configured to send a keepalive ping every ten seconds and to restart the client connection if no reply has been received after a minute.  If you set `OVPN_IDLE_TIMEOUT` then the server will kill the client connection after that many seconds, and the client will be configured to _exit_ instead of restart after a minute of failed pings.  For this reason your client can take up to a minute longer than the configured `OVPN_IDLE_TIMEOUT` timeout value before it exits.

## LDAP authentication filters

You can restrict who can log into the VPN via LDAP filters.  This container uses the `libpam-ldapd` and [nslcd](http://manpages.ubuntu.com/manpages/focal/man5/nslcd.conf.5.html) packages to authenticate against LDAP.  The value of `LDAP_FILTER` will be appended to the user lookup.  So if `LDAP_FILTER` is `memberOf=cn=staff,cn=groups,cn=accounts,dc=example,dc=org` then the filter that `nslcd` will generate is `(&(uid=username)(memberOf=cn=staff,cn=groups,cn=accounts,dc=example,dc=org))`.
`nslcd` defaults to `(objectClass=posixAccount)`, which will therefore create a filter like `(&(uid=username)(objectClass=posixAccount))` if `LDAP_FILTER` is undefined.
