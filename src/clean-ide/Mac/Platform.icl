implementation module Platform

import StdInt, StdMisc, StdFile
import StdTuple,StdOverloaded,StdArray
import StdSystem

PlatformDependant win mac
	:== mac

// FIXME: should be IdePlatform
batchOptions	:: !*World -> (!Bool,Bool,String,*File,!*World)
batchOptions world
	# interact		= True
	  force_update	= undef
	  prj_name		= undef
	  logfile		= undef
	= (interact,force_update,prj_name,logfile,world)

// FIXME: should be IdePlatform
wAbort			:: !String !*World -> *World
wAbort message world
	# stderr	= fwrites message stderr
	# (_,world)	= fclose stderr world
	= world

TempDir	:: String
TempDir = applicationpath "Temp"

EnvsDir		:: String
EnvsDir = applicationpath "Config"

PrefsDir	:: String
PrefsDir = applicationpath "Config"

BitmapDir	:: String
BitmapDir = applicationpath "Bitmaps"

//////////////

:: OSStatus	:== Int

onOSX :: Bool
onOSX =: fst (runningCarbonOSX 0/*OSNewToolbox*/)

runningCarbonOSX tb
	# (err,res,tb)	= Gestalt "sysv" tb
	| err <> 0 = abort "Gestalt failed.\n"
	= (res >= 0x01000, tb)

Gestalt :: !String !*Int -> (!Int,!Int,!*Int)
Gestalt sSel tb
	| size sSel <> 4 = abort "Gestalt not called with four-char selector.\n"
	# iSel	= ((toInt sSel.[0]) << 24) bitor ((toInt sSel.[1]) << 16) bitor ((toInt sSel.[2]) << 8) bitor ((toInt sSel.[3]) << 0)
	= Gestalt iSel tb
where
	Gestalt :: !Int !*Int -> (!Int,!Int,!*Int)
	Gestalt _ _ = code {
		ccall Gestalt "PI:II:I"
		}
