#!/bin/bash

# -------------------------------------------------------------------------
# cleanUp - some cleanup actions when a user logs in
# Coypright: © 2015 by Karsten Müller · IT-Beratung (info@kamueller.de)
# -------------------------------------------------------------------------

function log(){
	log=$1
	/usr/bin/logger -s -t de.kamueller.cleanUp "$log"
}

# delete User directories
for user in $(ls /Users | egrep -v "xadmin|schueler|lehrer|Shared|.localized"); do
    if [ "$user" == "$(who | grep 'console' | cut -d' ' -f1)" ]; then
        log "Skipping user: $user (current user)"
    else
        log "Removing user: $user"
        [ "X$user" != "X" ] && rm -rf /Users/$user
    fi
done

# clear all printer queues
lpstat -p | awk '{print $2}' | while read printer; do
  log "Clearing printer queue for $printer"
  lprm - -P "$printer"
done
