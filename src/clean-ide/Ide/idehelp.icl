implementation module idehelp

import StdFunc, StdMisc
import StdMenu, StdPStClass, StdSystem
import ExtNotice
import ioutil, UtilIO, IdePlatform

//-- export

initHelpMenu :: !Id !*(PSt .b) -> *PSt .b
initHelpMenu wId ps
	# (mId,ps)	= openId ps
	# (_,ps)	= openMenu Void (helpMenu wId mId) ps
	# ps		= helpItems wId mId ps
	= ps

//-- local

helpMenu wId mId
	= Menu "&Help"
		(	MenuItem "&About..." [MenuFunction (noLS (about wId))]
		:+:	SubMenu "&Help" NilLS [MenuId mId]
		)
		[
		]

about wId ps
	# (wId,ps)	= openId ps
	# (bmap,ps)	= getAboutBitmap ps
	| isNothing bmap
		= openNotice (Notice ["AboutIDE bitmap unavailable."] (NoticeButton "OK" id) []) ps
	# bmap		= fromJust bmap
	# (cId,ps)	= openId ps
	# (_,ps)	= openModalDialog dloc (ddef bmap cId wId) ps
	= ps
where
	dloc = 0
	ddef bmap cId wId
		# bitmapSize = 	getBitmapSize bmap
		= Dialog "About the Clean IDE"
						( CustomControl bitmapSize bitmapLook [ControlId cId])
						[ WindowClose (noLS (closeWindow wId))
						, WindowId wId
						, WindowHMargin 0 0
						, WindowVMargin 0 0
						]
	where
		bitmapLook _ _ p
			= draw bmap p
