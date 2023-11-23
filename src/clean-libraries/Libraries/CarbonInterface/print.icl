implementation module print

from quickdraw import ::GrafPtr	
from mac_types import ::Toolbox
import code from "cPrinter."

:: *InternalPicture :== (!GrafPtr, !*Toolbox)
:: PRecHdl :== Int
:: OkReturn :== Int

getDefaultPrintSetupC	:: !*env -> (!(!Int,!String),!*env)
getDefaultPrintSetupC _
	= code
		{
			ccall getDefaultPrintSetupC ":VIS:A"
		}

getPageDimensionsC	::	!String	!Bool
					->	(!Int,!(!(!Int,!Int), !(!(!Int,!Int),!(!Int,!Int)), !(!Int,!Int)))
getPageDimensionsC x y
	= code
		{
			ccall getPageDimensionsC "SI:VIIIIIIIII"
		}

printSetupDialogC	:: !String !*env -> (!(!Int,!String),!*env)
printSetupDialogC _ _
	= code
		{
			ccall printSetupDialogC "S:VIS:A"
		}

prOpenPage :: !GrafPtr !*Toolbox -> (!OkReturn, !*Toolbox)
prOpenPage _ _
	= code
	{
			ccall prOpenPage "II-II"
	}

prClosePage :: !GrafPtr !*Toolbox -> (!OkReturn, !*Toolbox)
prClosePage _ _
	= code
	{
			ccall prClosePage "II-II"
	}

// error codes: 0=noErr, 2=non fatal error (especially user abort)
// 1 = fatal error.
prOpenDoc :: !PRecHdl !*Toolbox -> (!Int, !InternalPicture)
prOpenDoc _ _
	= code
	{
			ccall prOpenDoc "II-III"
	}

prCloseDoc :: !InternalPicture !PRecHdl -> *Toolbox
prCloseDoc _ _
	= code
	{
			ccall prCloseDoc "III-I"
	}

prClose :: !*Toolbox -> *Toolbox
prClose _  
	= code
	{
			ccall  prClose "I-I"
	}

getPrintInfoC :: !Int !Int !String !*Toolbox -> 
                       ( !OkReturn, 
                       	 !PRecHdl,
                         !Int, !Int,
                         !Int,
						 !String,
                       	 !*Toolbox
                       )
// error code: 0==ok, 1=out of memory, 2==user cancelled
//getPrintInfoC _ _ _ t = (0,0,0,0,0,"",t)
getPrintInfoC _ _ _ _
	= code
	{
			ccall getPrintInfoC "IISI:VIIIIISI"
	}

printsetupstringvalid		::	!String !*env
						->	(!Bool, !*env)
printsetupstringvalid _ _
	= code
	{
		ccall os_printsetupvalid "S:I:A"
	}

os_getresolution :: !*Toolbox -> (!(!Int,!Int),!*Toolbox)
os_getresolution _
	= code 	{
	 			ccall getResolutionC ":VII:I"
			}

// MW++
isPrinting :: !*Toolbox ->(!Int,!*Toolbox)
isPrinting _
	= code
	{
			ccall isPrinting ":I:I"
	}
