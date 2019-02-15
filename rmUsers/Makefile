USE_PKGBUILD=1
include /usr/local/share/luggage/luggage.make

TITLE=cleanUp
NAME=cleanUp
REVERSE_DOMAIN=de.kamueller

PAYLOAD=\
	pack-script-cleanUp\
	pack-Library-LaunchAgents-${REVERSE_DOMAIN}.${NAME}.plist

pack-script-cleanUp:
	@sudo ${INSTALL} -d ${WORK_D}/Library/Management/${NAME}
	@sudo ${INSTALL} -C -m 0740 -o root -g wheel \
		./${NAME}.sh ${WORK_D}/Library/Management/${NAME}/${NAME}.sh
