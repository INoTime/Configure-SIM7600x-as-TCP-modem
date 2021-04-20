#!/bin/bash
# https://github.com/elementzonline/GSMModem/blob/master/SIM7600/mbim-set-ip/mbim-set-ip

if [ "$EUID" -ne 0 ]
  then echo "Run as root"
  exit
fi

ipv4_addresses=()
ipv4_gateway=""
ipv4_dns=()
ipv4_mtu=""
ipv6_addresses=()
ipv6_gateway=""
ipv6_dns=()
ipv6_mtu=""

#CONTROL-IFACE
CONTROLDEV="$1"
#WWAN-IFACE
DEV="$2"

echo "Requesting IPv4 and IPv6 information through mbimcli proxy:"
mbimcli -d $CONTROLDEV -p --query-ip-configuration
IPDATA=$(mbimcli -d $CONTROLDEV -p --query-ip-configuration=0)

# get ip address
function parse_ip {
	local line_re="IP \[([0-9]+)\]: '(.+)'"
	local input=$1
	if [[ $input =~ $line_re ]]; then
		local ip_cnt=${BASH_REMATCH[1]}
		local ip=${BASH_REMATCH[2]}
	fi
	echo "$ip"
}

# get gateway
function parse_gateway {
	local line_re="Gateway: '(.+)'"
	local input=$1
	if [[ $input =~ $line_re ]]; then
		local gw=${BASH_REMATCH[1]}
	fi
	echo "$gw"
}

# get DNS
function parse_dns {
	local line_re="DNS \[([0-9]+)\]: '(.+)'"
	local input=$1
	if [[ $input =~ $line_re ]]; then
		local dns_cnt=${BASH_REMATCH[1]}
		local dns=${BASH_REMATCH[2]}
	fi
	echo "$dns"
}

# get MTU
function parse_mtu {
	local line_re="MTU: '([0-9]+)'"
	local input=$1
	if [[ $input =~ $line_re ]]; then
		local mtu=${BASH_REMATCH[1]}
	fi
	echo "$mtu"
}
while read -r line || [[ -n "$line" ]] ; do
	[ -z "$line" ] && continue
	case "$line" in
		*"IPv4 configuration available: 'none'"*)
		       	state="start"
		        continue
			;;
		*"IPv4 configuration available"*)
			state="ipv4"
			continue
			;;
		*"IPv6 configuration available: 'none'"*)
		        state="start"
		        continue
			;;
		*"IPv6 configuration available"*)
			state="ipv6"
			continue
			;;
		*)
			;;
	esac
	case "$state" in
		"ipv4")

			case "$line" in
			*"IP"*)
				row=$(parse_ip "$line")
				ipv4_addresses+=("$row")
			        continue
				;;
			*"Gateway"*)
				row=$(parse_gateway "$line")
				ipv4_gateway="$row"
				continue
				;;
			*"DNS"*)
				row=$(parse_dns "$line")
				ipv4_dns+=("$row")
				continue
				;;
			*"MTU"*)
				row=$(parse_mtu "$line")
				ipv4_mtu="$row"
				continue
				;;
			*)
				;;
			esac
			;;

		"ipv6")
			case "$line" in
			*"IP"*)
				row=$(parse_ip "$line")
				ipv6_addresses+=("$row")
			        continue
				;;
			*"Gateway"*)
				row=$(parse_gateway "$line")
				ipv6_gateway="$row"
				continue
				;;
			*"DNS"*)
				row=$(parse_dns "$line")
				ipv6_dns+=("$row")
				continue
				;;
			*"MTU"*)
				row=$(parse_mtu "$line")
				ipv6_mtu="$row"
				continue
				;;
			*)
				continue
				;;
			esac
		;;
	*)
		continue
	;;
	esac
done <<< "$IPDATA"

execfile=$(mktemp)

printf "ip link set $DEV down\n" >> $execfile
printf "ip addr flush dev $DEV \n" >> $execfile
printf "ip -6 addr flush dev $DEV \n" >> $execfile
printf "ip link set $DEV up\n" >> $execfile

if [[ "${#ipv4_addresses[@]}" > 0 ]]; then
	printf "ip addr add %s dev $DEV broadcast +\n" "${ipv4_addresses[@]}" >> $execfile
	printf "ip route add default via $ipv4_gateway dev $DEV\n" >> $execfile

	if [ -n "$ipv4_mtu" ]; then
		printf "ip link set mtu $ipv4_mtu dev $DEV \n" >> $execfile
	fi
	if [[ "${#ipv4_dns[@]}" > 0 ]]; then
		printf "systemd-resolve -4 --interface=$DEV --set-dns=%s\n" "${ipv4_dns[@]}" >>$execfile
	fi
fi

if [[ "${#ipv6_addresses[@]}" > 0 ]]; then
	printf "ip -6 addr add %s dev $DEV\n" "${ipv6_addresses[@]}" >> $execfile
	printf "ip -6 route add default via $ipv6_gateway dev $DEV\n" >> $execfile
	if [ -n "$ipv6_mtu" ]; then
		printf "ip -6 link set mtu $ipv6_mtu dev $DEV\n" >> $execfile
	fi
	if [[ "${#ipv6_dns[@]}" > 0 ]]; then
		printf "systemd-resolve -6 --interface=$DEV --set-dns=%s\n" "${ipv6_dns[@]}" >>$execfile
	fi
fi
echo "Applying the following network interface configurations:"
cat $execfile
bash $execfile
rm $execfile
echo "Network interface configurations completed."