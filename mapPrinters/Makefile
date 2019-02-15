USE_PKGBUILD=1
include /usr/local/share/luggage/luggage.make

TITLE=mapPrinters
NAME=mapPrinters

REVERSE_DOMAIN=de.kamueller

PAYLOAD=\
	pack-script-mapShares\
	pack-Library-LaunchAgents-${REVERSE_DOMAIN}.${NAME}.plist

pack-script-mapShares:
	@sudo ${INSTALL} -d ${WORK_D}/Library/Management/${NAME}
	@sudo ${INSTALL} -C -m 0755 -o root -g wheel \
		./${NAME}.sh ${WORK_D}/Library/Management/${NAME}/${NAME}.sh
	@sudo ${INSTALL} -C -m 0444 -o root -g wheel \
		./read_ini.sh ${WORK_D}/Library/Management/${NAME}/read_ini.sh
#	@sudo ${INSTALL} -d ${WORK_D}/Library/Printers/PPDs/Contents/Resources
#	@sudo ${INSTALL} -m 664 -g admin -o root ppd/* ${WORK_D}/Library/Printers/PPDs/Contents/Resources
