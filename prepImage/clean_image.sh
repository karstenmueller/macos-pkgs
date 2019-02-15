#!/bin/bash
# this script does some cleanup in preperation for building an image
# best to run this from single user mode, or at least right before you shutdown run this as root, or with sudo rights

set -x

# Set prefix to a specific volume
PREFIX=""

#delete swapfiles
rm -f $PREFIX/private/var/vm/swap*
rm -f $PREFIX/private/var/vm/sleepimage

#delete volume info DB
rm $PREFIX/private/var/db/volinfo.database

#cleanup local admin's home dir
rm -rf $PREFIX/Users/admin/Desktop/*
rm -rf $PREFIX/Users/admin/Documents/*
rm -rf $PREFIX/Users/admin/Library/Caches/*
rm -rf $PREFIX/Users/admin/Library/Recent\ Servers/*
rm -rf $PREFIX/Users/admin/Library/Logs/*
rm -rf $PREFIX/Users/admin/Library/Keychains/*
rm -rf $PREFIX/Users/admin/Library/Preferences/ByHost/*
rm -f $PREFIX/Users/admin/Library/Preferences/com.apple.recentitems.plist
rm -rf $PREFIX/Users/admin/Movies/*
rm -rf $PREFIX/Users/admin/Music/*
rm -rf $PREFIX/Users/admin/Pictures/*
rm -rf $PREFIX/Users/admin/Public/Drop\ Box/* 

#cleanup root's home dir
rm -rf $PREFIX/private/var/root/Desktop/*
rm -rf $PREFIX/private/var/root/Documents/*
rm -rf $PREFIX/private/var/root/Downloads/*
rm -rf $PREFIX/private/var/root/Library/Caches/*
rm -rf $PREFIX/private/var/root/Library/Recent\ Servers/*
rm -rf $PREFIX/private/var/root/Library/Logs/*
rm -rf $PREFIX/private/var/root/Library/Keychains/*
rm -rf $PREFIX/private/var/root/Library/Preferences/ByHost/*
rm -f $PREFIX/private/var/root/Library/Preferences/com.apple.recentitems.plist
rm -rf $PREFIX/private/var/root/Public/Drop\ Box/*

#unlock files and empty trash
chflags -R nouchg $PREFIX/Users/*/.Trash/*
rm -rf $PREFIX/Users/*/.Trash/*

#clean up global caches and temp data
rm -rf $PREFIX/Library/Caches/*
rm -rf $PREFIX/System/Library/Caches/*
#rm -rf $PREFIX/Users/Shared/*
rm -f $PREFIX/private/etc/ssh_host*

#network interfaces - this is regenerated on reboot and can differ on different hardware
rm -f $PREFIX/Library/Preferences/SystemConfiguration/NetworkInterfaces.plist

#Leopard - cleanup local KDC, see http://support.apple.com/kb/TS1245
/usr/sbin/systemkeychain -k /Library/Keychains/System.keychain -C -f
rm -rf $PREFIX/var/db/krb5kdc
/usr/bin/defaults delete /System/Library/LaunchDaemons/com.apple.configureLocalKDC Disabled

#log cleanup.  We touch the log file after removing it since syslog
#won't create missing logs.  
rm $PREFIX/private/var/log/alf.log
touch $PREFIX/private/var/log/alf.log
rm $PREFIX/private/var/log/cups/access_log   
touch $PREFIX/private/var/log/cups/access_log
rm $PREFIX/private/var/log/cups/error_log   
touch $PREFIX/private/var/log/cups/error_log
rm $PREFIX/private/var/log/cups/page_log   
touch $PREFIX/private/var/log/cups/page_log
rm $PREFIX/private/var/log/daily.out
rm $PREFIX/private/var/log/ftp.log*
touch $PREFIX/private/var/log/ftp.log
rm -rf $PREFIX/private/var/log/httpd/*
rm $PREFIX/private/var/log/lastlog
rm $PREFIX/private/var/log/lookupd.log*
rm $PREFIX/private/var/log/lpr.log*
rm $PREFIX/private/var/log/mail.log*
touch $PREFIX/private/var/log/lpr.log
rm $PREFIX/private/var/log/mail.log*
touch $PREFIX/private/var/log/mail.log
rm $PREFIX/private/var/log/monthly.out
rm $PREFIX/private/var/log/run_radmind.log
rm -rf $PREFIX/private/var/log/samba/*
rm $PREFIX/private/var/log/secure.log
touch $PREFIX/private/var/log/secure.log
rm $PREFIX/private/var/log/system.log*
touch $PREFIX/private/var/log/system.log
rm $PREFIX/private/var/log/weekly.out
rm $PREFIX/private/var/log/windowserver.log
touch $PREFIX/private/var/log/windowserver.log
rm $PREFIX/private/var/log/windowserver_last.log
rm $PREFIX/private/var/log/wtmp.*

# Self-removal if run by pkgutil
[ X$INSTALL_PKG_SESSION_ID != "X" ] && /usr/bin/srm -mf "${0}"
