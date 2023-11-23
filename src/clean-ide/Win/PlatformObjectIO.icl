implementation module PlatformObjectIO

import StdArray, StdEnum, StdList, StdClass, StdBool, StdMisc
from ArgEnv import getCommandLine
import set_return_code
import StdPSt
from UtilIO import GetLongPathName
import StdIOCommon

from iostate import ioStGetWorld,ioStSetWorld

app_world_instead_of_ps f ps
	:== appPIO app_world_instead_of_io ps
where
	app_world_instead_of_io io
		# (w,io) = ioStGetWorld io
		# w = f w
		= ioStSetWorld w io

cl_args =: getCommandLine

filter_opts [] = []
filter_opts [h:t]
	| h.[0] == '-'	= filter_opts (drop 1 t)
	= [h:filter_opts t]

initPlatformCommandLineArguments :: !*(PSt .l) -> (![String],!*PSt .l)
initPlatformCommandLineArguments ps
	# args	= cl_args
	# args	= [arg \\ arg <-: args]
	# args = filter_opts args
	| isEmpty args
		= ([],ps)
	# files	= tl args
	# files	= map GetLongPathName files
	= (files, ps)

pAbort :: !(PSt .a) -> PSt .a
pAbort ps
	= app_world_instead_of_ps (set_return_code_world (-1)) ps

installPlatformEventHandlers :: !*(PSt .l) -> *(PSt .l)
installPlatformEventHandlers ps
	= ps

openPlatformWindowMenu :: !*(PSt .l) -> *(PSt .l)
openPlatformWindowMenu ps
	= ps

getWindowModified :: !Id !(IOSt .l) -> (!Maybe Bool,!IOSt .l)
getWindowModified _ io = (Nothing,io)

setWindowModified :: !Id !String !Bool !(IOSt .l) -> IOSt .l
setWindowModified _ _ _ io = io
