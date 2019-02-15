#!/bin/bash

# -------------------------------------------------------------------------
# mapShares - mount CIFS shares according to AD group membership
# Coypright: © 2015 by Karsten Müller · IT-Beratung (info@kamueller.de)
# -------------------------------------------------------------------------

USER=$(whoami)
FILER_NAME="sv-fs1"
FILER_PATH="//${USER}@${FILER_NAME}"

# -------------------------------------------------------------------------
# functions
# -------------------------------------------------------------------------
tmp=$(mktemp /tmp/mapShares.XXXX)

function log(){
	log=$1
	/usr/bin/logger -s -t de.kamueller.mapShares "$log"
}

function exec() {
	local cmd=$1
	[ -n "$debug" ] && log "CMD: $cmd"
	if ! eval $cmd > $tmp 2>&1; then
		"error cmd '$cmd': $(cat $tmp)"
		return 1
	fi
}

function mapshare(){
	local rpath=$1
	local lpath=$2
	log "mapping share ${rpath} -> ${lpath}"
	/sbin/umount $lpath >/dev/null 2>&1
	exec "/bin/mkdir -p $lpath"
	exec "/bin/chmod a+rwx $lpath"
	exec "/sbin/mount -t smbfs $rpath $lpath"
}

function myexit(){
	log "Exiting with status $1"
	/bin/rm -f $tmp
	/sbin/umount /Volumes/Netlogon >/dev/null 2>&1
	exit $1
}

# -------------------------------------------------------------------------
# MAIN
# -------------------------------------------------------------------------
AD_GROUPS=$(/usr/bin/id -G -n)
AD_DOMAIN_NODE=$(dscl localhost -list "/Active Directory" | head -n 1)

# check filer
if ! ping -t 5 -c 1 $FILER_NAME | grep 'round-trip' >/dev/null; then
	log "No ping response from '$FILER_NAME'"; myexit 1
fi

mapshare //${AD_DOMAIN_NODE}/Netlogon/Macs /Volumes/Netlogon

# get a list of share mappings
file=/Library/Management/mapShares/read_ini.sh
if [ -r $file ]; then
  exec ". $file"
else
  log "Can not read file '$file'"; myexit 1
fi

file="/Volumes/Netlogon/mapShares.ini"
if [ -r $file ]; then
  if ! exec "read_ini $file -p MAP"; then
    log "read_ini failed for file '$file'"; myexit 1
  fi
else
  log "Can not read file '$file'"; myexit 1
fi

log "Start mapping shares for groups $AD_GROUPS"
for group in $AD_GROUPS; do
	if ! echo $group | grep $AD_DOMAIN_NODE >/dev/null; then
		log "skipping group $group"
		continue
	fi
	# section name rewriting
	search=$(echo $group | sed -e "s/$AD_DOMAIN_NODE\\\//" -e 's/-/_/g' -e 's/ /___/g' | tr A-Z a-z)
	for var in $MAP__ALL_VARS; do
		#echo "$var :: MAP__${search}__"
		if echo $var | egrep "^MAP__${search}__" >/dev/null; then
			log "found section name $search"
			value=$(eval echo \$$var)
			#echo "var: $var value:: $value"
			rpath=$(echo $value | cut -f1 -d:); lpath=$(echo $value| cut -f2 -d:)
		    exec "mapshare ${FILER_PATH}${rpath} ${lpath}"
		fi
	done
done
log "End mapping shares for user $USER"

/sbin/umount /Volumes/Netlogon >/dev/null 2>&1

## show servers on desktop
if [ X$(/usr/bin/defaults read com.apple.finder ShowMountedServersOnDesktop 2>/dev/null) != "X1" ]; then
	/usr/bin/defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
	/usr/bin/killall Finder
fi

# Is this real? (Wipers)
myexit 0
