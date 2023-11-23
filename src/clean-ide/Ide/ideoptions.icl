implementation module ideoptions

import StdFunc
import StdWindow
import StdPStClass
import IdeState
import ioutil, tools

ideOptionsDialog :: !*(PSt *General) -> *(PSt *General)
ideOptionsDialog ps
	# (prefs,ps)	= getPrefs ps
	# (wId,ps)		= openId ps
	# (okId,ps)		= openId ps
	# iniSWMark		= toMark prefs.switch_close
	# iniTBMark		= toMark prefs.show_toolbar
	# iniBVMark		= toMark prefs.be_verbose
	# (iniNHIndex,iniCVIndex)
					= case prefs.newline_handling of
						(LeaveAlone NewlineConventionNone)	-> (1,1)
						(LeaveAlone NewlineConventionMac)	-> (1,2)
						(LeaveAlone NewlineConventionUnix)	-> (1,3)
						(LeaveAlone NewlineConventionDos)	-> (1,4)
						(AlwaysUse NewlineConventionNone)	-> (2,1)
						(AlwaysUse NewlineConventionMac)	-> (2,2)
						(AlwaysUse NewlineConventionUnix)	-> (2,3)
						(AlwaysUse NewlineConventionDos)	-> (2,4)
	# iniAWMark		= toMark prefs.altgr_workaround
	# (ti,ps)		= toolData prefs ps
	# (_,ps)		= openModalDialog Void (ddef iniSWMark iniTBMark iniBVMark iniNHIndex iniCVIndex iniAWMark
						ti okId wId) ps
	= ps

ddef
	iniSWMark iniTBMark iniBVMark iniNHIndex iniCVIndex iniAWMark
	ti okId wId
	= Dialog "IDE Options"
		(	CheckControl
			[("Switch windows",Nothing,iniSWMark,noLS switchSW)
			,("Show toolbar",Nothing,iniTBMark,noLS switchTB)
			,("Verbose diagnostics",Nothing,iniBVMark,noLS switchBV)
			,("AltGr workaround",Nothing,iniAWMark,noLS switchAW)
			] (Columns 1) []
		:+: TextControl "Newline Handling"
			[ControlPos (Left,zero)]
		:+: RadioControl
			[("Leave existing files alone and use given convention for new files",Nothing,noLS (changeNH LeaveAlone))
			,("Always save using given convention",Nothing,noLS (changeNH AlwaysUse))
			]
			(Columns 1)
			(iniNHIndex)
			[ControlPos (Left,zero)]
		:+: TextControl "Newline Convention"
			[ControlPos (Left,zero)]
		:+: RadioControl
			[("Native",Nothing,noLS (changeCV NewlineConventionNone))
			,("Mac",Nothing,noLS (changeCV NewlineConventionMac))
			,("Unix",Nothing,noLS (changeCV NewlineConventionUnix))
			,("Dos",Nothing,noLS (changeCV NewlineConventionDos))
			]
			(Rows 1)
			(iniCVIndex)
			[ControlPos (Left,zero)]
		:+: toolOptions ti
		:+: ButtonControl "OK" [ControlPos (Right,zero), ControlFunction (noLS (closeWindow wId)), ControlId okId]
		) [WindowClose (noLS (closeWindow wId)), WindowId wId, WindowOk okId, WindowCancel okId]

switchAW ps
	# (prefs,ps)	= getPrefs ps
	# prefs			= {prefs & altgr_workaround = not prefs.altgr_workaround}
	= setPrefs prefs ps

switchSW ps
	# (prefs,ps)	= getPrefs ps
	# prefs			= {prefs & switch_close = not prefs.switch_close}
	= setPrefs prefs ps

switchTB ps
	# (prefs,ps)	= getPrefs ps
	# prefs			= {prefs & show_toolbar = not prefs.show_toolbar}
	= setPrefs prefs ps

switchBV ps
	# (prefs,ps)	= getPrefs ps
	# prefs			= {prefs & be_verbose = not prefs.be_verbose}
	= setPrefs prefs ps

changeNH nh ps
	# (prefs,ps)	= getPrefs ps
	# prefs			= {prefs & newline_handling = case prefs.newline_handling of
						(LeaveAlone conv)	-> nh conv
						(AlwaysUse conv)	-> nh conv
					  }
	= setPrefs prefs ps

changeCV cv ps
	# (prefs,ps)	= getPrefs ps
	# prefs			= {prefs & newline_handling = case prefs.newline_handling of
						(LeaveAlone _)	-> LeaveAlone cv
						(AlwaysUse _)	-> AlwaysUse cv
					  }
	= setPrefs prefs ps
