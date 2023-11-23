implementation module ostoolbox

import StdClass,StdMisc,StdInt
import pointer,events

::	OSToolbox 
	:==	Int

// OSNewToolbox :: *OSToolbox
OSNewToolbox :== 0

// RWS ??? add success bool
osInitToolbox :: !*OSToolbox -> *OSToolbox
osInitToolbox tb
	| tb <> 0
		= abort "OSInitToolbox reinitialised\n" 
	# tb	= setSystemMaskForKeyUp tb
	= tb		// DvA: dummy implementation

SetEventMask :: !Int !*OSToolbox -> *OSToolbox
SetEventMask _ _ = code {
	ccall SetEventMask "I:V:I"
	}


setSystemMaskForKeyUp :: !*OSToolbox -> *OSToolbox
setSystemMaskForKeyUp tb
	# sysEvtMask		= MDownMask bitor MUpMask bitor KeyDownMask bitor AutoKeyMask bitor DiskMask
	  tb				= SetEventMask (sysEvtMask bitor KeyUpMask) tb
	= tb


// RWS ??? ugly
// OSDummyToolbox :: *OSToolbox
OSDummyToolbox :== 0

worldGetToolbox :: !*World -> (!*OSToolbox,!*World)
worldGetToolbox world = (OSNewToolbox,world)

worldSetToolbox :: !*OSToolbox !*World -> *World
worldSetToolbox tb world = world
