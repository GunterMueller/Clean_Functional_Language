implementation module ostooltip

//	Clean Object I/O library, version 1.2

//	Operations to add and remove tooltip controls and areas.

/*	Tooltip controls are added and removed by osAddControlTooltip and OSremoveControlTooltip.
	The first  OSWindowPtr argument identifies the parent window.
	The second OSWindowPtr argument identifies the control.
	The String argument is the tooltip text.
*/

import	StdTuple, StdString
import	ostoolbox
//import	clCrossCall_12
//from	clCCall_12	import WinMakeCString, WinReleaseCString, CSTR
from	oswindow	import :: OSWindowPtr

osAddControlToolTip :: !OSWindowPtr !OSWindowPtr !String !*OSToolbox -> *OSToolbox
osAddControlToolTip parentPtr controlPtr tip tb
	= tb

osRemoveControlToolTip :: !OSWindowPtr !OSWindowPtr !*OSToolbox -> *OSToolbox
osRemoveControlToolTip parentPtr controlPtr tb
	= tb
	
/*
osAddControlToolTip :: !OSWindowPtr !OSWindowPtr !String !*OSToolbox -> *OSToolbox
osAddControlToolTip parentPtr controlPtr tip tb
	# (textptr,tb)	= WinMakeCString tip tb
	# cci			= Rq3Cci CcRqADDCONTROLTIP parentPtr controlPtr textptr
	# tb			= snd (IssueCleanRequest2 osIgnoreCallback cci tb)
	= WinReleaseCString textptr tb

OSremoveControlToolTip :: !OSWindowPtr !OSWindowPtr !*OSToolbox -> *OSToolbox
OSremoveControlToolTip parentPtr controlPtr tb
	= snd (IssueCleanRequest2 osIgnoreCallback (Rq2Cci CcRqDELCONTROLTIP parentPtr controlPtr) tb)

osIgnoreCallback :: !CrossCallInfo !*OSToolbox -> (!CrossCallInfo,!*OSToolbox)
osIgnoreCallback _ tb 
	= (Return0Cci,tb)
*/
