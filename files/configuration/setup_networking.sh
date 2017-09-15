#Create the VPN tunnel interface

mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi


#Set up routes to push to the client and create NAT rules for those
#routes if NAT is required.

network_addr=`whatmask ${OVPN_NETWORK} | grep 'IP Entered' | awk '{ print $5 }'`
cidr=`whatmask ${OVPN_NETWORK} | grep 'CIDR' | awk '{ print $4 }'`

#first_ip=`whatmask ${OVPN_NETWORK} | grep 'First Usable IP Address' | awk '{ print $7 }'`
#netmask=`whatmask ${OVPN_NETWORK} | grep 'Netmask =' | awk '{ print $4 }'`

export this_ovpn_network="$network_addr$cidr"
export this_natdevice=`route | grep '^default' | grep -o '[^ ]*$'`

if [ "${OVPN_ROUTES}x" != "x" ] ; then 

  FS=',' read -r -a routes <<< "$OVPN_ROUTES"

  echo "" >/tmp/routes_config.txt

  for this_route in $route_list ; do
   this_ip=`whatmask $this_route | grep 'IP Entered' | awk '{ print $5 }'`
   this_cidr=`whatmask $this_route | grep 'CIDR' | awk '{ print $4 }'`
   echo "$this_ip$this_cidr"
   OVPN_ROUTES+=("$this_ip$this_cidr")
   echo "push route \"$this_route\"" >> /tmp/ovpn_routes.txt
  done


  if [ "$OVPN_NAT" == "true" ]; then

   #echo 1 > /proc/sys/net/ipv4/ip_forward

   iptables -t nat -C POSTROUTING -s $this_ovpn_network -o $this_natdevice -j MASQUERADE || iptables -t nat -A POSTROUTING -s $this_ovpn_network -o $this_natdevice -j MASQUERADE

   for i in "${routes[@]}"; do
    iptables -t nat -C POSTROUTING -s "$i" -o $this_natdevice -j MASQUERADE || iptables -t nat -A POSTROUTING -s "$i" -o $this_natdevice -j MASQUERADE
   done


  fi

else

 #If no routes are set then we'll redirect all traffic from the client over the tunnel.
 #This means that we'll set up NAT regardless of whether OVPN_NAT is set to false.

 echo "push \"redirect-gateway def1\"" >> /tmp/ovpn_routes.txt
 #echo 1 > /proc/sys/net/ipv4/ip_forward
 
 iptables -t nat -C POSTROUTING -s $this_ovpn_network -o $this_natdevice -j MASQUERADE || iptables -t nat -A POSTROUTING -s $this_ovpn_network -o $this_natdevice -j MASQUERADE 

fi
