implementation module menuevent


import	StdBool, StdList, StdMisc, StdFunc
//import	clCrossCall_12
//from	clCCall_12			import WinMakeCString, CSTR, ALTBIT, CTRLBIT, SHIFTBIT
from	osmenu				import osMenuItemCheck
import	commondef, deviceevents, iostate
from	menuaccess			import menuStateHandleGetHandle, menuStateHandleGetMenuId
from	processstack		import topShowProcessShowState
from	StdProcessAttribute	import getProcessToolbarAtt, isProcessToolbar
from	StdPSt				import accPIO
import events,menus,desk,windows
import osdocumentinterface,menuaccess,menudefaccess,menudevice
import osutil,oskey,osmenu

trace_n _ f :== f
//import dodebug


menueventFatalError :: String String -> .x
menueventFatalError function error
	= fatalError function "menuevent" error


/*	menuEvent filters the scheduler events that can be handled by this menu device.
	For the time being no timer menu elements are added, so these events are ignored.
	menuEvent assumes that it is not applied to an empty IOSt and that its device is
	present.
*/
menuEvent :: !SchedulerEvent !(PSt .l) -> (!Bool,!Maybe DeviceEvent,!SchedulerEvent,!PSt .l)
menuEvent schedulerEvent pState
	# (hasMenuDevice,pState)	= accPIO (ioStHasDevice MenuDevice) pState
	| not hasMenuDevice			// This condition should never hold
		= menueventFatalError "menuEvent" "MenuDevice.dEvent applied while MenuDevice not present in IOSt"
	| otherwise
		= menuEvent schedulerEvent pState
where
	menuEvent :: !SchedulerEvent !(PSt .l) -> (!Bool,!Maybe DeviceEvent,!SchedulerEvent,!PSt .l)
	menuEvent schedulerEvent=:(ScheduleOSEvent osEvent _) pState=:{io=ioState}
		# (ioIsActive,ioState)				= ioStIsActive ioState
		| not ioIsActive
			# pState						= {pState & io=ioState}
			= (False,Nothing,schedulerEvent,pState)
		| isToolbarOSEvent osEvent
			# (osdInfo,ioState)				= ioStGetOSDInfo ioState
			# (myEvent,replyToOS,deviceEvent,ioState)
											= filterToolbarEvent osdInfo osEvent ioState
			# pState						= {pState & io=ioState}
			  schedulerEvent				= if (isJust replyToOS) (ScheduleOSEvent osEvent (fromJust replyToOS)) schedulerEvent
			= (myEvent,deviceEvent,schedulerEvent,pState)
		| isMenuOSEvent osEvent
			# (osdInfo,ioState)				= ioStGetOSDInfo ioState
			# (processStack,ioState)		= ioStGetProcessStack ioState
			  (found,systemId)				= topShowProcessShowState processStack
			# (ioId,ioState)				= ioStGetIOId ioState
			# (tb,ioState)					= getIOToolbox ioState
			# (found,mDevice,ioState)		= ioStGetDevice MenuDevice ioState
			# menus							= menuSystemStateGetMenuHandles mDevice
			# (myEvent,replyToOS,deviceEvent,menus,tb)
			  								= filterOSEvent osdInfo osEvent (found && systemId==ioId) menus tb
			# ioState						= ioStSetDevice (MenuSystemState menus) ioState
			# ioState						= setIOToolbox tb ioState
			# pState						= {pState & io=ioState}
			  schedulerEvent				= if (isJust replyToOS) (ScheduleOSEvent osEvent (fromJust replyToOS)) schedulerEvent
			= (myEvent,deviceEvent,schedulerEvent,pState)
		| otherwise
			# pState						= {pState & io=ioState}
			= (False,Nothing,schedulerEvent,pState)
	where
		isMenuOSEvent :: !OSEvent -> Bool
		isMenuOSEvent (_,MouseDownEvent,_,_,_,_,_)			= True
		isMenuOSEvent (_,KeyUpEvent,_,_,_,_,_)				= True
		isMenuOSEvent (_,KeyDownEvent,_,_,_,_,_)			= True
		isMenuOSEvent (_,AutoKeyEvent,_,_,_,_,_)			= True
		isMenuOSEvent _										= False
		
		isToolbarOSEvent :: !OSEvent -> Bool
		isToolbarOSEvent _						= False
	
	menuEvent schedulerEvent=:(ScheduleMsgEvent msgEvent) pState=:{io=ioState}
		# (ioId,ioState)		= ioStGetIOId ioState
		| ioId<>recLoc.rlIOId || recLoc.rlDevice<>MenuDevice
			= (False,Nothing,schedulerEvent,{pState & io=ioState})
		| otherwise
			# (found,mDevice,ioState)	= ioStGetDevice MenuDevice ioState
			  menus						= menuSystemStateGetMenuHandles mDevice
			  (found,menus)				= hasMenuHandlesMenu recLoc.rlParentId menus
			  deviceEvent				= if found (Just (ReceiverEvent msgEvent)) Nothing
			# ioState					= ioStSetDevice (MenuSystemState menus) ioState
			= (found,deviceEvent,schedulerEvent,{pState & io=ioState})
	where
		recLoc							= getMsgEventRecLoc msgEvent
		
		hasMenuHandlesMenu :: !Id !(MenuHandles .pst) -> (!Bool,!MenuHandles .pst)
		hasMenuHandlesMenu menuId mHs=:{mMenus}
			# (found,mMenus)= ucontains (eqMenuId menuId) mMenus
			= (found,{mHs & mMenus=mMenus})
		where
			eqMenuId :: !Id !(MenuStateHandle .pst) -> *(!Bool,!MenuStateHandle .pst)
			eqMenuId theId msH
				# (mId,msH)	= menuStateHandleGetMenuId msH
				= (theId==mId,msH)
	
	menuEvent schedulerEvent pState
		= (False,Nothing,schedulerEvent,pState)


/*	filterToolbarEvent filters the OSEvents that can be handled by this menu device.
*/
filterToolbarEvent :: !OSDInfo !OSEvent !(IOSt .l) -> (!Bool,!Maybe [Int],!Maybe DeviceEvent,!IOSt .l)
filterToolbarEvent _ _ _
	= menueventFatalError "filterToolbarEvent" "unmatched OSEvent"


/*	filterOSEvent filters the OSEvents that can be handled by this menu device.
		The Bool argument is True iff the parent process is visible and active.
*/
filterOSEvent :: !OSDInfo !OSEvent !Bool !(MenuHandles .pst) !*OSToolbox -> (!Bool,!Maybe [Int],!Maybe DeviceEvent,!MenuHandles .pst,!*OSToolbox)
filterOSEvent osdInfo osEvent=:(_,MouseDownEvent,mess,i,h,v,mods) parentActive menus tb
	# (region,wPtr,tb)				= FindWindow h v tb
	| region==menuBar
		# (menuId,itemNr,tb)		= MenuSelect h v tb
		# (ret,tb)					= ReceivedQuit tb
		| ret == 1
			= (True,Nothing,Just ProcessRequestClose,menus,tb)
		# (ok,deviceEvent,menus,tb) = menuSelection True menuId itemNr mods menus osdInfo tb
		= (ok,Nothing,deviceEvent,menus,tb)
	= (False,Nothing,Nothing,menus,tb)
where
	menuBar					= 1
	inSysWindow				= 2

filterOSEvent _ osEvent=:(_,KeyUpEvent,message,_,_,_,mods) parentActive menus tb
	# (ret,tb)					= ReceivedQuit tb
	| ret == 1
		= (True,Nothing,Just ProcessRequestClose,menus,tb)
	| commandKeyUp
		= (False,Nothing,Nothing,menus,tb)
	# (menuId,itemNr,tb)	= getMenuEvent osEvent tb
	  tb					= HiliteMenu 0 tb
	| menuId<>0
		= (True,Nothing,Nothing, menus,tb)
	= (True,Nothing,Nothing,menus,tb)
where
	commandKeyUp			= mods bitand 256==0

filterOSEvent osdInfo osEvent=:(_,what,message,_,_,_,mods) parentActive menus tb
	| what<>KeyDownEvent && what<>AutoKeyEvent || commandKeyUp
		= (False,Nothing,Nothing,menus,tb)
	# (menuId,itemNr,tb)	= getMenuEvent osEvent tb
	| menuId<>0
		# (ok,deviceEvent,menus,tb) = menuSelection False menuId itemNr mods menus osdInfo tb
		= (True,Nothing,deviceEvent,menus,tb)
	// if isSpecial leave unhandled so that keyboard function can use it...
	| isSpecialKey macCode
		= (False,Nothing,Nothing,menus,tb)
	= (True,Nothing,Nothing,menus,tb)
where
	commandKeyUp			= mods bitand 256==0
	macCode					= getMacCode message

filterOSEvent _ _ _ _ _
	= menueventFatalError "filterOSEvent" "unmatched OSEvent"

import code from "menuaid."
import code from library "menuaid_library"
//import code from library "me_library"

getMenuEvent osEvent=:(_,_,message,_,_,_,mods) tb
//	# (menuId,itemNr,tb)	= MenuKey charCode tb
//	# (menuId,itemNr,tb)	= MenuEvent osEvent tb
	# ret					= getCMenuEvent keyc`
	# cc1					= ret bitand 255
	# cc2					= (ret >> 16) bitand 255
	# (menuId,itemNr,tb)	= MenuKey cc1 tb
	| menuId <> 0
		# tb = trace_n ("MenuKey1",(virtCode,keyc`,ret),(menuId,itemNr),(cc1,cc2,charCode)) tb
		= (menuId,itemNr,tb)
	# (menuId,itemNr,tb)	= MenuKey cc2 tb
	# tb = trace_n ("MenuKey2",(virtCode,keyc`,ret),(menuId,itemNr),(cc1,cc2,charCode)) tb
	= (menuId,itemNr,tb)
where
	charCode	= message bitand 255
	virtCode	= (message>>8) bitand 255
//	mods`		= mods bitand 0x0FF00
	mods`		= mods bitand 0x02700
	keyc`		= mods` bitor virtCode
//	KCHRPtr		= Ptr (GetScriptManagerVariable(smKCHRCache))
//	tranKey		= KeyTranslate KCHRPtr keyc` 0 

getCMenuEvent :: !Int -> Int
getCMenuEvent _ = code {
	ccall getMenuEvent "I:I"
	}


menuSelection :: !Bool !Int !Int !Int !*(MenuHandles .ps) !OSDInfo !*OSToolbox -> *(!Bool,!Maybe DeviceEvent,!*MenuHandles .ps,!*OSToolbox)
menuSelection tracking noChoice=:0 _ _ menus _ tb
	# tb							= HiliteMenu 0 tb
	| tracking
		= (True,Nothing,menus,tb)
	= (False,Nothing, menus,tb)
menuSelection _ AppleMenuId itemNr mods menus=:{mEnabled,mMenus=mHs} osdInfo tb
	# tb							= HiliteMenu 0 tb
	| itemNr==1 && mEnabled
		// should generate About... here
		# deviceEvent				= Nothing
		= (True, deviceEvent, menus,tb)
	= (True,Nothing,menus,tb)
menuSelection _ menuId itemNr mods menus=:{mEnabled,mMenus=mHs} osdInfo tb
	# tb							= HiliteMenu 0 tb
	# (found,deviceEvent,mHs,tb)	= getSelectedMenuStateHandlesItem menuId itemNr mods mHs tb
	= (found,deviceEvent,{menus & mMenus=mHs},tb)


getSelectedMenuStateHandlesItem :: !Int !Int !Int ![MenuStateHandle .pst] !*OSToolbox
				-> (!Bool,!Maybe DeviceEvent,![MenuStateHandle .pst],!*OSToolbox)
getSelectedMenuStateHandlesItem menuId itemNr mods msHs tb
	# (isEmpty,msHs)				= uisEmpty msHs
	| isEmpty
		= (False,Nothing,msHs,tb)
	# (msH,msHs)					= hdtl msHs
	# (found,menuEvent,msH,tb)		= getSelectedMenuStateHandleItem menuId itemNr (toModifiers mods) msH tb
	| found
		= (found,menuEvent,[msH:msHs],tb)
	| otherwise
		# (found,menuEvent,msHs,tb)	= getSelectedMenuStateHandlesItem menuId itemNr mods msHs tb
		= (found,menuEvent,[msH:msHs],tb)


getSelectedMenuStateHandleItem :: !Int !Int !Modifiers !(MenuStateHandle .pst) !*OSToolbox
				-> (!Bool,!Maybe DeviceEvent,!MenuStateHandle .pst, !*OSToolbox)
getSelectedMenuStateHandleItem menuId itemNr mods msH=:(MenuLSHandle mlsH=:{mlsHandle=mH=:{mSelect,mHandle,mMenuId,mItems,mOSMenuNr}}) tb
	| not mSelect
		= (False,Nothing,msH,tb)
	| otherwise
		# (found,menuEvent,_,_,itemHs,tb)	= getSelectedMenuElementHandlesItem menuId itemNr mHandle mMenuId mOSMenuNr mods [] 1 mItems tb
		= (found,menuEvent,MenuLSHandle {mlsH & mlsHandle={mH & mItems=itemHs}},tb)
where
	getSelectedMenuElementHandlesItem :: !Int !Int !OSMenu !Id !OSMenuNr !Modifiers ![Int] !Int ![MenuElementHandle .ls .pst] !*OSToolbox
								  -> (!Bool,!Maybe DeviceEvent,![Int],!Int,![MenuElementHandle .ls .pst],!*OSToolbox)
	getSelectedMenuElementHandlesItem menuId itemNr mH mMenuId mOSMenuNr mods parents zIndex itemHs tb
		# (isEmpty,itemHs)	= uisEmpty itemHs
		| isEmpty
			= (False,Nothing,parents,zIndex,itemHs,tb)
		# (itemH,itemHs)							= hdtl itemHs
		# (found,menuEvent,parents,zIndex,itemH,tb)	= getSelectedMenuElementHandle menuId itemNr mH mMenuId mOSMenuNr mods parents zIndex itemH tb
		| found
			= (found,menuEvent,parents,zIndex,[itemH:itemHs],tb)
		| otherwise
			# (found,menuEvent,parents,zIndex,itemHs,tb)= getSelectedMenuElementHandlesItem menuId itemNr mH mMenuId mOSMenuNr mods parents zIndex itemHs tb
			= (found,menuEvent,parents,zIndex,[itemH:itemHs],tb)
	where
		getSelectedMenuElementHandle :: !Int !Int !OSMenu !Id !OSMenuNr !Modifiers ![Int] !Int !(MenuElementHandle .ls .pst) !*OSToolbox
								 -> (!Bool,!Maybe DeviceEvent,![Int],!Int, !MenuElementHandle .ls .pst, !*OSToolbox)
		
		getSelectedMenuElementHandle menuId itemNr mH mMenuId mOSMenuNr mods parents zIndex itemH=:(MenuItemHandle {mOSMenuItem,mItemId}) tb
			| itemNr==zIndex && menuId == mOSMenuNr
				= (True,Just (MenuTraceEvent {mtId=mMenuId,mtParents=parents,mtItemNr=itemNr-1,mtModifiers= mods}),parents,zIndex+1,itemH,tb)
			| otherwise
				= (False,Nothing,parents,zIndex+1,itemH,tb)

		getSelectedMenuElementHandle menuId itemNr mH mMenuId mOSMenuNr mods parents zIndex itemH=:(SubMenuHandle submenuH=:{mSubOSMenuNr,mSubSelect,mSubHandle,mSubItems}) tb
			| not mSubSelect
				= (False,Nothing,parents,zIndex+1,itemH,tb)
			| otherwise
				#! parents1	= parents++[zIndex-1]
				# (found,menuEvent,parents1,_,itemHs,tb)
							= getSelectedMenuElementHandlesItem menuId itemNr mSubHandle mMenuId mSubOSMenuNr mods parents1 1 mSubItems tb
				# itemH		= SubMenuHandle {submenuH & mSubItems=itemHs}
				  parents	= if found parents1 parents
				= (found,menuEvent,parents,zIndex+1,itemH,tb)
		
		getSelectedMenuElementHandle menuId itemNr mH mMenuId mOSMenuNr mods parents zIndex (RadioMenuHandle rH=:{mRadioSelect,mRadioItems=itemHs,mRadioIndex}) tb
			# (nrRadios,itemHs)	= ulength itemHs
			| not mRadioSelect
				= (False,Nothing,parents,zIndex+nrRadios,RadioMenuHandle {rH & mRadioItems=itemHs},tb)
			# (found,menuEvent,parents,zIndex1,itemHs,tb)	= getSelectedMenuElementHandlesItem menuId itemNr mH mMenuId mOSMenuNr mods parents zIndex itemHs tb
			| not found
				= (found,menuEvent,parents,zIndex1,RadioMenuHandle {rH & mRadioItems=itemHs},tb)
			# curIndex	= mRadioIndex
			  newIndex	= zIndex1-zIndex
			| curIndex==newIndex
				= (found,menuEvent,parents,zIndex1,RadioMenuHandle {rH & mRadioItems=itemHs},tb)
			| otherwise
				# (before,[itemH:after])= splitAt (curIndex-1) itemHs
				# (curH,itemH)			= getMenuItemOSMenuItem itemH
				# (before,[itemH:after])= splitAt (newIndex-1) (before ++ [itemH:after])
				# (newH,itemH)			= getMenuItemOSMenuItem itemH
				# tb					= osMenuItemCheck False mH curH curIndex (curIndex+zIndex-1) tb
				# tb					= osMenuItemCheck True  mH newH newIndex (zIndex1-1) tb
				= (found,menuEvent,parents,zIndex1,RadioMenuHandle {rH & mRadioItems=before ++ [itemH:after],mRadioIndex=newIndex},tb)
		where
			getMenuItemOSMenuItem :: !*(MenuElementHandle .ls .pst) -> (!OSMenuItem,!MenuElementHandle .ls .pst)
			getMenuItemOSMenuItem itemH=:(MenuItemHandle {mOSMenuItem}) = (mOSMenuItem,itemH)
		
		getSelectedMenuElementHandle menuId itemNr mH mMenuId mOSMenuNr mods parents zIndex (MenuListLSHandle itemHs) tb
			# (found,menuEvent,parents,zIndex,itemHs,tb)	= getSelectedMenuElementHandlesItem menuId itemNr mH mMenuId mOSMenuNr mods parents zIndex itemHs tb
			= (found,menuEvent,parents,zIndex,MenuListLSHandle itemHs,tb)
		
		getSelectedMenuElementHandle menuId itemNr mH mMenuId mOSMenuNr mods parents zIndex (MenuExtendLSHandle mExH=:{mExtendItems=itemHs}) tb
			# (found,menuEvent,parents,zIndex,itemHs,tb)	= getSelectedMenuElementHandlesItem menuId itemNr mH mMenuId mOSMenuNr mods parents zIndex itemHs tb
			= (found,menuEvent,parents,zIndex,MenuExtendLSHandle {mExH & mExtendItems=itemHs},tb)
		
		getSelectedMenuElementHandle menuId itemNr mH mMenuId mOSMenuNr mods parents zIndex (MenuChangeLSHandle mChH=:{mChangeItems=itemHs}) tb
			# (found,menuEvent,parents,zIndex,itemHs,tb)	= getSelectedMenuElementHandlesItem menuId itemNr mH mMenuId mOSMenuNr mods parents zIndex itemHs tb
			= (found,menuEvent,parents,zIndex,MenuChangeLSHandle {mChH & mChangeItems=itemHs},tb)
		
		getSelectedMenuElementHandle _ _ _ _ _ _ parents zIndex itemH=:(MenuReceiverHandle _) tb
			= (False,Nothing,parents,zIndex,itemH,tb)

		getSelectedMenuElementHandle _ _ _ _ _ _ parents zIndex itemH tb
			= (False,Nothing,parents,zIndex+1,itemH,tb)


/*	popUpMenuEvent returns the proper DeviceEvent for PopUpMenu selections
*/

popUpMenuEvent :: !OSTrackPopUpMenu !(MenuStateHandle .ps) !*OSToolbox -> (!Maybe DeviceEvent, !MenuStateHandle .ps, !*OSToolbox)
//popUpMenuEvent {ospupItem=PopUpTrackedByIndex menuId itemNr,ospupModifiers=mods} msH tb
popUpMenuEvent {ospupItem=PopUpTrackedByIndex _ itemNr,ospupModifiers=mods} msH=:(MenuLSHandle {mlsHandle={mOSMenuNr=menuId}}) tb
	# (found,menuEvent,msH,tb)	= getSelectedMenuStateHandleItem menuId itemNr mods msH tb
	= (menuEvent,msH,tb)
popUpMenuEvent _ _ _
	= menueventFatalError "popUpMenuEvent" "PopUpTrackedByItemId not expected"

//--

import code from "cae."

ReceivedQuit :: !*OSToolbox -> (!Int,!*OSToolbox)
ReceivedQuit _ = code {
	ccall ReceivedQuit ":I:I"
	}
