definition module print

from quickdraw import :: GrafPtr	
from mac_types import :: Toolbox

:: *InternalPicture :== (!GrafPtr, !*Toolbox)
:: PRecHdl :== Int
:: OkReturn :== Int

getDefaultPrintSetupC	:: !*env -> (!(!Int,!String),!*env)
getPageDimensionsC		::	!String	!Bool
						->	(!Int,!(!(!Int,!Int), !(!(!Int,!Int),!(!Int,!Int)), !(!Int,!Int)))
printSetupDialogC		:: !String !*env -> (!(!Int,!String),!*env)
prOpenPage 				:: !GrafPtr !*Toolbox -> (!OkReturn, !*Toolbox)
prClosePage 			:: !GrafPtr !*Toolbox -> (!OkReturn, !*Toolbox)
prOpenDoc 				:: !PRecHdl !*Toolbox -> (!Int, !InternalPicture)
prCloseDoc 				:: !InternalPicture !PRecHdl -> *Toolbox
prClose 				:: !*Toolbox -> *Toolbox
getPrintInfoC 			:: !Int !Int !String !*Toolbox -> 
			                       ( !OkReturn, 
            			           	 !PRecHdl,
                        			 !Int, !Int,
			                         !Int,
									 !String,
                       				 !*Toolbox
			                       )
printsetupstringvalid	::	!String !*env
						->	(!Bool, !*env)
os_getresolution 		:: !*Toolbox -> (!(!Int,!Int),!*Toolbox)
isPrinting 				:: !*Toolbox ->(!Int,!*Toolbox)
