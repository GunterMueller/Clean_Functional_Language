implementation module osrgn

import	StdInt,StdClass
import ostypes,ostoolbox
import quickdraw
import	pointer

:: OSRgnHandle :== Int

osnewrgn :: !*OSToolbox -> (!OSRgnHandle, !*OSToolbox);
osnewrgn tb = QNewRgn tb

osnewrectrgn :: !OSRect !*OSToolbox -> (!OSRgnHandle,!*OSToolbox);
osnewrectrgn rect t
	# (region,t) = QNewRgn t
	# t = QRectRgn region (OSRect2Rect rect) t
	= (region,t);

osdisposergn :: !OSRgnHandle !*OSToolbox -> *OSToolbox;
osdisposergn region t = QDisposeRgn region t

ospolyrgn :: !(!Int,!Int) ![(Int,Int)] !OSRgnHandle !*OSToolbox -> (!OSRgnHandle,!*OSToolbox)
ospolyrgn (x,y) l r tb
	// XXX
	= (r,tb)
	
ossectrgn :: !OSRgnHandle !OSRgnHandle !*OSToolbox -> (!OSRgnHandle, !*OSToolbox);
ossectrgn srcRgnA srcRgnB t
	# (destRgn,t)	= QNewRgn t
	= QSectRgn srcRgnA srcRgnB destRgn t

osunionrgn ::!OSRgnHandle !OSRgnHandle !*OSToolbox -> (!OSRgnHandle, !*OSToolbox)
osunionrgn srcRgnA srcRgnB tb
	# (destRgn,tb) = QNewRgn tb
	= QUnionRgn srcRgnA srcRgnB destRgn tb

osdiffrgn :: !OSRgnHandle !OSRgnHandle !*OSToolbox -> (!OSRgnHandle, !*OSToolbox);
osdiffrgn srcRgnA srcRgnB tb
	# (destRgn,tb) = QNewRgn tb
	= QDiffRgn srcRgnA srcRgnB destRgn tb

osgetrgnbox	:: !OSRgnHandle !*OSToolbox -> (!Bool,!OSRect,!*OSToolbox)
osgetrgnbox rgnH tb
	# (isRect,tb)	= IsRegionRectangular rgnH tb
	# (rect,tb)		= GetRegionBounds rgnH tb
	= (isRect<>0,Rect2OSRect rect,tb)

IsRegionRectangular :: !OSRgnHandle !*OSToolbox -> (!Int,!*OSToolbox)
IsRegionRectangular _ _ = code {
	ccall IsRegionRectangular "I:I:I"
	}

osisemptyrgn :: !OSRgnHandle !*OSToolbox -> (!Bool, !*OSToolbox);
osisemptyrgn region t = QEmptyRgn region t

//--

OSRect2Rect r	:== (rleft,rtop,rright,rbottom)
where
	{rleft,rtop,rright,rbottom} = r
Rect2OSRect	(l,t,r,b)	:== {rleft=l,rtop=t,rright=r,rbottom=b}
