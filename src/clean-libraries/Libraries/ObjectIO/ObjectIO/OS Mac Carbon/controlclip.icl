implementation module controlclip


import	StdInt, StdBool, StdList
import StdControlAttribute
import	textedit
from	controls		import	TrackControl, SetCtlValue, HiliteControl, ControlHandle

import	commondef, windowaccess, wstateaccess,quickdraw,events
//from	controldefaccess	import	iscontrolhscroll, iscontrolvscroll
//from	controllayout		import	getCompoundContentRect, getCompoundHScrollRect, getCompoundVScrollRect
//from	regionaccess		import	disposeRgnHs
//from	windowdraw			import	openClipDrawing, closeClipDrawing, GrafPtr
from osutil import appClipport, accClipport
import StdFunc

//	trackClippedControl before calling TrackControl sets the clipping region of the window.
trackClippedControl :: !OSWindowPtr !Rect !ControlHandle !Point2 !*OSToolbox -> (!Int,!*OSToolbox)
trackClippedControl wPtr clipRect controlH {x,y} tb
= accClipport wPtr clipRect (TrackControl controlH x y 0) tb
/*#	(port,rgn,tb)	= openClipDrawing	wPtr			tb
	tb				= QClipRect			clipRect		tb
	(upPart,tb)		= TrackControl		controlH x y 0	tb
	tb				= closeClipDrawing	port rgn		tb
=	(upPart,tb)
*/

trackRectArea :: !OSWindowPtr !Rect !Rect !*OSToolbox -> (!Bool,!*OSToolbox)
trackRectArea wPtr clipRect itemRect tb
	= accClipport wPtr clipRect (track itemRect True) tb
/*	#	(port,rgn,tb)	= openClipDrawing	wPtr			tb
		tb				= QClipRect			clipRect		tb

		selected		= True
//		tb				= QInvertRect itemRect				tb
		(selected,tb)	= track itemRect selected			tb
		
		tb				= closeClipDrawing	port rgn		tb
	=	(selected,tb)
*/
where
	track :: !Rect !Bool !*OSToolbox -> (!Bool,!*OSToolbox)
	track itemRect selected tb
		# (x,y,tb)			= GetMouse tb
		# inside			= pointInRect {x=x,y=y} itemRect
		# (stillDown,tb)	= WaitMouseUp tb
		| stillDown && selected == inside
			= track itemRect inside tb
		| stillDown
			= track itemRect inside tb	//(QInvertRect itemRect tb)
		| not inside
			= (inside,tb)
		= (inside,tb)	//QInvertRect itemRect tb)

trackCustomButton :: !OSWindowPtr !Rect !Rect !*OSToolbox -> (!Bool,!*OSToolbox)
trackCustomButton wPtr clipRect itemRect tb
	= accClipport wPtr clipRect (track itemRect True o QInvertRect itemRect) tb
/*	#	(port,rgn,tb)	= openClipDrawing	wPtr			tb
		tb				= QClipRect			clipRect		tb

		selected		= True
		tb				= QInvertRect itemRect				tb
		(selected,tb)	= track itemRect selected			tb
		
		tb				= closeClipDrawing	port rgn		tb
	=	(selected,tb)
*/
where
	track :: !Rect !Bool !*OSToolbox -> (!Bool,!*OSToolbox)
	track itemRect selected tb
		# (x,y,tb)			= GetMouse tb
		# inside			= pointInRect {x=x,y=y} itemRect
		# (stillDown,tb)	= WaitMouseUp tb
		| stillDown && selected == inside
			= track itemRect inside tb
		| stillDown
			= track itemRect inside (QInvertRect itemRect tb)
		| not inside
			= (inside,tb)
		= (inside,QInvertRect itemRect tb)
		
	
//	setClippedControlValue before calling SetCtlValue sets the clipping region of the window.
setClippedControlValue :: !OSWindowPtr !Rect !ControlHandle !Int !*OSToolbox -> *OSToolbox
setClippedControlValue wPtr clipRect controlH x tb
= appClipport wPtr clipRect (SetCtlValue controlH x) tb
/*#	(port,rgn,tb)	= openClipDrawing	wPtr		tb
	tb				= QClipRect			clipRect	tb
	tb				= SetCtlValue		controlH x	tb
	tb				= closeClipDrawing	port rgn	tb
=	tb
*/
//	hiliteClippedControl before calling HiliteControl sets the clipping region of the window.
hiliteClippedControl :: !OSWindowPtr !Rect !ControlHandle !Int !*OSToolbox -> *OSToolbox
hiliteClippedControl wPtr clipRect controlH partCode tb
= appClipport wPtr clipRect (HiliteControl controlH partCode) tb
/*#	(port,rgn,tb)	= openClipDrawing	wPtr				tb
	tb				= QClipRect			clipRect			tb
	tb				= HiliteControl		controlH partCode	tb
	tb				= closeClipDrawing	port rgn			tb
=	tb
*/
/*	scrollClippedRect before scrolling a Rect over a Vector sets the clipping region of the window.
	It returns a [Rect] describing the newly revealed parts of the Rect.
	scrollClippedRect assumes that the proper GrafPort has been set.
*/
scrollClippedRect :: !Vector2 !Rect !*OSToolbox -> (![Rect],!*OSToolbox)
scrollClippedRect v=:{vx,vy} scrollRect tb
|	abs vx>=rectSize`.w || abs vy>=rectSize`.h
=	([scrollRect],tb)
#	(rgn,tb)			= QNewRgn tb
	(aidRgn,tb)			= QNewRgn tb
	(aidRgn,tb)			= QGetClip aidRgn tb
	tb					= QClipRect scrollRect tb
	tb					= QScrollRect scrollRect vx vy rgn tb
	tb					= QSetClip aidRgn tb
	tb					= disposeRgnHs [aidRgn,rgn] tb
=	(map fromTuple4 (diffRects (toTuple4 scrollRect) (toTuple4 scrolledRect)),tb)
where
	rectSize`			= rectSize scrollRect
	scrolledRect		= intersectRects scrollRect (fromTuple4 (AddRectVector v (toTuple4 scrollRect)))
	
//	diffRects :: !Rect !Rect -> [Rect]
	diffRects scrollRect=:(l,t, r,b) scrolledRect=:(l`,t`, r`,b`)
	|	vx==0			= if (vy<0) [(l,b`, r,b )] [(l, t, r,t`)]
	|	vy==0			= if (vx<0) [(r`,t, r,b )] [(l,t,  l`,b)]
	|	vx<0			= if (vy<0) [(l,b`, r, t ),(r`,t,  r, b`)] [(l,t,  r, t`),(r`,t`, r, b )]
						= if (vy<0) [(l,t,  l`,b`),(l, b`, r, t )] [(l,t,  r, t`),(l, t`, l`,b )]

/*
/*	calcUpdateRgn generates the OSRgnHandle that is the union of the [Rect].
	Therefore these must be given in local coordinates.
*/
calcUpdateRgn :: ![Rect] !*OSToolbox -> (!OSRgnHandle,!*OSToolbox)
calcUpdateRgn rects tb
#	(rgn,tb)		= QNewRgn tb
	tb				= QOpenRgn rgn tb
	tb				= StateMap2 QFrameRect rects tb
	tb				= QCloseRgn rgn tb
=	(rgn,tb)


/*	calcDialogClip and calcDialogClip` calculate the clipping region of the given window elements
	that are contained in the given Rect.
*/
::	*LocalCLipState
	:==	(	!OSRgnHandle
		,	!OSRgnHandle
		,	!OSRgnHandle
		,	!*OSToolbox
		)

calcDialogClip :: !Rect !(Maybe Id) ![WElementHandle .ls .ps] !*OSToolbox -> (!OSRgnHandle,![WElementHandle .ls .ps],!*OSToolbox)
calcDialogClip clipRect defId itemHs tb
#	(clipRgn, tb)	= QNewRgn tb
	(aidRgn1, tb)	= QNewRgn tb
	(aidRgn2, tb)	= QNewRgn tb
	(itemHs,(clipRgn,aidRgn1,aidRgn2,tb))
					= StateMap (calcWElementHandleClip clipRect defId) itemHs (clipRgn,aidRgn1,aidRgn2,tb)
	tb				= QDisposeRgn aidRgn1 tb
	tb				= QDisposeRgn aidRgn2 tb
=	(clipRgn,itemHs,tb)
where
	calcWElementHandleClip :: !Rect !(Maybe Id) !(WElementHandle .ls .ps) !LocalCLipState
											 -> (!WElementHandle .ls .ps, !LocalCLipState)
	calcWElementHandleClip clipRect defId (WListLSHandle itemHs) s
	#	(itemHs,s)	= StateMap (calcWElementHandleClip clipRect defId) itemHs s
	=	(WListLSHandle itemHs,s)
	calcWElementHandleClip clipRect defId (WExtendLSHandle dExH=:{wExtendItems=itemHs}) s
	#	(itemHs,s)	= StateMap (calcWElementHandleClip clipRect defId) itemHs s
	=	(WExtendLSHandle {dExH & wExtendItems=itemHs},s)
	calcWElementHandleClip clipRect defId (WChangeLSHandle dChH=:{wChangeItems=itemHs}) s
	#	(itemHs,s)	= StateMap (calcWElementHandleClip clipRect defId) itemHs s
	=	(WChangeLSHandle {dChH & wChangeItems=itemHs},s)
	calcWElementHandleClip clipRect defId (WItemHandle itemH=:{wItemShow}) s
	|	not wItemShow || DisjointRects (PosSizeToRect itemH.wItemPos itemH.wItemSize) clipRect
	=	(WItemHandle itemH,s)
	#	(itemH,s)	= calcWItemHandleClip clipRect defId itemH s
	=	(WItemHandle itemH,s)
	where
		calcWItemHandleClip :: !Rect !(Maybe Id) !(WItemHandle .ls .ps) !LocalCLipState
											  -> (!WItemHandle .ls .ps, !LocalCLipState)
		calcWItemHandleClip clipRect defId itemH=:{wItemKind=IsButtonControl} s
		=	(itemH,calcButtonClip clipRect defId itemH.wItemId itemH.wItemPos itemH.wItemSize s)
		calcWItemHandleClip clipRect _ itemH=:{wItemKind=IsPopUpControl} s
		=	(itemH,calcPopUpClip clipRect itemH.wItemPos itemH.wItemSize s)
		calcWItemHandleClip clipRect _ itemH=:{wItemKind=IsEditControl} s
		=	(itemH,calcItemRectClip clipRect itemRect s)
		where
			(l,t, r,b)		= toTuple4 (PosSizeToRect itemH.wItemPos itemH.wItemSize)
			itemRect		= fromTuple4 (l-3,t-3, r+3,b+3)
		calcWItemHandleClip clipRect defId itemH=:{wItemKind=IsCompoundControl} s
		#	s				= addCompoundSliderClip hasHScroll hRect s
			s				= addCompoundSliderClip hasVScroll vRect s
//???		|	not (isEmpty itemH.wItemLook)
//???		=	(itemH,calcItemRectClip clipRect contentRect s)
		#	(itemHs,s)		= StateMap (calcWElementHandleClip itemRect defId) itemH.wItems s
		=	({itemH & wItems=itemHs},s)
		where
			itemRect		= PosSizeToRect itemH.wItemPos itemH.wItemSize
			contentRect		= getCompoundContentRect hasHScroll hasVScroll itemRect
			hRect			= getCompoundHScrollRect wMetrics hasHScroll hasVScroll itemRect
			vRect			= getCompoundVScrollRect wMetrics hasHScroll hasVScroll itemRect
	//		atts			= itemH.wItemAtts
			hasHScroll		= isJust info.compoundHScroll	//Contains isControlHScroll atts
			hasVScroll		= isJust info.compoundVScroll	//Contains isControlVScroll atts
			info			= getWItemCompoundInfo ( itemH.wItemInfo)
		calcWItemHandleClip clipRect _ itemH=:{wItemKind=IsRadioControl} s
		=	(itemH,StateMap2 (calcRadioItemHandleClip clipRect) info.radioItems s)
		where
			info			= getWItemRadioInfo (fromJust itemH.wItemInfo)
			
			calcRadioItemHandleClip :: !Rect !(RadioItemInfo .ps) !LocalCLipState -> LocalCLipState
			calcRadioItemHandleClip clipRect {radioItemPos,radioItemSize} s
			=	calcItemRectClip clipRect (PosSizeToRect radioItemPos radioItemSize) s
		calcWItemHandleClip clipRect _ itemH=:{wItemKind=IsCheckControl} s
		=	(itemH,StateMap2 (calcCheckItemHandleClip clipRect) info.checkItems s)
		where
			info			= getWItemCheckInfo (fromJust itemH.wItemInfo)
			
			calcCheckItemHandleClip :: !Rect !(CheckItemInfo .ps) !LocalCLipState -> LocalCLipState
			calcCheckItemHandleClip clipRect {checkItemPos,checkItemSize} s
			=	calcItemRectClip clipRect (PosSizeToRect checkItemPos checkItemSize) s
		calcWItemHandleClip clipRect _ itemH s
		=	(itemH,calcItemRectClip clipRect (PosSizeToRect itemH.wItemPos itemH.wItemSize) s)

calcDialogClip` :: !Rect !(Maybe Id) ![WElementHandle`] !*OSToolbox -> (!OSRgnHandle,!*OSToolbox)
calcDialogClip` clipRect defId itemHs tb
#	(clipRgn, tb)	= QNewRgn tb
	(aidRgn1, tb)	= QNewRgn tb
	(aidRgn2, tb)	= QNewRgn tb
	(clipRgn,aidRgn1,aidRgn2,tb)
					= StateMap2 (calcWElementHandleClip clipRect defId) itemHs (clipRgn,aidRgn1,aidRgn2,tb)
	tb				= QDisposeRgn aidRgn1 tb
	tb				= QDisposeRgn aidRgn2 tb
=	(clipRgn,tb)
where
	calcWElementHandleClip :: !Rect !(Maybe Id) !WElementHandle` !LocalCLipState -> LocalCLipState
	calcWElementHandleClip clipRect defId (WRecursiveHandle` itemHs _) s
	=	StateMap2 (calcWElementHandleClip clipRect defId) itemHs s
	calcWElementHandleClip clipRect defId (WItemHandle` itemH=:{wItemShow`}) s
	|	not wItemShow` || DisjointRects (PosSizeToRect itemH.wItemPos` itemH.wItemSize`) clipRect
	=	s
	=	calcWItemHandleClip clipRect defId itemH s
	where
		calcWItemHandleClip :: !Rect !(Maybe Id) !WItemHandle` !LocalCLipState -> LocalCLipState
		calcWItemHandleClip clipRect defId itemH=:{wItemKind`=IsButtonControl} s
		=	calcButtonClip clipRect defId itemH.wItemId` itemH.wItemPos` itemH.wItemSize` s
		calcWItemHandleClip clipRect _ itemH=:{wItemKind`=IsPopUpControl} s
		=	calcPopUpClip clipRect itemH.wItemPos` itemH.wItemSize` s
		calcWItemHandleClip clipRect _ itemH=:{wItemKind`=IsEditControl} s
		=	calcItemRectClip clipRect itemRect s
		where
			(l,t, r,b)		= toTuple4 (PosSizeToRect itemH.wItemPos` itemH.wItemSize`)
			itemRect		= fromTuple4 (l-3,t-3, r+3,b+3)
		calcWItemHandleClip clipRect defId itemH=:{wItemShow`,wItemKind`=IsCompoundControl} s
		#	s				= addCompoundSliderClip hasHScroll hRect s
			s				= addCompoundSliderClip hasVScroll vRect s
//???		|	not (isEmpty itemH.wItemLook`)
//???		=	calcItemRectClip clipRect contentRect s
		=	StateMap2 (calcWElementHandleClip itemRect defId) itemH.wItems` s
		where
			itemRect		= PosSizeToRect itemH.wItemPos` itemH.wItemSize`
			contentRect		= getCompoundContentRect hasHScroll hasVScroll itemRect
			hRect			= getCompoundHScrollRect wMetrics hasHScroll hasVScroll itemRect
			vRect			= getCompoundVScrollRect wMetrics hasHScroll hasVScroll itemRect
			atts			= itemH.wItemAtts`
			info			= getWItemCompoundInfo` itemH.wItemInfo`
			hasHScroll		= isJust info.compoundHScroll	//Contains isControlHScroll atts
			hasVScroll		= isJust info.compoundVScroll	//Contains isControlVScroll atts
		calcWItemHandleClip clipRect _ itemH=:{wItemKind`=IsRadioControl} s
		#	info			= getWItemRadioInfo` (fromJust itemH.wItemInfo`)
			s				= StateMap2 (calcRadioItemHandleClip clipRect) info.radioItems` s
		=	s
		where
			calcRadioItemHandleClip :: !Rect !RadioItemInfo` !LocalCLipState -> LocalCLipState
			calcRadioItemHandleClip clipRect {radioItemPos`,radioItemSize`} s
			=	calcItemRectClip clipRect (PosSizeToRect radioItemPos` radioItemSize`) s
		calcWItemHandleClip clipRect _ itemH=:{wItemKind`=IsCheckControl} s
		#	info			= getWItemCheckInfo` (fromJust itemH.wItemInfo`)
			s				= StateMap2 (calcCheckItemHandleClip clipRect) info.checkItems` s
		=	s
		where
			calcCheckItemHandleClip :: !Rect !CheckItemInfo` !LocalCLipState -> LocalCLipState
			calcCheckItemHandleClip clipRect {checkItemPos`,checkItemSize`} s
			=	calcItemRectClip clipRect (PosSizeToRect checkItemPos` checkItemSize`) s
		calcWItemHandleClip clipRect _ itemH s
		=	calcItemRectClip clipRect (PosSizeToRect itemH.wItemPos` itemH.wItemSize`) s

//	Calculate the clipping shape of specific control kinds:
calcButtonClip :: !Rect !(Maybe Id) !(Maybe Id) !Point2 !Size !LocalCLipState -> LocalCLipState
calcButtonClip clipRect defId itemId itemPos itemSize (clipRgn,aidRgn1,aidRgn2,tb)
#	tb				= QOpenRgn aidRgn2 tb
	tb				= QFrameRoundRect (fromTuple4 buttonRect) 10 10 tb
	tb				= QCloseRgn aidRgn2 tb
	tb				= QRectRgn aidRgn1 clipRect tb
	(aidRgn1,tb)	= QSectRgn aidRgn1 aidRgn2 aidRgn1 tb
	(clipRgn,tb)	= QUnionRgn clipRgn aidRgn1 clipRgn tb
=	(clipRgn,aidRgn1,aidRgn2,tb)
where
	rect			= PosSizeToRect itemPos itemSize
	(l,t, r,b)		= toTuple4 rect
	buttonRect		= if (isJust itemId && isJust defId && fromJust defId==fromJust itemId) (l-4,t-4, r+4,b+4) (toTuple4 rect)

calcPopUpClip :: !Rect !Point2 !Size !LocalCLipState -> LocalCLipState
calcPopUpClip clipRect itemPos itemSize s=:(clipRgn,aidRgn1,aidRgn2,tb)
#	tb				= QOpenRgn aidRgn2		tb
	(x,y,tb)		= QGetPen				tb
	tb				= QMoveTo l		t		tb
	tb				= QLineTo (r-1)	t		tb
	tb				= QLineTo (r-1)	(t+2)	tb
	tb				= QLineTo r		(t+2)	tb
	tb				= QLineTo r		b		tb
	tb				= QLineTo (l+2)	b		tb
	tb				= QLineTo (l+2)	(b-1)	tb
	tb				= QLineTo l		(b-1)	tb
	tb				= QLineTo l		t		tb
	tb				= QMoveTo x		y		tb
	tb				= QCloseRgn aidRgn2		tb
	tb				= QRectRgn aidRgn1 clipRect tb
	(aidRgn1,tb)	= QSectRgn aidRgn1 aidRgn2 aidRgn1 tb
	(clipRgn,tb)	= QUnionRgn clipRgn aidRgn1 clipRgn tb
=	(clipRgn,aidRgn1,aidRgn2,tb)
where
	(l,t, r,b)		= toTuple4 (PosSizeToRect itemPos itemSize)

addCompoundSliderClip :: !Bool Rect !LocalCLipState -> LocalCLipState
addCompoundSliderClip hasScroll itemRect s
|	not hasScroll
=	s
#	(clipRgn,aidRgn1,aidRgn2,tb)
					= s
	tb				= QRectRgn aidRgn1 itemRect tb
	(clipRgn,tb)	= QUnionRgn clipRgn aidRgn1 clipRgn tb
=	(clipRgn,aidRgn1,aidRgn2,tb)

calcItemRectClip :: !Rect !Rect !LocalCLipState -> LocalCLipState
calcItemRectClip clipRect itemRect (clipRgn,aidRgn1,aidRgn2,tb)
#	tb				= QRectRgn aidRgn2 itemRect tb
	tb				= QRectRgn aidRgn1 clipRect tb
	(aidRgn1,tb)	= QSectRgn aidRgn1 aidRgn2 aidRgn1 tb
	(clipRgn,tb)	= QUnionRgn clipRgn aidRgn1 clipRgn tb
=	(clipRgn,aidRgn1,aidRgn2,tb)
*/
//~~~~
/*
//	openClipDrawing saves the current Grafport, sets the new Grafport, and saves its ClipRgn.
openClipDrawing :: !OSWindowPtr !*OSToolbox -> (!GrafPtr,!OSRgnHandle,!*OSToolbox)
openClipDrawing wPtr tb
#	(port,tb)	= QGetPort		tb
	tb			= QSetPort wPtr	tb
	(rgn, tb)	= QNewRgn		tb
	(rgn, tb)	= QGetClip rgn	tb
=	(port,rgn,tb)

//	closeClipDrawing restores the ClipRgn, restores the Grafport, and disposes the ClipRgn.
closeClipDrawing :: !GrafPtr !OSRgnHandle !*OSToolbox -> *OSToolbox
closeClipDrawing port clipRgn tb
#	tb	= QSetClip		clipRgn	tb
	tb	= QDisposeRgn	clipRgn	tb
	tb	= QSetPort		port	tb
=	tb
*/
//AddRectVector :: !Vector2 !Rect -> Rect
AddRectVector {vx,vy} (l,t, r,b) = (l+vx,t+vy, r+vx,b+vy)

