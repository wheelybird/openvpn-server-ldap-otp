#Create the VPN tunnel interface

mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
 mknod /dev/net/tun c 10 200
fi

ovpn_net_net=`echo ${OVPN_NETWORK} | awk '{ print $1 }'`
ovpn_net_cidr=`ipcalc -nb ${OVPN_NETWORK} | grep ^Netmask | awk '{ print $NF }'`
ovpn_net="${ovpn_net_net}/${ovpn_net_cidr}"

export this_natdevice=`route | grep '^default' | grep -o '[^ ]*$'`

#Set up routes to push to the client.

if [ "${OVPN_ROUTES}x" != "x" ] ; then

  IFS=","
  read -r -a route_list <<< "$OVPN_ROUTES"

  echo "" >/tmp/routes_config.txt

  for this_route in ${route_list[@]} ; do

   echo "routes: adding route $this_route to server config"
   echo "push \"route $this_route\"" >> /tmp/routes_config.txt

   if [ "$OVPN_NAT" == "true" ]; then
    IFS=" "
    this_net=`echo $this_route | awk '{ print $1 }'`
    this_cidr=`ipcalc -nb $this_route | grep ^Netmask | awk '{ print $NF }'`
    IFS=","
    to_masquerade="${this_net}/${this_cidr}"
    echo "iptables: masquerade from $ovpn_net to $to_masquerade via $this_natdevice"
    iptables -t nat -C POSTROUTING -s "$ovpn_net" -d "$to_masquerade" -o $this_natdevice -j MASQUERADE || \
    iptables -t nat -A POSTROUTING -s "$ovpn_net" -d "$to_masquerade" -o $this_natdevice -j MASQUERADE
   fi

  done

  IFS=" "

else

 #If no routes are set then we'll redirect all traffic from the client over the tunnel.

 echo "push \"redirect-gateway def1\"" >> /tmp/routes_config.txt
 echo "iptables: masquerade from $ovpn_net to everywhere via $this_natdevice"

 if [ "$OVPN_NAT" == "true" ]; then
  iptables -t nat -C POSTROUTING -s "$ovpn_net" -o $this_natdevice -j MASQUERADE || \
  iptables -t nat -A POSTROUTING -s "$ovpn_net" -o $this_natdevice -j MASQUERADE
 fi

fi

# Append extra iptables rules from a file if specified
if [ "${IPTABLES_EXTRA_FILE}x" != "x" ] ; then

 if [ -f "$IPTABLES_EXTRA_FILE" ]; then
  echo "IPTABLES_EXTRA_FILE was set, appending iptables rules from $IPTABLES_EXTRA_FILE"
  iptables-restore -nv "$IPTABLES_EXTRA_FILE"
 else
  echo "IPTABLES_EXTRA_FILE was set but the specified file $IPTABLES_EXTRA_FILE cannot be found!"
 fi

fi