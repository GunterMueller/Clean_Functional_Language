implementation module menubar

import StdFunc
import StdMenuElement
import IdeState, EdMonad, EdClient
import PmPath

mb_update_undoinfo :: !*(PSt *General) -> *PSt *General
mb_update_undoinfo ps
	#	({mn_und},ps)	= getMenuIds ps
		(mui,ps)		= sendToActiveWindow msgGetUndoState ps
	= case mui of
		Nothing			-> appPIO (disableMenuElements [mn_und] o setMenuElementTitles [(mn_und,"Undo")]) ps
		Just (st,ac)	-> case st of
			None		-> appPIO (disableMenuElements [mn_und] o setMenuElementTitles [(mn_und,"Undo")]) ps
			Undo		-> appPIO ( enableMenuElements [mn_und] o setMenuElementTitles [(mn_und,"Undo"+++ac)]) ps
			Redo		-> appPIO ( enableMenuElements [mn_und] o setMenuElementTitles [(mn_und,"Redo"+++ac)]) ps

mb_update_pathname :: !.Pathname !*(PSt *General) -> *PSt *General;
mb_update_pathname pathName ps
	# (menuIds,ps)	= getMenuIds ps
	# ps			= appPIO (setMenuElementTitles
						[(menuIds.mn_sav,"Save " +++(RemovePath pathName))
						,(menuIds.mn_rev,"Revert " +++(RemovePath pathName))
						,(menuIds.mn_oth,"Open " +++(makeOther(RemovePath pathName)))
						,(menuIds.mn_prt,"Print " +++ (RemovePath pathName))
						]) ps
	= ps
									

mb_enable_pathname :: !*(PSt *General) -> *PSt *General;
mb_enable_pathname ps
	# (menuIds,ps)	= getMenuIds ps
	= appPIO (enableMenuElements
		[ menuIds.mn_sav
		, menuIds.mn_rev
		, menuIds.mn_oth
		, menuIds.mn_prt
		]) ps

mb_disable_pathname :: !*(PSt *General) -> *PSt *General;
mb_disable_pathname ps
	# (menuIds,ps)	= getMenuIds ps
	= appPIO (disableMenuElements
		[ menuIds.mn_sav
		, menuIds.mn_rev
		, menuIds.mn_oth
		, menuIds.mn_prt
		]) ps

makeOther :: .Pathname -> Pathname;
makeOther pth
	| IsDefPathname pth = MakeImpPathname pth
	= MakeDefPathname pth
