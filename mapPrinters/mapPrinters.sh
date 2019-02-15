#!/bin/bash

# -------------------------------------------------------------------------
# mapPrinters - add a printer based on hostname
# Coypright: © 2015 by Karsten Müller · IT-Beratung (info@kamueller.de)
# -------------------------------------------------------------------------
COMPUTER_ID=$(/usr/sbin/scutil --get LocalHostName)

# -------------------------------------------------------------------------
# functions
# -------------------------------------------------------------------------
tmp=$(mktemp /tmp/mapPrinters.XXXX)

function log(){
	log=$1
	/usr/bin/logger -s -t de.kamueller.mapPrinters "$log"
}

function exec() {
	local cmd=$1
	if [ -n "$debug" ]; then
		log "CMD: $cmd"
	else
		if ! eval $cmd > $tmp 2>&1; then
			"error cmd '$cmd': $(cat $tmp)"
			return 1
		fi
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

function mapprinter(){
	local name="$1"
	local description="$2"
	local location="$3"
	local ppdfile="$4"
	local server="$5"
	log "mapping printer name: '$name' description: '$description' location: '$location' ppdfile: '$ppdfile' server: '$server'"
	local device_uri="$server/$name"
	# Remove printer if it exists
	if /usr/bin/lpstat -p $name > /dev/null 2>&1; then
		exec "/usr/sbin/lpadmin -x '$name'"
	fi
	# Install the printer
	exec "/usr/sbin/lpadmin -p '$name' -L '$location' -D '$location $description' -v '$device_uri' -P '$ppdfile'  -o printer-is-shared=false -E"
	# Enable and start the printers on the system (after adding the printer initially it is paused).
	exec "/usr/sbin/cupsenable '$(lpstat -p | grep -Ewi "drucker|printer" | awk '{print $2}' | sed -e 's/„//g' -e 's/“//g')'"
	[ -n "$dialog" -a -n "$description" ] && notify "mapPrinters: Drucker bereit" "$location $description"
}

function dialog() {
	local response="${1:-"Response..."}"
	local timeout=60
    local answer=$(osascript 2>&1 << EOT
        tell application "System Events"
            activate
            set charcount to 0
            with timeout of $timeout seconds
            repeat while ((charcount < 2) or (charcount > 10))
            	set response to text returned of (display dialog "$1" default answer "$2" giving up after $timeout)
            	set charcount to (count response)
            end repeat
            end timeout
            return response as string
        end tell
    EOT)
	answer=$(printf '%q' $answer)
	if echo $answer | grep -Ei "usercanceled|executionerror" >/dev/null; then
		return 1
	fi
    echo $answer
}

function notify() {
	osascript -e "display notification \"$2\" with title \"$1\"" &
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
# testing: mapPrinters.sh local_ini hostname
[ -n "$1" -o -n "$2" ] && debug=$3

# mount the AD servers netlogon share
if [ -z "$1" ]; then
	AD_DOMAIN_NODE=$(dscl localhost -list "/Active Directory" | head -n 1)
	mapshare //${AD_DOMAIN_NODE}/Netlogon/Macs /Volumes/Netlogon
fi

# get a list of share mappings with read_ini
source /Library/Management/mapPrinters/read_ini.sh || myexit 1
file=${1:-/Volumes/Netlogon/mapPrinters.ini}
read_ini $file -p MAP || myexit 1

# hostname: lowercase, all " " and "-" are replaces by "_"
hostname=${2:-$(echo $COMPUTER_ID | sed -e 's/-/_/g' -e 's/ /_/g' | tr A-Z a-z)}

unset sections
for section in $MAP__ALL_SECTIONS; do
	echo $section | grep -i "TEMPLATE" >/dev/null && continue
	name="$section\t($(eval echo \$MAP__${section}__location) - $(eval echo \$MAP__${section}__description))"
	names="$names\n$name"
	if echo $section | grep -E "^${hostname}" >/dev/null; then
		log "using section '$section' for hostname '$hostname'"
		sections="$sections $section"
	fi
done

if [ -z "$sections" ]; then
	log "found no configuration for hostname '$hostname', starting dialog"
	pre="Ihnen konnte kein Drucker zugewiesen werden!\nBitte wählen Sie einen aus:\n\n"
	while true; do
		sections=$(dialog "$pre$names")
		if [ $? -eq 0 ]; then
			log "got dialog answer: $sections"
		else
			break
		fi
		log "checking name"
		name="$(eval echo \$MAP__${sections}__name)"
		if echo "$sections" | grep -Ei "syntaxerror|\`|\'|\"" > /dev/null; then
			pre="Kein gültiger Druckername!\n\n"; continue
		fi
		if [ "X$name" = "X" -o "$name" = "${sections}__name" ]; then
			pre="$sections ist kein gültiger Druckername!\n\n"; continue
		fi
		break
	done
fi

# check for $section (using it from now on)
if [ -z "$sections" ]; then
	log "variable \$sections not set; exiting"; myexit 1
fi

# do sections
for section in $sections; do

log "going on with section $section"

name="$(eval echo \$MAP__${section}__name)"
description="$(eval echo \$MAP__${section}__description)"
location="$(eval echo \$MAP__${section}__location)"

# check if section exists (name is mandatory)
if [ "X$name" = "X" -o "$name" = "${section}__name" ]; then
	log "found NO configuration for section $section!"
	myexit 1
else
	log "found the configuration for section $section."
fi

# use specific value if set for $server
global_server=$MAP__server
section_server="$(eval echo \$MAP__${section}__server)"
if [ -n "$section_server" ]; then
	server=$section_server
else
	server=$global_server
fi

# ppd names from specific to global
ppd_section="$(eval echo \$MAP__${section}__ppd)"
# use file name created by OSX printer setup
ppd_cups="$(echo $(eval echo \$MAP__${section}__description) | sed -e 's/ /_/g')"
ppd_cups="_${ppd_cups}.ppd"
ppd_global=$MAP__ppd

# search for the ppd file in this directories (first match wins)
ppd_dirs="
/etc/cups/ppd
/Library/Printers/PPDs/Contents/Resources
/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/PrintCore.framework/Versions/A/Resources
"

unset ppd
for ppdname in $ppd_section $ppd_cups $ppd_global; do
	for d in $ppd_dirs; do
		[ -n "$ppd" ] && break
		f="$d/$ppdname"
		if [ -s "$f" ]; then
			# got a name
			ppd="$f"
			break
		fi
	done
done

# check if ppd file exists an is readable
if [ -r "$ppd" ]; then
	log "found ppd as '$ppd'"
else
	log "not found ppd '$ppd', exiting!"	
	myexit 1
fi

# just do it
mapprinter \
	"$name" \
	"$description" \
	"$location" \
	"$ppd" \
	"$server"

# done sections
done

# Is this real? (Wipers)
myexit 0
