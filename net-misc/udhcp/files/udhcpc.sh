#!/bin/sh
# udhcp setup script

# Ideally this should be the defalt udhcpc script, but I doubt upstream
# will accept it.

PATH=/bin:/usr/bin:/sbin:/usr/sbin

update_dns()
{
	[ -n "${PEER_DNS}" ] && [ "${PEER_DNS}" != "yes" ] && return
	[ -z "${domain}" ] && [ -z "${dns}" ] && return

	conf="# Generated by udhcpc for ${interface}\n"
	[ -n "${domain}" ] && conf="${conf}search ${domain}\n"
	for i in ${dns} ; do
		conf="${conf}nameserver ${i}\n"
	done
	if [ -x /sbin/resolvconf ] ; then
		printf "${conf}" | resolvconf -a ${interface}
	else
		printf "${conf}" > /etc/resolv.conf
		chmod 644 /etc/resolv.conf
	fi
}

update_ntp() {
	[ -n "${PEER_NTP}" ] && [ "${PEER_NTP}" != "yes" ] && return
	[ -z "${ntpsrv}" ] && return
	
	conf="# Generated by udhcpc for interface ${interface}\n"
	conf="${conf}restrict default noquery notrust nomodify\n"
	conf="${conf}restrict 127.0.0.1\n"
	for i in ${ntpsrv} ; do
		conf="${conf}restrict ${i} nomodify notrap noquery\n"
		conf="${conf}server ${i}\n"
	done
	conf="${conf}driftfile /var/lib/ntp/ntp.drift\n"
	conf="${conf}logfile /var/log/ntp.log\n"
	printf "${conf}" > /etc/ntp.conf
	chmod 644 /etc/ntp.conf
}

update_hostname() {
	[ -n "${PEER_HOSTNAME}" ] && [ "${PEER_HOSTNAME}" != "yes" ] && return
	[ -z "${hostname}" ] && return

	myhost="$(hostname)"
	[ -z "${myhost}" ] || [ "${myhost}" = "(none)" ] && hostname "${hostname}"
}

update_interface()
{
	[ -n "${broadcast}" ] && broadcast="broadcast ${broadcast}"
	[ -n "${subnet}" ] && netmask="netmask ${subnet}"
	[ -n "${mtu}" ] && mtu="mtu ${mtu}"
	ifconfig "${interface}" ${ip} ${broadcast} ${netmask} ${mtu}
}

update_routes()
{
	while route del default dev "${interface}" 2>/dev/null ; do
		:
	done
        
	[ -n "${PEER_ROUTERS}" ] && [ "${PEER_ROUTERS}" != "yes" ] && return
	
	if [ -n "${router}" ] ; then
		metric=
		[ -n "${IF_METRIC}" ] && metric="metric ${IF_METRIC}"
		for i in ${router} ; do
			route add default gw "${i}" ${metric} dev "${interface}"
		done
	fi
}

deconfig()
{
	ifconfig "${interface}" 0.0.0.0
	[ -x /sbin/resolvconf ] && resolvconf -d "${interface}"
}

case "$1" in
	bound|renew)
		update_hostname
		update_interface
		update_routes
		update_dns
		update_ntp
		;;
	deconfig|leasefail)
		deconfig
		;;
	nak)
		echo "nak: ${message}"
		;;
	*)
		echo "unknown option $1" >&2
		echo "Usage: $0 {bound|deconfig|leasefail|nak|renew}" >&2
		exit 1
		;;
esac

exit 0

# vim: ts=4 :
