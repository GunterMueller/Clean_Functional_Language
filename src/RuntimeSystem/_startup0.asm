
	_TEXT segment

	public	_mainCRTStartup
	extrn	clean_main:near

_mainCRTStartup:
	jmp		clean_main

_TEXT	ends

end
