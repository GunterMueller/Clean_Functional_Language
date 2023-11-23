implementation module ostoolbar


//	Clean object I/O library, version 1.2

//	Operations to add and remove tools.

import	StdMisc, StdTuple
from	osbitmap		import :: OSBitmap, osGetBitmapSize, osGetBitmapContent
import	ostypes, ostoolbox
//from	pictCCall_12	import WinCreateBitmap
//import	clCrossCall_12, windowCCall_12


::	OSToolbar
	=	{	toolbarPtr		:: !OSToolbarHandle		// The toolbar of the frame window (zero if no toolbar)
		,	toolbarHeight	:: !Int					// The height of the toolbar       (zero if no toolbar)
		}
::	OSToolbarHandle
	:==	OSWindowPtr

OSdefaultToolbarHeight :== 16	// The default height of the toolbar

/*	OScreateToolbar wPtr height
		creates a toolbar in the argument window with the given size of the bitmap images.
		The return Int is the actual height of the toolbar. 
*/
osCreateToolbar :: !Bool !OSWindowPtr !(!Int,!Int) !*OSToolbox -> (!(!OSToolbarHandle,!Int),!*OSToolbox)
osCreateToolbar forMDI hwnd (w,h) tb
	= ((OSNoWindowPtr,0),tb)
/*
OScreateToolbar forMDI hwnd (w,h) tb
	# (rcci,tb)		= IssueCleanRequest2 (ErrorCallback2 "OScreateToolbar") (Rq3Cci (if forMDI CcRqCREATEMDITOOLBAR CcRqCREATESDITOOLBAR) hwnd w h) tb
	  tbPtr_Height	= case rcci.ccMsg of
						CcRETURN2	-> (rcci.p1,rcci.p2)
						CcWASQUIT	-> (OSNoWindowPtr,0)
						other		-> abort "[OScreateToolbar] expected CcRETURN1 value."
	= (tbPtr_Height,tb)
*/
osCreateBitmapToolbarItem :: !OSToolbarHandle !OSBitmap !Int !*OSToolbox -> *OSToolbox
osCreateBitmapToolbarItem tbPtr osBitmap index tb
	= tb
/*
OScreateBitmapToolbarItem tbPtr osBitmap index tb
	# (hdc, tb)	= WinGetDC tbPtr tb
	# (hbmp,tb)	= WinCreateBitmap w contents hdc tb
	# (_,tb)	= IssueCleanRequest2 (ErrorCallback2 "OScreateBitmapToolbarItem") (Rq3Cci CcRqCREATETOOLBARITEM tbPtr hbmp index) tb
	# tb		= WinReleaseDC tbPtr (hdc,tb)
	= tb
where
	(w,_)		= OSgetBitmapSize    osBitmap
	contents	= OSgetBitmapContent osBitmap
*/

osCreateToolbarSeparator :: !OSToolbarHandle !*OSToolbox -> *OSToolbox
osCreateToolbarSeparator tbPtr tb
	= tb
/*
OScreateToolbarSeparator tbPtr tb
	= snd (IssueCleanRequest2 (ErrorCallback2 "OScreateBitmapToolbarSeparator") (Rq1Cci CcRqCREATETOOLBARSEPARATOR tbPtr) tb)
*/
