implementation module UtilObjectIO

/* OS dependent module */
/* Primitives which 'should be' in the standard CLEAN IO lib */

import StdArray, StdBool, StdClass, StdFile, StdList, StdMisc

import StdSystem, StdWindow

import StdFileSelect, StdPSt, StdPStClass, StdPictureDef

selectInputFile` :: !(PSt .l) -> (!Maybe String,!(PSt .l))
selectInputFile` ps
	= selectInputFile ps

selectOutputFile` :: !String !String !String !(PSt .l) -> (!Maybe String,!(PSt .l))
selectOutputFile` prompt filename ok ps
	= selectOutputFile prompt filename ps

selectDirectory` :: !(PSt .l) -> (!Maybe String,!PSt .l)
selectDirectory` ps
	# (ms,ps)	= selectDirectory ps
	# ms		= mapMaybe removeDirsep ms
	= (ms,ps)
where
	removeDirsep s
		# final				= dec (size s)
		| s.[final] == ':'	= s%(0,dec final)
		= s

ShellDefault :: !{#Char} !(PSt .l) -> (!Int,!(PSt .l))
ShellDefault _ ps = abort "no ShellDefault on a Mac silly:-)"

GetDialogBackgroundColour :: !(PSt .l) -> (!Colour,!PSt .l)
GetDialogBackgroundColour ps
	= (White/*LightGrey*/, ps)	// Mac Appearance dependant!

isWindow :: !Id *(PSt .l) -> (Bool,*(PSt .l))
isWindow wId ps
	# (s,ps)	= accPIO getWindowsStack ps
	= (isMember wId s, ps)

