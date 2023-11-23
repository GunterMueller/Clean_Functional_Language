implementation module WhiteBox


import	StdBool, StdFunc, StdInt, StdList, StdMisc, StdTuple
import	osdocumentinterface, ostoolbox, ostooltip, oswindow
import	cast, commondef, controlaccess, controllayout, controlrelayout, controlvalidate, id, iostate, StdControlAttribute, StdControlClass, StdId
import	windowaccess, windowclipstate, wstate
from	windowupdate	import updatewindowbackgrounds
from	receiverid		import unbindRIds
from	StdPSt			import appPIO


WhiteBoxFatalError :: String String -> .x
WhiteBoxFatalError function error
	= fatalError function "WhiteBox" error


::	WhiteBoxId ls = WhiteBoxId !Id

openWhiteBoxId :: !*env -> (!WhiteBoxId .ls,!*env) | Ids env
openWhiteBoxId env
	# (id,env) = openId env
	= (WhiteBoxId id,env)

whiteBoxIdtoId :: !(WhiteBoxId .ls) -> Id
whiteBoxIdtoId (WhiteBoxId id) = id

instance Controls (WhiteBox cDef) | Controls cDef where
	controlToHandles (WhiteBox (WhiteBoxId id) gui atts) pSt
		= controlToHandles (LayoutControl gui [ControlId id:atts]) pSt
	
	getControlType _ = "WhiteBox"

openWhiteBoxControls :: !(WhiteBoxId .ls) .(cdef .ls (PSt .l)) !(PSt .l) -> (!ErrorReport,!PSt .l) | Controls cdef
openWhiteBoxControls wbId=:(WhiteBoxId cId) newControls pState=:{io=ioState}
	# (maybeId,ioState)			= getParentWindowId cId ioState
	| isNothing maybeId
		= (ErrorUnknownObject,{pState & io=ioState})
	# wId						= fromJust maybeId
	# (found,wDevice,ioState)	= ioStGetDevice WindowDevice ioState
	| not found
		= (ErrorUnknownObject,{pState & io=ioState})
	# wHs						= windowSystemStateGetWindowHandles wDevice
	# (found,wsH,wHs)			= getWindowHandlesWindow (toWID wId) wHs
	| not found
		= (ErrorUnknownObject,{pState & io=ioStSetDevice (WindowSystemState wHs) ioState})
    // Mike //
    # (wKind,wsH)				= getWindowStateHandleWindowKind wsH
    | wKind==IsGameWindow
		= (OtherError "WrongObject",{pState & io=ioStSetDevice (WindowSystemState (setWindowHandlesWindow wsH wHs)) ioState})
    ///
	# (cs,pState)				= controlToHandles newControls {pState & io=ioState}
	# newItemHs					= map controlStateToWElementHandle cs
	  (currentIds,wsH)			= getWindowStateHandleIds wsH
	  (disjoint,newItemHs)		= disjointControlIds currentIds newItemHs
	| not disjoint
		= (ErrorIdsInUse,appPIO (ioStSetDevice (WindowSystemState (setWindowHandlesWindow wsH wHs))) pState)
	# (rt,ioState)				= ioStGetReceiverTable pState.io
	# (it,ioState)				= ioStGetIdTable ioState
	# (ioId,ioState)			= ioStGetIOId ioState
	  (ok,newItemHs,rt,it)		= controlIdsAreConsistent ioId wId newItemHs rt it
	# ioState					= ioStSetIdTable it ioState
	# ioState					= ioStSetReceiverTable rt ioState
	| not ok
		# ioState				= ioStSetDevice (WindowSystemState (setWindowHandlesWindow wsH wHs)) ioState
		# pState				= {pState & io=ioState}
		= (ErrorIdsInUse,pState)
	| otherwise
		# (osdInfo, ioState)	= ioStGetOSDInfo ioState
		# (wMetrics,ioState)	= ioStGetOSWindowMetrics ioState
		# (tb,ioState)			= getIOToolbox ioState
		# (ok,wsH,tb)			= openrecursivecontrols osdInfo wMetrics wbId newItemHs wsH tb
		# ioState				= setIOToolbox tb ioState
		# ioState				= ioStSetDevice (WindowSystemState (setWindowHandlesWindow wsH wHs)) ioState
		# pState				= {pState & io=ioState}
		= (if ok NoError ErrorUnknownObject,pState)

//	openrecursivecontrols is copied and modified from opencompoundcontrols in windowcontrols.icl:

/*	openrecursivecontrols adds the given controls to the recursive control of the given window. 
	It is assumed that the new controls do not conflict with the current controls.
*/
openrecursivecontrols :: !OSDInfo !OSWindowMetrics !(WhiteBoxId .ls) ![WElementHandle .ls .pst] !(WindowStateHandle .pst) !*OSToolbox
																					   -> (!Bool,!WindowStateHandle .pst, !*OSToolbox)
openrecursivecontrols osdInfo wMetrics wbId=:(WhiteBoxId compoundId) newItems 
					  wsH=:{wshIds,wshHandle=Just wlsH=:{wlsHandle=wH=:{whItems,whAtts,whDefaultId,whCancelId,whSelect,whShow,whItemNrs,whKind,whSize,whWindowInfo}}} 
					  tb
	# (found,nrSkip,_,itemNrs,oldItemHs)
									= addControls wbId newItems whItemNrs whItems
	| not found
		= (False,{wsH & wshHandle=Just {wlsH & wlsHandle={wH & whItems=oldItemHs}}},tb)
	| otherwise
		# (curw,curh)				= (whSize.w-(if visVScroll wMetrics.osmVSliderWidth 0),whSize.h-(if visHScroll wMetrics.osmHSliderHeight 0))
		  curSize					= {w=curw,h=curh}
		  wFrame					= sizeToRect curSize
		  hMargins					= getWindowHMargins   whKind wMetrics whAtts
		  vMargins					= getWindowVMargins   whKind wMetrics whAtts
		  spaces					= getWindowItemSpaces whKind wMetrics whAtts
		  reqSize					= {w=curw-fst hMargins-snd hMargins,h=curh-fst vMargins-snd vMargins}
		# (oldItemHs`,oldItemHs,tb)	= getWElementHandles` wPtr oldItemHs tb
		# (derSize,newItemHs,tb)	= layoutControls wMetrics hMargins vMargins spaces reqSize zero [(domain,origin)] oldItemHs tb
	//	# tb						= checkNewWindowSize curSize derSize wPtr osdInfo tb	// PA: curSize might be bigger than domain, then you shouldn't resize!
		# (newItemHs,tb)			= createRecursiveControls wMetrics compoundId nrSkip whDefaultId whCancelId whSelect wPtr newItemHs tb
		  wH						= {wH & whItemNrs=itemNrs,whItems=newItemHs}
		# (wH,tb)					= forceValidWindowClipState wMetrics True wPtr wH tb
		# (updRgn,newItemHs,tb)		= relayoutControls wMetrics whSelect whShow wFrame wFrame zero zero wPtr whDefaultId oldItemHs` wH.whItems tb
		# (wH,tb)					= updatewindowbackgrounds wMetrics updRgn wshIds {wH & whItems=newItemHs} tb
		= (True,{wsH & wshHandle=Just {wlsH & wlsHandle=wH}},tb)
where
	wPtr							= wshIds.wPtr
	domain							= rectToRectangle domainRect
	(origin,domainRect,hasHScroll,hasVScroll)
									= case whWindowInfo of
										WindowInfo info	-> (info.windowOrigin,info.windowDomain,isJust info.windowHScroll,isJust info.windowVScroll)
										other			-> (zero,             sizeToRect whSize,False,False)
	(visHScroll,visVScroll)			= osScrollbarsAreVisible wMetrics domainRect (toTuple whSize) (hasHScroll,hasVScroll)
	
	addControls :: !(WhiteBoxId .ls`) ![WElementHandle .ls` .pst] [Int] ![WElementHandle .ls .pst]
					   -> (!Bool,!Int,![WElementHandle .ls` .pst],[Int],![WElementHandle .ls .pst])
	addControls _ newItems itemNrs []
		= (False,0,newItems,itemNrs,[])
	addControls wbId newItems itemNrs [itemH:itemHs]
		# (found,nrSkip,newItems,itemNrs,itemH)		= addControls` wbId newItems itemNrs itemH
		| found
			= (found,nrSkip,newItems,itemNrs,[itemH:itemHs])
		| otherwise
			# (found,nrSkip,newItems,itemNrs,itemHs)= addControls wbId newItems itemNrs itemHs
			= (found,nrSkip,newItems,itemNrs,[itemH:itemHs])
	where
		addControls` :: !(WhiteBoxId .ls`) ![WElementHandle .ls` .pst] [Int] !(WElementHandle .ls .pst)
							-> (!Bool,!Int,![WElementHandle .ls` .pst],[Int], !WElementHandle .ls .pst)
		addControls` wbId newItems itemNrs (WItemHandle itemH)
			# (found,nrSkip,newItems,itemNrs,itemH) = addControls`` wbId newItems itemNrs itemH
			= (found,nrSkip,newItems,itemNrs,WItemHandle itemH)
		where
			addControls`` :: !(WhiteBoxId .ls`) ![WElementHandle .ls` .pst] [Int] !(WItemHandle .ls .pst)
								 -> (!Bool,!Int,![WElementHandle .ls` .pst],[Int], !WItemHandle .ls .pst)
			addControls`` wbId=:(WhiteBoxId compoundId) newItems itemNrs itemH=:{wItemKind,wItemId}
				| not (isRecursiveControl wItemKind)
					= (False,0,newItems,itemNrs,itemH)
				| not (identifyMaybeId compoundId wItemId)
					# (found,nrSkip,newItems,itemNrs,itemHs)	= addControls wbId newItems itemNrs itemH.wItems
					| found && wItemKind==IsCompoundControl
						= (found,nrSkip,newItems,itemNrs,invalidateCompoundClipState {itemH & wItems=itemHs})
					// otherwise
						= (found,nrSkip,newItems,itemNrs,{itemH & wItems=itemHs})
				| otherwise
					# (nrSkip,curItems)	= ulength itemH.wItems
					  (itemNrs,newItems)= genWElementItemNrs itemNrs newItems
					  newItems			= cast newItems		// PA: type cast included to enforce type correctness
					  itemH				= {itemH & wItems=curItems++newItems}
					  itemH				= if (wItemKind==IsCompoundControl) (invalidateCompoundClipState itemH) itemH
					= (True,nrSkip,[],itemNrs,itemH)
		
		addControls` wbId newItems itemNrs (WListLSHandle itemHs)
			# (found,nrSkip,newItems,itemNrs,itemHs)	= addControls wbId newItems itemNrs itemHs
			= (found,nrSkip,newItems,itemNrs,WListLSHandle itemHs)
		
		addControls` wbId newItems itemNrs (WExtendLSHandle wExH=:{wExtendItems=itemHs})
			# (found,nrSkip,newItems,itemNrs,itemHs)	= addControls wbId newItems itemNrs itemHs
			= (found,nrSkip,newItems,itemNrs,WExtendLSHandle {wExH & wExtendItems=itemHs})
		
		addControls` wbId newItems itemNrs (WChangeLSHandle wChH=:{wChangeItems=itemHs})
			# (found,nrSkip,newItems,itemNrs,itemHs)	= addControls wbId newItems itemNrs itemHs
			= (found,nrSkip,newItems,itemNrs,WChangeLSHandle {wChH & wChangeItems=itemHs})
openrecursivecontrols _ _ _ _ _ _
	= WhiteBoxFatalError "openrecursivecontrols" "unexpected window placeholder argument"


//	createRecursiveControls is copied and modified from createCompoundControls in controlcreate.icl:
//	Beware that the 'wPtr' argument must NOT be the wItemPtr of a LayoutControl, but the first 'real' parent.

createRecursiveControls :: !OSWindowMetrics !Id !Int !(Maybe Id) !(Maybe Id) !Bool !OSWindowPtr ![WElementHandle .ls .pst] !*OSToolbox
																						    -> (![WElementHandle .ls .pst],!*OSToolbox)
createRecursiveControls wMetrics compoundId nrSkip okId cancelId ableContext wPtr itemHs tb
	= stateMap (createRecursiveWElementHandle wMetrics compoundId nrSkip okId cancelId True ableContext zero wPtr) itemHs tb
where
	createRecursiveWElementHandle :: !OSWindowMetrics !Id !Int !(Maybe Id) !(Maybe Id) !Bool !Bool !Point2 !OSWindowPtr
									 !(WElementHandle .ls .pst) !*OSToolbox
								  -> (!WElementHandle .ls .pst, !*OSToolbox)
	createRecursiveWElementHandle wMetrics compoundId nrSkip okId cancelId showContext ableContext parentPos wPtr (WItemHandle itemH=:{wItemKind,wItemId}) tb
		| not (isRecursiveControl wItemKind)
			= (WItemHandle itemH,tb)
		| not (identifyMaybeId compoundId wItemId)
			# (itemHs,tb)			= stateMap (createRecursiveWElementHandle wMetrics compoundId nrSkip okId cancelId showContext1 ableContext1 itemPos itemPtr`) itemH.wItems tb
			= (WItemHandle {itemH & wItems=itemHs},tb)
		| otherwise
			# (oldItems,newItems)	= split nrSkip itemH.wItems
			# (newItems,tb)			= stateMap (createWElementHandle wMetrics okId cancelId showContext1 ableContext1 itemPos itemPtr`) newItems tb
			# tb					= if (wItemKind==IsCompoundControl) (osInvalidateCompound itemPtr) id tb		// PA: added
			= (WItemHandle {itemH & wItems=oldItems++newItems},tb)
	where
		showContext1				= showContext && itemH.wItemShow
		ableContext1				= ableContext && itemH.wItemSelect
		itemPos						= itemH.wItemPos
		itemPtr						= itemH.wItemPtr
		itemPtr`					= if (wItemKind==IsCompoundControl) itemPtr wPtr		// PA: pass real pointer
	
	createRecursiveWElementHandle wMetrics compoundId nrSkip okId cancelId showContext ableContext parentPos wPtr (WListLSHandle itemHs) tb
		# (itemHs,tb)	= stateMap (createRecursiveWElementHandle wMetrics compoundId nrSkip okId cancelId showContext ableContext parentPos wPtr) itemHs tb
		= (WListLSHandle itemHs,tb)
	
	createRecursiveWElementHandle wMetrics compoundId nrSkip okId cancelId showContext ableContext parentPos wPtr (WExtendLSHandle wExH=:{wExtendItems=itemHs}) tb
		# (itemHs,tb)	= stateMap (createRecursiveWElementHandle wMetrics compoundId nrSkip okId cancelId showContext ableContext parentPos wPtr) itemHs tb
		= (WExtendLSHandle {wExH & wExtendItems=itemHs},tb)
	
	createRecursiveWElementHandle wMetrics compoundId nrSkip okId cancelId showContext ableContext parentPos wPtr (WChangeLSHandle wChH=:{wChangeItems=itemHs}) tb
		# (itemHs,tb)	= stateMap (createRecursiveWElementHandle wMetrics compoundId nrSkip okId cancelId showContext ableContext parentPos wPtr) itemHs tb
		= (WChangeLSHandle {wChH & wChangeItems=itemHs},tb)

//	Copied from ioStGetIdParent and getParentWindowId in StdControl.icl:
ioStGetIdParent :: !Id !(IOSt .l) -> (!Maybe IdParent,!IOSt .l)
ioStGetIdParent id ioState
	# (idtable,ioState)		= ioStGetIdTable ioState
	# (idparent,idtable)	= getIdParent id idtable
	# ioState				= ioStSetIdTable idtable ioState
	= (idparent,ioState)

getParentWindowId :: !Id !(IOSt .l) -> (!Maybe Id,!IOSt .l)
getParentWindowId controlId ioState
	# (maybeParent,ioState)	= ioStGetIdParent controlId ioState
	| isNothing maybeParent
		= (Nothing,ioState)
	# parent				= fromJust maybeParent
	| parent.idpDevice<>WindowDevice
		= (Nothing,ioState)
	# (pid,ioState)			= ioStGetIOId ioState
	| parent.idpIOId<>pid
		= (Nothing,ioState)
	| otherwise
		= (Just parent.idpId,ioState)

//	Copied and modified (error message) from getWindowStateHandleIds in StdControl.icl:
getWindowStateHandleIds :: !(WindowStateHandle .pst) -> (![Id],!WindowStateHandle .pst)
getWindowStateHandleIds wsH=:{wshHandle=Just wlsH=:{wlsHandle=wH=:{whItems}}}
	# (ids,itemHs)	= getWElementControlIds whItems
	= (ids,{wsH & wshHandle=Just {wlsH & wlsHandle={wH & whItems=itemHs}}})
getWindowStateHandleIds _
	= WhiteBoxFatalError "getWindowStateHandleIds" "unexpected window placeholder argument"



//	Copied and unmodified as toOKorCANCEL and createWElementHandle from controlcreate.icl:

/*	toOKorCANCEL okId cancelId controlId
		checks if the optional Id of a control (controlId) is the OK control (OK), the CANCEL control (CANCEL), or a normal button (NORMAL).
*/
toOKorCANCEL :: (Maybe Id) (Maybe Id) !(Maybe Id) -> OKorCANCEL
toOKorCANCEL okId cancelId maybeControlId
	= case maybeControlId of
		Just id	-> if (isJust okId     && fromJust okId    ==id) OK
		          (if (isJust cancelId && fromJust cancelId==id) CANCEL
		              NORMAL
		          )
		nothing	-> NORMAL

/*	createWElementHandle generates the proper system resources.
*/
createWElementHandle :: !OSWindowMetrics !(Maybe Id) !(Maybe Id) !Bool !Bool !Point2 !OSWindowPtr !(WElementHandle .ls .pst) !*OSToolbox
																							   -> (!WElementHandle .ls .pst, !*OSToolbox)
createWElementHandle wMetrics okId cancelId showContext ableContext parentPos wPtr (WItemHandle itemH) tb
	# (itemH,tb)	= createWItemHandle wMetrics okId cancelId showContext ableContext parentPos wPtr itemH tb
	= (WItemHandle itemH,tb)
where
	createWItemHandle :: !OSWindowMetrics !(Maybe Id) !(Maybe Id) !Bool !Bool !Point2 !OSWindowPtr !(WItemHandle .ls .pst) !*OSToolbox
																							    -> (!WItemHandle .ls .pst, !*OSToolbox)
	
	createWItemHandle wMetrics okId cancelId showContext ableContext parentPos wPtr itemH=:{wItemKind=IsRadioControl} tb
		# radioInfo				= getWItemRadioInfo itemH.wItemInfo
		  show					= showContext && itemH.wItemShow
		  able					= ableContext && itemH.wItemSelect
		# (radioItems,(_,tb))	= stateMap (createRadioItem show able (toTuple parentPos) wPtr radioInfo.radioIndex) radioInfo.radioItems (1,tb)
		  radioInfo				= {radioInfo & radioItems=radioItems}
		= ({itemH & wItemInfo=RadioInfo radioInfo},tb)
	where
		(hasTip,tipAtt)			= cselect isControlTip undef itemH.wItemAtts
		tip						= getControlTipAtt tipAtt
		
		createRadioItem :: !Bool !Bool !(!Int,!Int) !OSWindowPtr !Index !(RadioItemInfo .pst) !(!Index,!*OSToolbox)
																 	 -> (!RadioItemInfo .pst, !(!Index,!*OSToolbox))
		createRadioItem show able parentPos wPtr index item=:{radioItem=(title,_,_),radioItemPos,radioItemSize} (itemNr,tb)
			# (radioPtr,tb)		= osCreateRadioControl wPtr parentPos title show able (toTuple radioItemPos) (toTuple radioItemSize) (index==itemNr) (itemNr==1) tb
			  itemH				= {item & radioItemPtr=radioPtr}
			| not hasTip
				= (itemH,(itemNr+1,tb))
			| otherwise
				= (itemH,(itemNr+1,osAddControlToolTip wPtr radioPtr tip tb))
	
	createWItemHandle wMetrics okId cancelId showContext ableContext parentPos wPtr itemH=:{wItemKind=IsCheckControl} tb
		# checkInfo				= getWItemCheckInfo itemH.wItemInfo
		  show					= showContext && itemH.wItemShow
		  able					= ableContext && itemH.wItemSelect
		# (checkItems,(_,tb))	= stateMap (createCheckItem show able (toTuple parentPos) wPtr) checkInfo.checkItems (1,tb)
		  checkInfo				= {checkInfo & checkItems=checkItems}
		= ({itemH & wItemInfo=CheckInfo checkInfo},tb)
	where
		(hasTip,tipAtt)			= cselect isControlTip undef itemH.wItemAtts
		tip						= getControlTipAtt tipAtt
		
		createCheckItem :: !Bool !Bool !(!Int,!Int) !OSWindowPtr !(CheckItemInfo .pst) !(!Index,!*OSToolbox)
															  -> (!CheckItemInfo .pst, !(!Index,!*OSToolbox))
		createCheckItem show able parentPos wPtr item=:{checkItem=(title,_,mark,_),checkItemPos,checkItemSize} (itemNr,tb)
			# (checkPtr,tb)		= osCreateCheckControl wPtr parentPos title show able (toTuple checkItemPos) (toTuple checkItemSize) (marked mark) (itemNr==1) tb
			  itemH				= {item & checkItemPtr=checkPtr}
			| not hasTip
				= (itemH,(itemNr+1,tb))
			| otherwise
				= (itemH,(itemNr+1,osAddControlToolTip wPtr checkPtr tip tb))
	
	createWItemHandle wMetrics okId cancelId showContext ableContext parentPos wPtr itemH=:{wItemKind=IsPopUpControl} tb
		# (popUpPtr,editPtr,tb)	= osCreateEmptyPopUpControl wPtr (toTuple parentPos) show able (toTuple pos) (toTuple size) (length items) isEditable tb
		# maybeEditPtr			= if isEditable (Just editPtr) Nothing
		# tb					= osCreatePopUpControlItems popUpPtr maybeEditPtr ableContext (map fst items) info.popUpInfoIndex tb
		  info					= if isEditable {info & popUpInfoEdit=Just {popUpEditText="",popUpEditPtr=editPtr}} info
		  itemH					= {itemH & wItemPtr=popUpPtr, wItemInfo=PopUpInfo info}
		| not hasTip
			= (itemH,tb)
		| otherwise
			= (itemH,osAddControlToolTip wPtr popUpPtr (getControlTipAtt tipAtt) tb)
	where
		pos						= itemH.wItemPos
		size					= itemH.wItemSize
		show					= showContext && itemH.wItemShow
		able					= ableContext && itemH.wItemSelect
		info					= getWItemPopUpInfo itemH.wItemInfo
		items					= info.popUpInfoItems
		(hasTip,tipAtt)			= cselect isControlTip undef itemH.wItemAtts
		isEditable				= contains isControlKeyboard itemH.wItemAtts
	
	createWItemHandle wMetrics okId cancelId showContext ableContext parentPos wPtr itemH=:{wItemKind=IsSliderControl} tb
		# (sliderPtr,tb)		= osCreateSliderControl wPtr (toTuple parentPos) show able (direction==Horizontal) (toTuple pos) (toTuple size) (osMin,osThumb,osMax,osThumbSize) tb
		  itemH					= {itemH & wItemPtr=sliderPtr}
		| not hasTip
			= (itemH,tb)
		| otherwise
			= (itemH,osAddControlToolTip wPtr sliderPtr (getControlTipAtt tipAtt) tb)
	where
		show					= showContext && itemH.wItemShow
		able					= ableContext && itemH.wItemSelect
		info					= getWItemSliderInfo itemH.wItemInfo
		direction				= info.sliderInfoDir
		sliderState				= info.sliderInfoState
		min						= sliderState.sliderMin
		max						= sliderState.sliderMax
		(osMin,osThumb,osMax,osThumbSize)
								= toOSscrollbarRange (min,sliderState.sliderThumb,max) 0
		pos						= itemH.wItemPos
		size					= itemH.wItemSize
		(hasTip,tipAtt)			= cselect isControlTip undef itemH.wItemAtts

	createWItemHandle wMetrics okId cancelId showContext ableContext parentPos wPtr itemH=:{wItemKind=IsTextControl} tb
		# (textPtr,tb)			= osCreateTextControl wPtr (toTuple parentPos) title show (toTuple pos) (toTuple size) tb
		  itemH					= {itemH & wItemPtr=textPtr}
		| not hasTip
			= (itemH,tb)
		| otherwise
			= (itemH,osAddControlToolTip wPtr textPtr (getControlTipAtt tipAtt) tb)
	where
		show					= showContext && itemH.wItemShow
		pos						= itemH.wItemPos
		size					= itemH.wItemSize
		title					= (getWItemTextInfo itemH.wItemInfo).textInfoText
		(hasTip,tipAtt)			= cselect isControlTip undef itemH.wItemAtts
	
	createWItemHandle wMetrics okId cancelId showContext ableContext parentPos wPtr itemH=:{wItemKind=IsEditControl} tb
		# (editPtr,tb)			= osCreateEditControl wPtr (toTuple parentPos) text show able keySensitive (toTuple pos) (toTuple size) tb
		  itemH					= {itemH & wItemPtr=editPtr}
		| not hasTip
			= (itemH,tb)
		| otherwise
			= (itemH,osAddControlToolTip wPtr editPtr (getControlTipAtt tipAtt) tb)
	where
		show					= showContext && itemH.wItemShow
		able					= ableContext && itemH.wItemSelect
		atts					= itemH.wItemAtts
		keySensitive			= contains isControlKeyboard atts
		pos						= itemH.wItemPos
		size					= itemH.wItemSize
		text					= (getWItemEditInfo itemH.wItemInfo).editInfoText
		(hasTip,tipAtt)			= cselect isControlTip undef atts
	
	createWItemHandle wMetrics okId cancelId showContext ableContext parentPos wPtr itemH=:{wItemKind=IsButtonControl} tb
		# (buttonPtr,tb)		= osCreateButtonControl wPtr (toTuple parentPos) title show able (toTuple pos) (toTuple size) okOrCancel tb
		  itemH					= {itemH & wItemPtr=buttonPtr}
		| not hasTip
			= (itemH,tb)
		| otherwise
			= (itemH,osAddControlToolTip wPtr buttonPtr (getControlTipAtt tipAtt) tb)
	where
		show					= showContext && itemH.wItemShow
		able					= ableContext && itemH.wItemSelect
		pos						= itemH.wItemPos
		size					= itemH.wItemSize
		itemId					= itemH.wItemId
		okOrCancel				= toOKorCANCEL okId cancelId itemId
		title					= (getWItemButtonInfo itemH.wItemInfo).buttonInfoText
		(hasTip,tipAtt)			= cselect isControlTip undef itemH.wItemAtts
	
	createWItemHandle wMetrics okId cancelId showContext ableContext parentPos wPtr itemH=:{wItemKind=IsCustomButtonControl} tb
		# (buttonPtr,tb)		= osCreateCustomButtonControl wPtr (toTuple parentPos) show able (toTuple pos) (toTuple size) okOrCancel tb
		  itemH					= {itemH & wItemPtr=buttonPtr}
		| not hasTip
			= (itemH,tb)
		| otherwise
			= (itemH,osAddControlToolTip wPtr buttonPtr (getControlTipAtt tipAtt) tb)
	where
		show					= showContext && itemH.wItemShow
		able					= ableContext && itemH.wItemSelect
		pos						= itemH.wItemPos
		size					= itemH.wItemSize
		itemId					= itemH.wItemId
		okOrCancel				= toOKorCANCEL okId cancelId itemId
		(hasTip,tipAtt)			= cselect isControlTip undef itemH.wItemAtts
	
	createWItemHandle wMetrics okId cancelId showContext ableContext parentPos wPtr itemH=:{wItemKind=IsCustomControl} tb
		# (customPtr,tb)		= osCreateCustomControl wPtr (toTuple parentPos) show able (toTuple pos) (toTuple size) tb
		  itemH					= {itemH & wItemPtr=customPtr}
		| not hasTip
			= (itemH,tb)
		| otherwise
			= (itemH,osAddControlToolTip wPtr customPtr (getControlTipAtt tipAtt) tb)
	where
		show					= showContext && itemH.wItemShow
		able					= ableContext && itemH.wItemSelect
		pos						= itemH.wItemPos
		size					= itemH.wItemSize
		(hasTip,tipAtt)			= cselect isControlTip undef itemH.wItemAtts
	
	createWItemHandle wMetrics okId cancelId showContext ableContext parentPos wPtr itemH=:{wItemKind=IsCompoundControl} tb
		# (compoundPtr,hPtr,vPtr,tb)
								= osCreateCompoundControl wMetrics wPtr (toTuple parentPos) show able False (toTuple pos) (toTuple size) hScroll vScroll tb
		  compoundInfo			= {info & compoundHScroll=setScrollbarPtr hPtr info.compoundHScroll
		  								, compoundVScroll=setScrollbarPtr vPtr info.compoundVScroll
		  						  }
		# (itemHs,tb)			= stateMap (createWElementHandle wMetrics okId cancelId show able itemH.wItemPos compoundPtr) itemH.wItems tb
		  itemH					= {itemH & wItemInfo=CompoundInfo compoundInfo,wItemPtr=compoundPtr,wItems=itemHs}
		| not hasTip
			= (itemH,tb)
		| otherwise
			= (itemH,osAddControlToolTip wPtr compoundPtr (getControlTipAtt tipAtt) tb)
	where
		show					= showContext && itemH.wItemShow
		able					= ableContext && itemH.wItemSelect
		pos						= itemH.wItemPos
		size					= itemH.wItemSize
		info					= getWItemCompoundInfo itemH.wItemInfo
		domainRect				= info.compoundDomain
		origin					= info.compoundOrigin
		(hasHScroll,hasVScroll)	= (isJust info.compoundHScroll,isJust info.compoundVScroll)
		visScrolls				= osScrollbarsAreVisible wMetrics domainRect (toTuple size) (hasHScroll,hasVScroll)
		{w,h}					= rectSize (osGetCompoundContentRect wMetrics visScrolls (sizeToRect size))
		(hasTip,tipAtt)			= cselect isControlTip undef itemH.wItemAtts
		
		hScroll :: ScrollbarInfo
		hScroll
			| hasHScroll		= {cbiHasScroll=True, cbiPos=toTuple hInfo.scrollItemPos,cbiSize=toTuple hSize,cbiState=hState}
			| otherwise			= {cbiHasScroll=False,cbiPos=undef,cbiSize=undef,cbiState=undef}
		where
			hInfo				= fromJust info.compoundHScroll
			hSize				= hInfo.scrollItemSize
			hState				= toOSscrollbarRange (domainRect.rleft,origin.x,domainRect.rright) w
		vScroll :: ScrollbarInfo
		vScroll
			| hasVScroll		= {cbiHasScroll=True, cbiPos=toTuple vInfo.scrollItemPos,cbiSize=toTuple vSize,cbiState=vState}
			| otherwise			= {cbiHasScroll=False,cbiPos=undef,cbiSize=undef,cbiState=undef}
		where
			vInfo				= fromJust info.compoundVScroll
			vSize				= vInfo.scrollItemSize
			vState				= toOSscrollbarRange (domainRect.rtop,origin.y,domainRect.rbottom) h

		setScrollbarPtr :: OSWindowPtr !(Maybe ScrollInfo) -> Maybe ScrollInfo
		setScrollbarPtr scrollPtr (Just info)	= Just {info & scrollItemPtr=scrollPtr}
		setScrollbarPtr _ nothing				= nothing

	createWItemHandle wMetrics okId cancelId showContext ableContext parentPos wPtr itemH=:{wItemKind=IsLayoutControl,wItems} tb
		# (itemHs,tb)			= stateMap (createWElementHandle wMetrics okId cancelId show able parentPos wPtr) wItems tb
		= ({itemH & wItems=itemHs},tb)
	where
		show					= showContext && itemH.wItemShow
		able					= ableContext && itemH.wItemSelect

	createWItemHandle _ _ _ _ _ _ _ itemH tb
		= (itemH,tb)

createWElementHandle wMetrics okId cancelId showContext ableContext parentPos wPtr (WListLSHandle itemHs) tb
	# (itemHs,tb)	= stateMap (createWElementHandle wMetrics okId cancelId showContext ableContext parentPos wPtr) itemHs tb
	= (WListLSHandle itemHs,tb)

createWElementHandle wMetrics okId cancelId showContext ableContext parentPos wPtr (WExtendLSHandle wExH=:{wExtendItems=itemHs}) tb
	# (itemHs,tb)	= stateMap (createWElementHandle wMetrics okId cancelId showContext ableContext parentPos wPtr) itemHs tb
	= (WExtendLSHandle {wExH & wExtendItems=itemHs},tb)

createWElementHandle wMetrics okId cancelId showContext ableContext parentPos wPtr (WChangeLSHandle wChH=:{wChangeItems=itemHs}) tb
	# (itemHs,tb)	= stateMap (createWElementHandle wMetrics okId cancelId showContext ableContext parentPos wPtr) itemHs tb
	= (WChangeLSHandle {wChH & wChangeItems=itemHs},tb)
