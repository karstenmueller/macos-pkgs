set listofUrls to {}
set urlList to ":Users:kmueller:Desktop:urllist.txt" as alias
set Urls to paragraphs of (read urlList)
repeat with nextLine in Urls
	if length of nextLine is greater than 0 then
		copy nextLine to the end of listofUrls
	end if
end repeat
choose from list listofUrls with title "Refine URL list" with prompt "Please select the URLs that will comprise your corpus." with multiple selections allowed

set choices to the result
set tid to AppleScript's text item delimiters
set AppleScript's text item delimiters to return
set list_2_string to choices as text
set AppleScript's text item delimiters to tid
log list_2_string
write list_2_string to newList
