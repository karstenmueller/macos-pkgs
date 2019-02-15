#!/bin/bash

# -------------------------------------------------------------------------
# Script config
# -------------------------------------------------------------------------
AD_DOMAIN="<domainname>"
#COMPUTER_ID=$(/usr/sbin/scutil --get LocalHostName)
COMPUTER_ID=""
COMPUTERS_OU="OU=Macs,OU=<organisation>,DC=<domaincontroller>,DC=<domain>"
ADMIN_LOGIN="apple-admin"
ADMIN_PWD=""
MOBILE="disable"
MOBILE_CONFIRM="disable"
LOCAL_HOME="enable"
USE_UNC_PATHS="enable"
UNC_PATHS_PROTOCOL="smb"
PACKET_SIGN="allow"
PACKET_ENCRYPT="allow"
PASSWORD_INTERVAL="0"
#ADMIN_GROUPS="COMPANY\Domain Admins,COMPANY\Enterprise Admins"
ADMIN_GROUPS="<domainname>\Domänen-Admins,<domainname>\Organisations-Admins,<domainname>\Mac-Admins"

# UID_MAPPING=
# GID_MAPPING=
# GGID_MAPPING==

# disable history characters
histchars=""

SCRIPT_NAME=`basename "${0}"`
echo "${SCRIPT_NAME} - v1.26 ("`date`")"

# -------------------------------------------------------------------------
# functions
# -------------------------------------------------------------------------
is_ip_address() {
  IP_REGEX="\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"
  IP_CHECK=`echo ${1} | egrep ${IP_REGEX}`
  if [ ${#IP_CHECK} -gt 0 ]
  then
    return 0
  else
    return 1
  fi
}

get_hostname() {
  local user=$1
  hostname=$(/usr/bin/osascript <<_EOT_
tell application "System Events"
  activate
  set c to 0
  -- Repeat until the user either enters a 2- to 4-character code or cancels.
  repeat while ((c < 2) or (c > 10))
    set hostname to text returned of (display dialog "Bitte den Hostname eingeben (2-10 Zeichen)" default answer "")
    set c to (count hostname)
  end repeat
  return hostname as string
end tell
_EOT_)
  echo $hostname
}

get_password() {
  local title=$1
  password=$(/usr/bin/osascript <<_EOT_
  tell application "System Events"
  activate
  set pw_answer to display dialog "Passwort:" with title "$title" with icon caution default answer "" buttons {"Abbrechen", "OK"} default button 2 giving up after 60 with hidden answer
  set pw_text to text returned of pw_answer
  if length of pw_text is 0 then
    display dialog "Kein Passwort angegeben!" buttons ["OK"] default button 1 giving up after 5
  else
    return pw_text
  end if
  end tell
_EOT_)
  echo $password
}

get_answer() {
  local title=$1
  answer=$(/usr/bin/osascript <<_EOT_
  tell application "System Events"
  activate
  set my_answer to display dialog "Eingabe:" with title "$title" with icon caution default answer "" buttons {"Abbrechen", "OK"} default button 2 giving up after 60
  set my_text to text returned of my_answer
  if length of my_text is 0 then
    display dialog "Keine Eingabe!" buttons ["OK"] default button 1 giving up after 5
  else
    return my_text
  end if
  end tell
_EOT_)
  echo $answer
}

# -------------------------------------------------------------------------
# MAIN
# -------------------------------------------------------------------------

# check for logged in user
cuser=$(who | grep "console" | cut -d" " -f1)
if [ "X${cuser}" = "X" ]; then
  echo "Can't get a console user; exiting!"
  exit 1
else
  echo "User '${cuser}' logged in to console"
fi

# We need root permissions so elevate the script's privileges
if [ ! "$UID" -eq 0 ]; then
  pw=$(get_password "Passwort eines Benutzers mit lokalen Admin Rechten")
  if [ -n "$pw" ]; then
    echo "$pw" | /usr/bin/sudo -k -S bash "$0" "$@"
    exit 0
  else
    echo "No  password for admin specified, exiting"
    exit 1
  fi
fi

# We need a password for $ADMIN_LOGIN so get it
if [ "X$ADMIN_PWD" = "X" ]; then
  ADMIN_PWD=$(get_password "Passwort des Benutzer $ADMIN_LOGIN für AD join")
  if [ -z "$ADMIN_PWD" ]; then
    echo "No password for $ADMIN_LOGIN specified, exiting"
    exit 1
  fi
fi

# We need a name for the game
if [ "X$COMPUTER_ID" = "X" ]; then
  COMPUTER_ID=$(get_answer "Name für diesen Computer")
  if [ -z "$COMPUTER_ID" ]; then
    echo "No computer name specified, exiting"
    exit 1
  fi
fi

if [ "X${COMPUTER_ID}" = "X" ]
then
echo "This mac doesn't have a name, exiting."
  exit 1
fi

# -------------------------------------------------------------------------
# all set so let's get started
#

# AD can only use a 15 character name
COMPUTER_ID=`echo ${COMPUTER_ID} | sed 's/ //g' | cut -c1-15`

/usr/sbin/scutil --set ComputerName ${COMPUTER_ID}
/usr/sbin/scutil --set HostName ${COMPUTER_ID}
/usr/sbin/scutil --set LocalHostName ${COMPUTER_ID}

hostname=$(/usr/sbin/scutil --get LocalHostName)
echo "Hostname set to $hostname"

#
# Wait for network services to be initialized
#
echo "Checking for the default route to be active..."
ATTEMPTS=0
MAX_ATTEMPTS=18
while ! (netstat -rn -f inet | grep -q default)
do
  if [ ${ATTEMPTS} -le ${MAX_ATTEMPTS} ]
  then
    echo "Waiting for the default route to be active..."
    sleep 10
    ATTEMPTS=`expr ${ATTEMPTS} + 1`
  else
    echo "Network not configured, AD binding failed (${MAX_ATTEMPTS} attempts), will retry at next boot!" 2>&1
    exit 1
  fi
done

#
# Wait for the related server to be reachable
# NB: AD service entries must be correctly set in DNS
#
SUCCESS=
is_ip_address "${AD_DOMAIN}"
if [ ${?} -eq 0 ]
then
  # the AD_DOMAIN variable contains an IP address, let's try to ping the server
  echo "Testing ${AD_DOMAIN} reachability" 2>&1  
  if ping -t 5 -c 1 "${AD_DOMAIN}" | grep "round-trip"
  then
    echo "Ping successful!" 2>&1
    SUCCESS="YES"
  else
    echo "Ping failed..." 2>&1
  fi
else
  ATTEMPTS=0
  MAX_ATTEMPTS=12
  while [ -z "${SUCCESS}" ]
  do
    if [ ${ATTEMPTS} -lt ${MAX_ATTEMPTS} ]
    then
      AD_DOMAIN_IPS=( `host "${AD_DOMAIN}" | grep " has address " | cut -f 4 -d " "` )
      for AD_DOMAIN_IP in ${AD_DOMAIN_IPS[@]}
      do
        echo "Testing ${AD_DOMAIN} reachability on address ${AD_DOMAIN_IP}" 2>&1  
        if ping -t 5 -c 1 ${AD_DOMAIN_IP} | grep "round-trip"
        then
          echo "Ping successful!" 2>&1
          SUCCESS="YES"
        else
          echo "Ping failed..." 2>&1
        fi
        if [ "${SUCCESS}" = "YES" ]
        then
          break
        fi
      done
      if [ -z "${SUCCESS}" ]
      then
        echo "An error occurred while trying to get ${AD_DOMAIN} IP addresses, new attempt in 10 seconds..." 2>&1
        sleep 10
        ATTEMPTS=`expr ${ATTEMPTS} + 1`
      fi
    else
      echo "Cannot get any IP address for ${AD_DOMAIN} (${MAX_ATTEMPTS} attempts), aborting lookup..." 2>&1
      break
    fi
  done
fi

if [ -z "${SUCCESS}" ]
then
  echo "Cannot reach any IP address of the domain ${AD_DOMAIN}." 2>&1
  echo "AD binding failed, will retry at next boot!" 2>&1
  exit 1
fi

#
# Unbinding computer first
#
echo "Unbinding computer..." 2>&1
dsconfigad -remove -username "${ADMIN_LOGIN}" -password "${ADMIN_PWD}" 2>&1

#
# Try to bind the computer
#
ATTEMPTS=0
MAX_ATTEMPTS=12
SUCCESS=
while [ -z "${SUCCESS}" ]
do
  if [ ${ATTEMPTS} -le ${MAX_ATTEMPTS} ]
  then
    echo "Binding computer to domain ${AD_DOMAIN}..." 2>&1 
    dsconfigad -add "${AD_DOMAIN}" -computer "${COMPUTER_ID}" -ou "${COMPUTERS_OU}" -username "${ADMIN_LOGIN}" -password "${ADMIN_PWD}" -force 2>&1
    IS_BOUND=`dsconfigad -show | grep "Active Directory Domain"`
    if [ -n "${IS_BOUND}" ]
    then
      SUCCESS="YES"
    else
      echo "An error occured while trying to bind this computer to AD, new attempt in 10 seconds..." 2>&1
      sleep 10
      ATTEMPTS=`expr ${ATTEMPTS} + 1`
    fi
  else
    echo "AD binding failed (${MAX_ATTEMPTS} attempts), will retry at next boot!" 2>&1
    SUCCESS="NO"
  fi
done

if [ "${SUCCESS}" = "YES" ]; then
  # update AD plugin options
  echo "Setting AD options..." 2>&1
  dsconfigad -mobile ${MOBILE} > /dev/null 2>&1; sleep 1
  dsconfigad -mobileconfirm ${MOBILE_CONFIRM}  > /dev/null 2>&1; sleep 1
  dsconfigad -localhome ${LOCAL_HOME}  > /dev/null 2>&1; sleep 1
  dsconfigad -useuncpath ${USE_UNC_PATHS}  > /dev/null 2>&1; sleep 1
  dsconfigad -protocol ${UNC_PATHS_PROTOCOL}  > /dev/null 2>&1; sleep 1
  dsconfigad -packetsign ${PACKET_SIGN}  > /dev/null 2>&1; sleep 1
  dsconfigad -packetencrypt ${PACKET_ENCRYPT}  > /dev/null 2>&1; sleep 1
  dsconfigad -passinterval ${PASSWORD_INTERVAL}  > /dev/null 2>&1
  if [ -n "${ADMIN_GROUPS}" ]; then
    sleep 1; dsconfigad -groups "${ADMIN_GROUPS}" 2>&1
  fi
  sleep 1

  if [ -n "${AUTH_DOMAIN}" ] && [ "${AUTH_DOMAIN}" != 'All Domains' ]; then
    dsconfigad -alldomains disable > /dev/null 2>&1
  else
    dsconfigad -alldomains enable > /dev/null 2>&1
  fi
  AD_SEARCH_PATH=`dscl /Search -read / CSPSearchPath | grep "Active Directory" | sed 's/^ *//' | sed 's/ *$//'`
  if [ -n "${AD_SEARCH_PATH}" ]
  then
    echo "Deleting '${AD_SEARCH_PATH}' from authentication search path..." 2>&1
    dscl localhost -delete /Search CSPSearchPath "${AD_SEARCH_PATH}" 2>/dev/null
    echo "Deleting '${AD_SEARCH_PATH}' from contacts search path..." 2>&1
    dscl localhost -delete /Contact CSPSearchPath "${AD_SEARCH_PATH}" 2>/dev/null
  fi
  dscl localhost -create /Search SearchPolicy CSPSearchPath 2>&1
  dscl localhost -create /Contact SearchPolicy CSPSearchPath 2>&1
  AD_DOMAIN_NODE=`dscl localhost -list "/Active Directory" | head -n 1`
  if [ "${AD_DOMAIN_NODE}" = "All Domains" ]; then
    AD_SEARCH_PATH="/Active Directory/All Domains"
  elif [ -n "${AUTH_DOMAIN}" ] && [ "${AUTH_DOMAIN}" != 'All Domains' ]; then
    AD_SEARCH_PATH="/Active Directory/${AD_DOMAIN_NODE}/${AUTH_DOMAIN}"
  else
    AD_SEARCH_PATH="/Active Directory/${AD_DOMAIN_NODE}/All Domains"
  fi
  echo "Adding '${AD_SEARCH_PATH}' to authentication search path..." 2>&1
  dscl localhost -append /Search CSPSearchPath "${AD_SEARCH_PATH}"
  echo "Adding '${AD_SEARCH_PATH}' to contacts search path..." 2>&1
  dscl localhost -append /Contact CSPSearchPath "${AD_SEARCH_PATH}"

  if [ -n "${UID_MAPPING}" ]; then
    sleep 1; dsconfigad -uid "${UID_MAPPING}" 2>&1
  fi
  if [ -n "${GID_MAPPING}" ]; then
    sleep 1; dsconfigad -gid "${GID_MAPPING}" 2>&1
  fi
  if [ -n "${GGID_MAPPING}" ]; then
    sleep 1; dsconfigad -ggid "${GGID_MAPPING}" 2>&1
  fi

  GROUP_MEMBERS=`dscl /Local/Default -read /Groups/com.apple.access_loginwindow GroupMembers 2>/dev/null`
  NESTED_GROUPS=`dscl /Local/Default -read /Groups/com.apple.access_loginwindow NestedGroups 2>/dev/null`
  if [ -z "${GROUP_MEMBERS}" ] && [ -z "${NESTED_GROUPS}" ]; then
    echo "Enabling network users login..." 2>&1
    dseditgroup -o edit -n /Local/Default -a netaccounts -t group com.apple.access_loginwindow 2>/dev/null
  fi

  if [ "${SUCCESS}" = "YES" ]; then
    if [ -e "/System/Library/CoreServices/ServerVersion.plist" ]; then
      DEFAULT_REALM=`more /Library/Preferences/edu.mit.Kerberos | grep default_realm | awk '{ print $3 }'`
      if [ -n "${DEFAULT_REALM}" ]; then
        echo "The binding process looks good, will try to configure Kerberized services on this machine for the default realm ${DEFAULT_REALM}..." 2>&1
        /usr/sbin/sso_util configure -r "${DEFAULT_REALM}" -a "${ADMIN_LOGIN}" -p "${ADMIN_PWD}" all
      fi
      # Give OD a chance to fully apply new settings
      echo "Applying changes..." 2>&1
      sleep 10
    fi
    # Self-removal only if run by pkgutil
    [ X$INSTALL_PKG_SESSION_ID != "X" ] && /usr/bin/srm -mf "${0}"
    echo "Finished successfully."; exit 0
  fi
fi

echo "Finished with errors."; exit 1
