implementation module EdCommon

import EdMonad, EdText, EdSelection
import StrictList
import IdeState
import PmParse, PmPath
import StdMenuElement
import search, EdMovement, EdVisualCursor

:: *PLocState :== General

mChangeSelectionTo :: Selection -> EditMonad (PSt General) nothing
mChangeSelectionTo newSelection =
	getText											>>>= \text ->
	getMenuSelection								>>>= \mselold ->
	accEnv (getMenuIds)								>>>= \mIds ->
	let (frag,_)	= getTextFragment (orderSelection newSelection) text
		mselnew		= dofrag frag
		fragaction
			| changed mselold mselnew = (handlefrag mselnew mIds	>>> setMenuSelection mselnew)
			= skip
	in
	fragaction
where
	changed Nothing Nothing = False
	changed (Just strl) (Just strr) = strl <> strr
	changed _ _ = True
	
	dofrag (SCons (str) SNil) 
		| CleanModId str
			= Just str
		= Nothing
	dofrag _ = Nothing

	handlefrag (Just str) mIds
		=	appEnv (appPIO (setMenuElementTitles
				[(mIds.mn_odm,"Open "+++(MakeDefPathname str))
				,(mIds.mn_oim,"Open "+++(MakeImpPathname str))
				]))
	handlefrag _ mIds =
		appEnv (appPIO (setMenuElementTitles
			[(mIds.mn_odm,"Open Definition...")
			,(mIds.mn_oim,"Open Implementation...")
			]))

mRemoveSelection :: EditMonad (PSt General) nothing
mRemoveSelection =
	accEnv (getMenuIds)								>>>= \mIds ->
	appEnv (appPIO (setMenuElementTitles
		[(mIds.mn_odm,"Open Definition...")
		,(mIds.mn_oim,"Open Implementation...")
		]))											>>>
	setMenuSelection Nothing

// control click

controlDoubleClick :: !.Bool !.Position -> EditMonad (PSt General) nothing
controlDoubleClick shiftDown position =
	selectWordAt position						>>>= \selection ->
  	getPathName									>>>= \pathname ->
  	getText										>>>= \text ->
	let orderedSelection	= orderSelection selection
		(fragment, _)		= getTextFragment orderedSelection text
	    string				= case fragment of
	    						SCons string SNil	-> string
	    						_					-> ""
	in
	vChangeSelectionTo selection				>>>
	setSelectMode (SelectWords selection)		>>>
	accEnv getFBI								>>>= \fbi ->
	accEnv (accPLoc getTypeWinInfo)				>>>= \twi ->
	getWindowId									>>>= \windowId ->
	let
		fbi` =	{ fbi 
				& kind = if shiftDown Implementation Definition
				, type = if (isTypeWindow windowId twi) SearchPaths SearchImports
				}
	in
	// should make sure single line selection, here or in sr_find_def_imp...
	// now done above...
	appEnv ( sr_find_def_imp_sel False string pathname fbi` )
