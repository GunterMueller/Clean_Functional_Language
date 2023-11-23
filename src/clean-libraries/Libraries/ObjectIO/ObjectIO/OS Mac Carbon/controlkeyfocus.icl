implementation module controlkeyfocus


import	StdInt, StdBool, StdFunc
from	quickdraw		import GrafPtr, QEraseRect, QFrameRect, QClipRect
import	textedit
import	commondef, keyfocus, windowaccess
from	windowaccess	import	getCompoundContentRect
from	controlclip		import	openClipDrawing, closeClipDrawing
import ossystem

/*	getDeactivateKeyInputItem yields the system feedback function (IdFun Toolbox) of the 
	window item that currently has the keyboard input focus. This function can then be 
	used to provide the proper feedback for deactivating that item.
*/
getDeactivateKeyInputItem :: !OSWindowPtr !Rect !*KeyFocus !Point2 ![WElementHandle .ls .ps]
											-> (!*KeyFocus,!IdFun *OSToolbox,![WElementHandle .ls .ps])
getDeactivateKeyInputItem wPtr clipRect kf mousePos itemHs
#	(opt_kfNr,kf)			= getCurrentFocusItem kf
|	isNothing opt_kfNr
=	(kf,id,itemHs)
#	(_,f,itemHs)		= getDeactivateKeyInputItem` wPtr clipRect (fromJust opt_kfNr) mousePos itemHs
=	(kf,f,itemHs)
where
	getDeactivateKeyInputItem` :: !OSWindowPtr !Rect !Int !Point2 ![WElementHandle .ls .ps]
									  -> (!Bool,!IdFun *OSToolbox,![WElementHandle .ls .ps])
	getDeactivateKeyInputItem` wPtr clipRect kfNr mousePos [itemH:itemHs]
	#	(found,f,itemH)	= getDeactivate wPtr clipRect kfNr mousePos itemH
	|	found
	=	(found,f,[itemH:itemHs])
	#	(found,f,itemHs)= getDeactivateKeyInputItem` wPtr clipRect kfNr mousePos itemHs
	=	(found,f,[itemH:itemHs])
	where
		getDeactivate :: !OSWindowPtr !Rect !Int !Point2 !(WElementHandle .ls .ps) -> (!Bool,!IdFun *OSToolbox,!WElementHandle .ls .ps)
		getDeactivate wPtr clipRect kfNr mousePos (WListLSHandle itemHs)
		#	(found,f,itemHs)	= getDeactivateKeyInputItem` wPtr clipRect kfNr mousePos itemHs
		=	(found,f,WListLSHandle itemHs)
		getDeactivate wPtr clipRect kfNr mousePos (WExtendLSHandle dExH=:{wExtendItems=itemHs})
		#	(found,f,itemHs)	= getDeactivateKeyInputItem` wPtr clipRect kfNr mousePos itemHs
		=	(found,f,WExtendLSHandle {dExH & wExtendItems=itemHs})
		getDeactivate wPtr clipRect kfNr mousePos (WChangeLSHandle dChH=:{wChangeItems=itemHs})
		#	(found,f,itemHs)	= getDeactivateKeyInputItem` wPtr clipRect kfNr mousePos itemHs
		=	(found,f,WChangeLSHandle {dChH & wChangeItems=itemHs})
		getDeactivate wPtr clipRect kfNr mousePos (WItemHandle itemH)
		#	(found,f,itemH)		= getDeactivate` wPtr clipRect kfNr mousePos itemH
		=	(found,f,WItemHandle itemH)
		where
			getDeactivate` :: !OSWindowPtr !Rect !Int !Point2 !(WItemHandle .ls .ps) -> (!Bool,!IdFun *OSToolbox,!WItemHandle .ls .ps)
			getDeactivate` wPtr clipRect kfNr mousePos itemH=:{wItemKind=IsEditControl,wItemPtr = hTE,wItemNr,wItemPos,wItemSize}
			# itemH = itemH
			|	kfNr<>wItemNr
			=	(False,id,itemH)
			|	PointInRect mousePos ( marginRect)
			=	(True,id,itemH)
			=	(True,deactivateEditControl wPtr clipRect hTE marginRect,itemH)
			where
				itemRect	= PosSizeToRect wItemPos wItemSize
				(l,t, r,b)	= toTuple4 itemRect
				marginRect	= fromTuple4 (l-3,t-3, r+3,b+3)
		//		hTE			= itemH.wItemPtr
				
				deactivateEditControl :: !OSWindowPtr !Rect !TEHandle !Rect !*OSToolbox -> *OSToolbox
				deactivateEditControl wPtr clipRect hTE rect tb
				#	(port,rgn,tb)	= openClipDrawing wPtr tb
					tb				= QClipRect clipRect tb
					tb				= TEDeactivate hTE tb
					tb				= QEraseRect rect tb
					tb				= QFrameRect rect tb
					tb				= TEUpdate rect hTE tb
					tb				= closeClipDrawing port rgn tb
				=	tb
			getDeactivate` wPtr clipRect kfNr mousePos itemH=:{wItemKind=IsCustomControl,wItemNr}
			=	(kfNr==wItemNr,id,itemH)
			getDeactivate` wPtr clipRect kfNr mousePos itemH=:{wItemKind=IsCompoundControl,wItems}
			#	(found,f,itemHs)	= getDeactivateKeyInputItem` wPtr (IntersectRects clipRect1 clipRect) kfNr mousePos wItems
				itemH				= {itemH & wItems=itemHs}
			=	(found,f,itemH)
			where
				itemRect			= PosSizeToRect itemH.wItemPos itemH.wItemSize
				clipRect1			= getCompoundContentRect wMetrics (hasHScroll, hasVScroll) itemRect
				info				= getWItemCompoundInfo ( itemH.wItemInfo)
				hasHScroll			= isJust info.compoundHScroll
				hasVScroll			= isJust info.compoundVScroll
				(wMetrics,_) = OSDefaultWindowMetrics OSNewToolbox
			getDeactivate` _ _ _ _ itemH
			=	(False,id,itemH)
	getDeactivateKeyInputItem` _ _ _ _ _
	=	(False,id,[])
