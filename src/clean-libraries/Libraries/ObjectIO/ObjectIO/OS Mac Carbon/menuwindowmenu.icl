implementation module menuwindowmenu


//	Version 1.2

//	The definition and implementation of the WindowMenu. 


import	StdInt, StdBool, StdClass, StdList, StdTuple, StdFunc, StdEnum, StdMisc
import	StdMenu, StdMenuElement, StdWindow, StdPSt, StdProcess, StdIOCommon, StdId
import	menuinternal, menucreate, menudevice, id, windowdefaccess, windowaccess
// RWS +++
import commondef
import oswindow, iostate, osmenu, menuaccess, menuitems

//import StdDebug,dodebug
trace_n _ s :== s
//import dodebug

menuwindowmenuError :: String String -> .x
menuwindowmenuError rule message
	= error rule "menuwindowmenu" message

menuwindowmenuFatalError :: String String -> .x
menuwindowmenuFatalError rule message
	= fatalError rule "menuwindowmenu" message

minWindowW = fst osMinWindowSize
minWindowH = snd osMinWindowSize

TitleBarWidth		:== osWindowTitleBarHeight		// Conventional width of a window's title bar

/*	openWindowMenu creates the WindowMenu. This menu contains atleast the following elements:
	-	MenuItem "&Cascade":
			Reorder the current list of windows from left-top to right-bottom.
	-	MenuItem "Tile &Horizontally":
			Reorder the current list of windows from top to bottom.
	-	MenuItem "&Tile Vertically":
			Reorder the current list of windows from left to right.
	-	MenuSeparator
	-	RadioMenu:
			Display all current open windows (hidden and shown). Selection activates and
			shows the indicated window.
*/
updateActiveWindow ps
	# (wId,ps)	= accPIO getActiveWindow ps
	| isNothing wId = ps
	= appPIO (updateWindow (fromJust wId) Nothing) ps
	
openWindowMenu :: !(PSt .l) -> PSt .l
openWindowMenu pState
	# pState			= menuFunctions.dOpen pState
	# (id_types,pState)	= accPIO getMenus pState
	  ids					= map fst id_types
	| contains ((==) wMenuId) ids
	= pState
	#! wi = wMenuId
	#! li = length ids
	#! wd = wMenuDef li
	#! pState = pState
	# (error,pState)		= openMenu` wi Void wd pState
	| error==NoError
	= pState
	= menuwindowmenuError "openWindowMenu" "Fatal error: could not open the WindowMenu"
where
	wMenuId		= windowMenuId
	wMenuDef i	= Menu "Windows"
					(	MenuItem "&Cascade"				[MenuSelectState Unable,MenuId windowMenuCascadeId,	MenuFunction (noLS cascade)]
					:+:	MenuItem "Tile &Horizontally"	[MenuSelectState Unable,MenuId windowMenuTileHId,	MenuFunction (noLS tileH)]
					:+:	MenuItem "&Tile Vertically"		[MenuSelectState Unable,MenuId windowMenuTileVId,	MenuFunction (noLS tileV)]
					:+:	RadioMenu [] 0					[MenuId windowMenuRadioId]
					)
					[	MenuId		wMenuId
//					,	MenuIndex	i
					]
	
	cascade :: !(PSt .l) -> PSt .l
	cascade pState
		# (wIds,pState)		= accPIO getWindowsStack pState
		  nrWindows			= length wIds
		| nrWindows==0
		= pState
		# (pwSize,pState)	= accPIO getProcessWindowSize pState
		  wMargin			= pwSize.w/5
		  hMargin			= pwSize.h/5
		  (dx,dy)			= (TitleBarWidth,TitleBarWidth)
		  n					= min (wMargin/dx+1) (hMargin/dy+1)
		  virtualWidth		= max minWindowW (pwSize.w-(n-1)*dx)
		  virtualHeight		= max minWindowH (pwSize.h-(n-1)*dy)
		  virtualSize		= {w=virtualWidth-dx,h=virtualHeight-dy}
		  (front,rest)		= hdtl wIds
		  posWindows		= zip2 [(pos dx dy n i,virtualSize) \\ i<-[0..nrWindows-2]] (reverse rest)
		  pState			= stateMap2 rearrange posWindows pState
		  pState			= appPIO (setWindowViewSize front virtualSize) pState
		  pState			= appPIO (setWindowPos front (LeftTop,OffsetVector (pos dx dy n (nrWindows-1)))) pState
		# pState = trace_n ("cascade","nrWindows",nrWindows) pState
		# pState = trace_n ("cascade","pwSize",pwSize) pState
		# pState = trace_n ("cascade","virtualSize",virtualSize) pState
		= pState
	where
		pos :: !Int !Int !Int !Int -> Vector2
		pos dx dy n i	= {vx=dx*(i rem n),vy=dy*(i rem n)}
			
	tileH :: !(PSt .l) -> PSt .l
	tileH pState
		# (wIds,pState)		= accPIO getWindowsStack pState
		| isEmpty wIds
		= pState
		# (pwSize,pState)	= accPIO getProcessWindowSize pState
		  nrWindows			= length wIds
		  columns			= smallestNrColumns (minWindowH+TitleBarWidth) pwSize.h nrWindows
		  perfecttiling		= nrWindows rem columns==0
		  percolumn			= if perfecttiling (nrWindows/columns) (nrWindows/columns+1)
		  leftovers			= if perfecttiling 0 (nrWindows-(columns-1)*percolumn)
		  allWidth			= max minWindowW (pwSize.w/columns)
		  leftHeight		= max minWindowH (pwSize.h/leftovers)
		  restHeight		= max minWindowH (pwSize.h/percolumn)
		  leftSize			= {w=allWidth,h=leftHeight-TitleBarWidth}
		  restSize			= {w=allWidth,h=restHeight-TitleBarWidth}
		  (front,rest)		= hdtl wIds
		  (l,r)				= split (leftovers-1) rest
		  leftWindows		= zip2 [({vx=0,vy=i*leftHeight},leftSize) \\ i<-[1..]] l
		  restWindows		= zip2 [(pos allWidth restHeight percolumn i,restSize) \\ i<-[(if perfecttiling 1 percolumn)..]] r
		  pState			= stateMap2 rearrange (reverse (leftWindows++restWindows)) pState
		  firstSize			= if perfecttiling restSize leftSize
		  pState			= appPIO (setWindowViewSize front firstSize) pState
		  pState			= appPIO (setWindowPos  front (LeftTop,zero)) pState
		= pState
	where
		pos :: !Int !Int !Int !Int -> Vector2
		pos w h n i		= {vx=w*(i/n),vy=h*(i rem n)}
		
		smallestNrColumns :: !Int !Int !Int -> Int
		smallestNrColumns minHeight pwHeight nrWindows
			= smallestNrColumns` 1
		where
			smallestNrColumns` :: !Int -> Int
			smallestNrColumns` columns
				| (columns*pwHeight)/nrWindows>=minHeight
				= columns
				= smallestNrColumns` (columns+1)
	
	tileV :: !(PSt .l) -> PSt .l
	tileV pState
		# (wIds,pState)	= accPIO getWindowsStack pState
		| isEmpty wIds
		= pState
		# (pwSize,pState)	= accPIO getProcessWindowSize pState
		  nrWindows			= length wIds
		  rows				= smallestNrRows minWindowW pwSize.w nrWindows
		  perfecttiling		= nrWindows rem rows==0
		  perrow			= if perfecttiling (nrWindows/rows) (nrWindows/rows+1)
		  leftovers			= if perfecttiling 0 (nrWindows-(rows-1)*perrow)
		  allHeight			= max minWindowH (pwSize.h/rows)
		  topWidth			= max minWindowW (pwSize.w/leftovers)
		  restWidth			= max minWindowW (pwSize.w/perrow)
		  topSize			= {w=topWidth, h=allHeight-TitleBarWidth}
		  restSize			= {w=restWidth,h=allHeight-TitleBarWidth}
		  (front,rest)		= hdtl wIds
		  (l,r)				= split (leftovers-1) rest
		  topWindows		= zip2 [({vx=i*topWidth,vy=zero},topSize) \\ i<-[1..]] l
		  restWindows		= zip2 [(pos restWidth allHeight perrow i,restSize) \\ i<-[(if perfecttiling 1 perrow)..]] r
		  pState			= stateMap2 rearrange (reverse (topWindows++restWindows)) pState
		  firstSize			= if perfecttiling restSize topSize
		  pState			= appPIO (setWindowViewSize front firstSize) pState
		  pState			= appPIO (setWindowPos  front (LeftTop,zero)) pState
		= pState
	where
		pos :: !Int !Int !Int !Int -> Vector2
		pos w h n i		= {vx=w*(i rem n),vy=h*(i/n)}
		
		smallestNrRows :: !Int !Int !Int -> Int
		smallestNrRows minWidth pwWidth nrWindows
			= smallestNrRows` 1
		where
			smallestNrRows` :: !Int -> Int
			smallestNrRows` rows
				| (rows*pwWidth)/nrWindows>=minWidth
				= rows
				= smallestNrRows` (rows+1)
	
	rearrange :: !(!(!Vector2,!Size),!Id) !(PSt .l) -> PSt .l
	rearrange ((newPos,newSize),id) pState
		# (curSize,ioState)		= getWindowViewSize id pState.io
		  (Just curPos,ioState)	= getWindowPos id ioState
		  pState				= {pState & io=ioState}
		| curSize==newSize && curPos==newPos
		= pState
		| curSize==newSize
		= appPIO (setWindowPos id (LeftTop,OffsetVector newPos)) pState
		| curPos==newPos
		= appPIO (setWindowViewSize id newSize) pState
		# (wPtr,pState)			= accPIO (getWindowPtr id) pState
//		# pState				= hideWindow wPtr pState
		# pState				= appPIO (setWindowViewSize id newSize) pState
		# pState				= appPIO (setWindowPos id (LeftTop,OffsetVector newPos)) pState
//		# pState				= showWindow wPtr pState
		# pState = trace_n ("rearrange",id,newPos,newSize) pState
		= pState

showWindow Nothing pState = pState
showWindow (Just wPtr) pState
	= pState
//	= appPIO (appIOToolbox (snd o osShowWindow wPtr False)) pState

hideWindow Nothing pState = pState
hideWindow (Just wPtr) pState
	= pState
//	= appPIO (appIOToolbox (snd o osHideWindow wPtr False)) pState

//--

import StdArray
windowTitle2menuTitle wt :== {c \\ c <- double_amps [c \\ c <-: wt]}
double_amps [] = []
double_amps [h:t]
	| h == '&' = [h,'&':double_amps t]
	= [h:double_amps t]
//--
	
/*	addWindowToWindowMenu adds a new item to the RadioMenu of the WindowMenu if present. 
	The Id argument is the id of the window that should be added, and the Title argument its title. 
*/
addWindowToWindowMenu :: !Id !Title !(PSt .l) -> PSt .l
addWindowToWindowMenu windowId windowTitle pState
	# windowTitle			= windowTitle2menuTitle windowTitle
	# (document,pState)		= accPIO ioStGetDocumentInterface pState
	| document<>MDI
		= pState
	# (optMState,pState)	= accPIO (getMenu windowMenuId) pState
	| isNothing optMState
		= pState
	# mState				= fromJust optMState
	  wIds					= map (fromJust o snd) (getCompoundMenuElementTypes windowMenuRadioId mState)
	  titles				= map (fromJust o snd) (getMenuElementTitles wIds mState)
	  index					= findInsertIndex windowTitle titles
	  (radioId,pState)		= openId pState
	  pState				= appPIO (appWT (WT_Add windowId radioId)) pState
	  radioItem				= (windowTitle,Just radioId,Nothing,setActiveWindow windowId)// o showWindows [windowId])
	  (error,pState)		= accPIO (openRadioMenuItems windowMenuRadioId index [radioItem]) pState
//	  error = trace_n error error
	| error<>NoError
		= menuwindowmenuError "addWindowToWindowMenu" "Fatal error: could not add MenuItem to WindowMenu"
	| not (isEmpty wIds)
		= pState
//	# ioState				= setMenu windowMenuId 
//								[enableMenuElements [windowMenuCascadeId,windowMenuTileHId,windowMenuTileVId]] ioState
	# pState				= appPIO (enableMenuElements [windowMenuCascadeId,windowMenuTileHId,windowMenuTileVId]) pState
	  itemIds				= map snd (getMenuElementTypes mState)
	  (_,index)				= findMenuSeparatorIndex windowMenuTileVId itemIds
	  (error,pState)		= openMenuElements windowMenuId index Void (MenuSeparator [MenuId windowMenuSeparatorId]) pState
	| error<>NoError
		= menuwindowmenuError "addWindowToWindowMenu" "Fatal error: could not add MenuSeparator to WindowMenu"
	= pState


/*	removeWindowFromWindowMenu removes the window entry from the WindowMenu if present.
*/
removeWindowFromWindowMenu :: !Id !(IOSt .l) -> IOSt .l
removeWindowFromWindowMenu wId ioState
	# (document,ioState)	= ioStGetDocumentInterface ioState
	| document<>MDI
//		= trace_n "rem: notMDI" ioState
		= ioState
	# (optMState,ioState)	= getMenu windowMenuId ioState
	| isNothing optMState
//		= trace_n "rem: no menu" ioState
		= ioState
	# mState				= fromJust optMState
	  rIds					= map (fromJust o snd) (getCompoundMenuElementTypes windowMenuRadioId mState)
	  (wIds,ioState)		= accWT (seqList (map WT_LookupR rIds)) ioState
	  wIds					= map fromJust wIds
	  (found,index)			= findCloseIndex wId wIds
	| not found
//		= trace_n "rem: not found" ioState
		= ioState
	# ioState				= closeRadioMenuIndexElements` windowMenuRadioId [index] ioState
	| length wIds<>1
		= ioState
//	# ioState				= setMenu windowMenuId 
//								[disableMenuElements [windowMenuCascadeId,windowMenuTileHId,windowMenuTileVId]] ioState
	# ioState				= disableMenuElements [windowMenuCascadeId,windowMenuTileHId,windowMenuTileVId] ioState
	  ioState				= closemenuelements windowMenuId [windowMenuSeparatorId] ioState
	= ioState

changeWindowInWindowMenu :: !Id !String !(IOSt .l) -> IOSt .l
changeWindowInWindowMenu wId title ioState
	# title					= windowTitle2menuTitle title
	# (document,ioState)	= ioStGetDocumentInterface ioState
	| document<>MDI
//		= trace_n "change: notMDI" ioState
		= ioState
	# (optMState,ioState)	= getMenu windowMenuId ioState
	| isNothing optMState
//		= trace_n "change: no menu" ioState
		= ioState
	# (rId,ioState)			= accWT (WT_LookupW wId) ioState
	| isNothing rId
//		= trace_n "change: not found" ioState
		= ioState
	# ioState				= setMenuElementTitles [(fromJust rId,osValidateMenuItemTitle Nothing title)] ioState
	= ioState

closeRadioMenuIndexElements` :: !Id ![Index] !(IOSt .l) -> IOSt .l
closeRadioMenuIndexElements` mId indices ioState
	# (idtable,ioState)		= ioStGetIdTable ioState
	# (maybeParent,idtable)	= getIdParent mId idtable
	# ioState				= ioStSetIdTable idtable ioState
	| isNothing maybeParent
//		= trace_n "cMIE:no parent" ioState
		= ioState
	# parent				= fromJust maybeParent
	| parent.idpDevice<>MenuDevice
//		= trace_n "cMIE: not a menu" ioState
		= ioState
	# (ioId,ioState)		= ioStGetIOId ioState
	| parent.idpIOId<>ioId //|| parent.idpId<>mId
//		= trace_n "cMIE: diff io or id" ioState
		= ioState
//	| parent.idpId<>mId
//		= trace_n ("cMIE: diff id",parent.idpId,mId) ioState
	| otherwise
		= closemenuindexelements RemoveSpecialMenuElements True ioId (parent.idpId,Just mId) indices ioState

changeRadioMenuIndexElements` :: !Id !String ![Index] !(IOSt .l) -> IOSt .l
changeRadioMenuIndexElements` mId title indices ioState
	# (idtable,ioState)		= ioStGetIdTable ioState
	# (maybeParent,idtable)	= getIdParent mId idtable
	# ioState				= ioStSetIdTable idtable ioState
	| isNothing maybeParent
//		= trace_n "cMIE:no parent" ioState
		= ioState
	# parent				= fromJust maybeParent
	| parent.idpDevice<>MenuDevice
//		= trace_n "cMIE: not a menu" ioState
		= ioState
	# (ioId,ioState)		= ioStGetIOId ioState
	| parent.idpIOId<>ioId //|| parent.idpId<>mId
//		= trace_n "cMIE: diff io or id" ioState
		= ioState
//	| parent.idpId<>mId
//		= trace_n ("cMIE: diff id",parent.idpId,mId) ioState
	| otherwise
		= changemenuindexelements RemoveSpecialMenuElements True ioId (parent.idpId,Just mId) title indices ioState

changemenuindexelements :: !Bool !Bool !SystemId !(!Id,!Maybe Id) !String ![Index] !(IOSt .l) -> IOSt .l
changemenuindexelements removeSpecialElements fromRadioMenu pid loc title indices ioState
	# (rt,ioState)		= ioStGetReceiverTable ioState
	# (it,ioState)		= ioStGetIdTable ioState
	# (osdInfo,ioState)	= ioStGetOSDInfo ioState
	# ((rt,it),ioState)	= accessMenuSystemState True (removeMenusIndexItems osdInfo removeSpecialElements fromRadioMenu loc indices pid) (rt,it) ioState
	# ioState			= ioStSetIdTable it ioState
	# ioState			= ioStSetReceiverTable rt ioState
	= ioState


/*	validateWindowActivateForWindowMenu takes care that if this interactive process is an MDI process,
	and the WindowLSHandle represents a Windows instance that the WindowActivate function of the
	WindowLSHandle will select the proper RadioMenuItem of the WindowMenu if present before any other 
	actions are taken.
*/
//I a = a

validateWindowActivateForWindowMenu` :: !Id !Bool ![WindowAttribute *(.ls,PSt .p)] -> [WindowAttribute *(.ls,PSt .p)]
validateWindowActivateForWindowMenu` wId isMDI atts
	| not isMDI
//	= trace_n "NOT MDI" atts
	= atts
	# (defound,att,atts)	= remove isWindowDeactivate (WindowDeactivate id) atts
	# atts = case defound of
				True	-> [WindowDeactivate (getWindowDeactivateFun att o (noLS (deselectWindow wId))):atts]
				_		-> [WindowDeactivate (noLS (deselectWindow wId)):atts]
	# (found,att,atts)	= remove isWindowActivate (WindowActivate id) atts
	| not found
//	= trace_n "NOT FOUND" [WindowActivate (noLS (selectWindow wId)):atts]
	= [WindowActivate (noLS (selectWindow wId)):atts]
	# activateF			= getWindowActivateFun att
//	= trace_n "FOUND & MODIFIED" [WindowActivate (activateF o (noLS (selectWindow wId))):atts]
	= [WindowActivate (activateF o (noLS (selectWindow wId))):atts]
where
	selectWindow :: !Id !(PSt .l) -> PSt .l
	selectWindow wId pState
		#! pState = trace_n ("activate: "+++toString wId) pState
		# (document,pState)= accPIO ioStGetDocumentInterface pState
		| document<>MDI
			= pState
//		# ioState			= setMenu windowMenuId [selectRadioMenuItem windowMenuRadioId id] ioState
		# (rId,pState)		= accPIO (accWT (WT_LookupW wId)) pState
		| isNothing rId
			= pState
		# rId				= fromJust rId
		= appPIO (selectRadioMenuItem windowMenuRadioId rId) pState
	deselectWindow :: !Id !(PSt .l) -> PSt .l
	deselectWindow wId pState
		#! pState = trace_n ("deactivate: "+++toString wId) pState
		= pState
	
validateWindowActivateForWindowMenu :: !Id !(WindowLSHandle .ls (PSt .l)) !(IOSt .l)
										-> (!WindowLSHandle .ls (PSt .l),  !IOSt .l)
validateWindowActivateForWindowMenu wId dlsH=:{wlsHandle=dH=:{whAtts,whKind}} ioState
	| whKind<>IsWindow
	= (dlsH,ioState)
	# (document,ioState)= ioStGetDocumentInterface ioState
	| document<>MDI
	= (dlsH,ioState)
	# (found,att,atts)	= remove isWindowActivate (WindowActivate id) whAtts
	| not found
	= ({dlsH & wlsHandle={dH & whAtts=[WindowActivate (noLS (selectWindow wId)):atts]}},ioState)
	# activateF			= getWindowActivateFun att
	= ({dlsH & wlsHandle={dH & whAtts=[WindowActivate (activateF o (noLS (selectWindow wId))):atts]}},ioState)
where
	selectWindow :: !Id !(PSt .l) -> PSt .l
	selectWindow id pState=:{io}
		# (document,ioState)= ioStGetDocumentInterface io
		| document<>MDI
		= {pState & io=ioState}
//		# ioState			= setMenu windowMenuId [selectRadioMenuItem windowMenuRadioId id] ioState
		# ioState			= selectRadioMenuItem windowMenuRadioId id ioState
		= {pState & io=ioState}


//	Index locating functions.

findInsertIndex :: x ![x] -> Int	| Ord x
findInsertIndex x ys
	= findInsertIndex` 0 x ys
where
	findInsertIndex` :: !Int x ![x] -> Int	| Ord x
	findInsertIndex` index x [y:ys]
		| x<=y
		= index
		= findInsertIndex` (index+1) x ys
	findInsertIndex` index _ _
		= index+1

findCloseIndex :: x ![x] -> (!Bool,!Int)	| Eq x
findCloseIndex id ids
	= findCloseIndex` 1 id ids
where
	findCloseIndex` :: !Int x ![x] -> (!Bool,!Int)	| Eq x
	findCloseIndex` index x [y:ys]
		| x==y
		= (True,index)
		= findCloseIndex` (index+1) x ys
	findCloseIndex` index _ _
		= (False,index)

findMenuSeparatorIndex :: x ![Maybe x] -> (!Bool,!Int)	| Eq x
findMenuSeparatorIndex id opt_ids
	= findMenuSeparatorIndex` 1 id opt_ids
where
	findMenuSeparatorIndex` :: !Int x ![Maybe x] -> (!Bool,!Int)	| Eq x
	findMenuSeparatorIndex` index x [y:ys]
		| isJust y && x==fromJust y
		= (True,index)
		= findMenuSeparatorIndex` (index+1) x ys
	findMenuSeparatorIndex` index _ _
		= (False,index)

//--

getWindowPtr :: !Id !(IOSt .l) -> (!Maybe OSWindowPtr,!IOSt .l)
getWindowPtr id ioState
	# (found,wDevice,ioState)	= ioStGetDevice WindowDevice ioState
	| not found
		= (Nothing,ioState)
	# windows					= windowSystemStateGetWindowHandles wDevice
	  (found,wsH,windows)		= getWindowHandlesWindow (toWID id) windows
	| not found
		= (Nothing,ioStSetDevice (WindowSystemState windows) ioState)
	| otherwise
		# (wPtr,wsH)			= getWindowStateHandleWindowPtr wsH
		= (Just wPtr,ioStSetDevice (WindowSystemState (setWindowHandlesWindow wsH windows)) ioState)

getWindowStateHandleWindowPtr :: !(WindowStateHandle .pst) -> *(!OSWindowPtr,!WindowStateHandle .pst)
getWindowStateHandleWindowPtr wsH=:{wshIds}
	= (wshIds.wPtr,wsH)

//--

appWT f ioState
	# (osd,ioState)			= ioStGetOSDInfo ioState
	  wt					= getOSDInfoWindowTable osd
	  wt					= f wt
	  osd					= setOSDInfoWindowTable wt osd
	  ioState				= ioStSetOSDInfo osd ioState
	= ioState

accWT f ioState
	# (osd,ioState)			= ioStGetOSDInfo ioState
	  wt					= getOSDInfoWindowTable osd
	  (r,wt)				= f wt
	  osd					= setOSDInfoWindowTable wt osd
	  ioState				= ioStSetOSDInfo osd ioState
	= (r,ioState)

//-- ALSO in StdMenu and in menuinternal...

accessMenuSystemState :: !Bool
						 !(OSMenuBar -> u:x -> u:((MenuHandles (PSt .l)) -> u:(*OSToolbox -> *(u:x,MenuHandles (PSt .l),*OSToolbox))))
						 u:x
						 !(IOSt .l)
				  -> *(u:x,!IOSt .l)
accessMenuSystemState redrawMenus f x ioState
	# (found,mDevice,ioState)	= ioStGetDevice MenuDevice ioState
	| not found
		= (x,ioState)
	# (osdinfo,ioState)			= ioStGetOSDInfo ioState
	  maybeOSMenuBar			= getOSDInfoOSMenuBar osdinfo
	| isNothing maybeOSMenuBar	// This condition should never hold
		= menuwindowmenuFatalError "accessMenuSystemState" "could not retrieve OSMenuBar from OSDInfo"
	# osMenuBar					= fromJust maybeOSMenuBar
	# (tb,ioState)				= getIOToolbox ioState
	  menus						= menuSystemStateGetMenuHandles mDevice
	# (x,menus,tb)				= f osMenuBar x menus tb
	| not redrawMenus
		# ioState				= setIOToolbox tb ioState
		= (x,ioStSetDevice (MenuSystemState menus) ioState)
	| otherwise
		# ioState				= setIOToolbox (osDrawMenuBar osMenuBar tb) ioState
		= (x,ioStSetDevice (MenuSystemState menus) ioState)

