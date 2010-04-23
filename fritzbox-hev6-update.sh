#!/bin/sh

NULLIP='0.0.0.0'

if [ "$#" -lt 1 ]; then
	echo "usage: nohup $0 {configfile} >/tmp/v6tunnel.log 2>&1 &" >&2
	exit 1
fi

. "$1"

getpublicip() {
	curl -s -H 'Content-Type: text/xml; charset="utf-8"' \
	  -H 'SOAPAction: urn:schemas-upnp-org:service:WANIPConnection:1#GetExternalIPAddress' \
	  --data-binary '<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:GetExternalIPAddress xmlns:u="urn:schemas-upnp-org:service:WANIPConnection:1" /></s:Body></s:Envelope>' \
	  'http://169.254.1.1:49000/upnp/control/WANCommonIFC1' | \
	  sed -n -e 's#^.*<NewExternalIPAddress>\(.*\)</NewExternalIPAddress>.*$#\1#p'
}

getlocalip() {
	ip -f inet addr show dev "$uplink" scope global | sed -n -e 's/.* inet \([0-9.]*\)\/.*/\1/p' | head -n 1
}

lastpublicip="$NULLIP"

while true; do
	publicip="$(getpublicip)"
	if [ "$publicip" != "$lastpublicip" -a "$publicip" != "$NULLIP" -a -n "$publicip" ]; then
		localip="$(getlocalip)"
		if [ -n "$localip" ]; then
			lastpublicip="$publicip"
			ret="$(curl -k -s "https://ipv4.tunnelbroker.net/ipv4_end.php?ipv4b=$publicip&pass=$md5pass&user_id=$userid&tunnel_id=$tunnelid")"
			echo "$ret"
			if echo "$ret" | grep -q 'has been updated'; then
				modprobe ipv6
				ip tunnel del "$ifname"
				ip tunnel add "$ifname" mode sit remote "$server" local "$localip" ttl 255 &&
				ip link set "$ifname" up &&
				ip addr add "$v6addr" dev "$ifname" &&
				ip route add ::/0 dev "$ifname"
			fi
		fi
	fi
	sleep "$refresh"
done
