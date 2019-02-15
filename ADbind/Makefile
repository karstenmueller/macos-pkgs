USE_PKGBUILD=1
include /usr/local/share/luggage/luggage.make

TITLE=ADbind
PACKAGE_NAME=ADbind
REVERSE_DOMAIN=de.kamueller
PAYLOAD=\
	pack-script-adbind\
	pack-script-postinstall\
	remove-script-postinstall

pack-script-adbind:
	cp adbind.sh postinstall

remove-script-postinstall:
	rm -f postinstall
