#!/bin/bash

CD_APP="/Applications/Utilities/CocoaDialog.app"
CD="$CD_APP/Contents/MacOS/CocoaDialog"

res=$($CD dropdown --title "Preferred OS" --no-newline \
--text "What is your favorite OS?" \
--items "Mac OS X" "GNU/Linux" "Windows" --button1 'That one!' \
--button2 Nevermind)

echo $res

## CHosse from a list
items=("invisible below" foo1 "invisible above" "bar" "foo")
#printf "%s\n" "${items[@]}"
res=$($CD standard-dropdown --title "Chooser" \
	--text "Choose:" --items "${items[@]}" \
	--string-output --float --debug)

echo $res


