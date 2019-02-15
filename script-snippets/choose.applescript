set l to {"aa", "bb", "cc"}
set choices to ""
repeat with x in l
	set choices to choices & quoted form of x & " "
end repeat
set dialog to paragraphs of (do shell script "/Applications/Utilities/CocoaDialog.app/Contents/MacOS/CocoaDialog" & " standard-dropdown --title title --text text --items " & choices)
if item 1 of dialog is "2" then return -- pressed cancel button
item ((item 2 of dialog) + 1) of l

-- choose from list {"aa", "bb", "cc"} with title "title" with prompt "prompt" default items "bb" with multiple selections allowed
-- choose from list {"ent", "oder", "weder"} with title "title" with prompt "Bitte auswählen:"


-- display a dialog to prompt the user to select a voice from a list of voices
set myVoices to {"Agnes", "Kathy", "Princess", "Vicki", "Victoria"}

-- get the voice the user selected from the list
set selectedVoice to {choose from list myVoices}

-- say "Hello world" using the voice the user selected
say "Hello world" using selectedVoice
