implementation module processdevice


//	Clean object I/O library, version 1.2

import StdBool, StdFunc, StdMisc
import StdPSt
import commondef, devicefunctions, processevent, StdProcessAttribute, toolbar


processdeviceFatalError :: String String -> .x
processdeviceFatalError rule error
	= fatalError rule "processdevice" error


processFunctions :: DeviceFunctions (PSt .l)
processFunctions
	= {	dDevice	= ProcessDevice
	  ,	dShow	= id//processShow
	  ,	dHide	= id//processHide
	  ,	dEvent	= processEvent
	  ,	dDoIO	= processIO
	  ,	dOpen	= processOpen
	  ,	dClose	= processClose
	  }

//processOpen :: !(PSt .l) -> PSt .l
processOpen pState=:{io=ioState}
	# (hasProcess,ioState)			= ioStHasDevice ProcessDevice ioState
	| hasProcess
		= {pState & io=ioState}
	| otherwise
		# ioState					= appIOToolbox osInitialiseDI ioState
		# ioState					= ioStSetDeviceFunctions processFunctions ioState
		# (osdinfo,ioState)			= ioStGetOSDInfo ioState
		# ioState					= createOSDInfo osdinfo ioState
		= {pState & io=ioState}
where
//	createOSDInfo :: !OSDInfo !(IOSt .l) -> IOSt .l
	createOSDInfo emptyOSDInfo ioState
		| di==NDI
			= ioStSetOSDInfo emptyOSDInfo ioState
		# (atts,ioState)	= ioStGetProcessAttributes ioState
		  acceptOpenFiles	= contains isProcessOpenFiles atts
		# (tb,ioState)		= getIOToolbox ioState
		| di==MDI
			# hasToolbarAtt	= contains isProcessToolbar   atts
			# (osdinfo,tb)	= osOpenMDI (not hasToolbarAtt) acceptOpenFiles tb
			# ioState		= setIOToolbox tb ioState
			# ioState		= ioStSetOSDInfo osdinfo ioState
			# ioState		= openToolbar ioState
			= ioState
		| di==SDI
			# (osdinfo,tb)	= osOpenSDI acceptOpenFiles tb
			# ioState		= setIOToolbox tb ioState
			# ioState		= ioStSetOSDInfo osdinfo ioState
			# ioState		= openToolbar ioState
			= ioState
	where
		di					= getOSDInfoDocumentInterface emptyOSDInfo

//processClose :: !(PSt .l) -> PSt .l
processClose pState=:{io=ioState}
	# (_,_,ioState)	= ioStGetDevice ProcessDevice ioState
	# ioState		= ioStRemoveDeviceFunctions ProcessDevice ioState
	= {pState & io=ioState}

//processIO :: !DeviceEvent !(PSt .l) -> (!DeviceEvent,!PSt .l)

processIO deviceEvent=:ProcessRequestClose pState
	# (atts,pState)		= accPIO ioStGetProcessAttributes pState
	  (hasCloseAtt,att)	= cselect isProcessClose undef atts
	| not hasCloseAtt
		= (deviceEvent,pState)
	| otherwise
		= (deviceEvent,getProcessCloseFun att pState)

processIO deviceEvent=:(ProcessRequestOpenFiles openFilesInfo) pState
	# (atts,pState)			= accPIO ioStGetProcessAttributes pState
	  (hasFilesOpenAtt,att)	= cselect isProcessOpenFiles undef atts
	| not hasFilesOpenAtt
		= (deviceEvent,pState)
	| otherwise
		= (deviceEvent,getProcessOpenFilesFun att openFilesInfo pState)

// DvA...
processIO deviceEvent=:(ProcessRequestClipboardChanged) pState
	# (atts,pState)			= accPIO ioStGetProcessAttributes pState
	  (hasClipChangeAtt,att)= cselect isProcessClipboardChanged undef atts
	| not hasClipChangeAtt
		= (deviceEvent,pState)
	| otherwise
		= (deviceEvent,getProcessClipboardChangedFun att pState)

processIO deviceEvent=:(ConsoleQuitEvent) pState
	# (atts,pState)			= accPIO ioStGetProcessAttributes pState
	  (hasAtt,att)= cselect isProcessConsoleQuit undef atts
	| not hasAtt
		= (deviceEvent,pState)
	| otherwise
		= (deviceEvent,getProcessConsoleQuitFun att pState)
processIO deviceEvent=:(ConsoleOutEvent msg) pState
	# (atts,pState)			= accPIO ioStGetProcessAttributes pState
	  (hasAtt,att)= cselect isProcessConsoleOut undef atts
	| not hasAtt
		= (deviceEvent,pState)
	| otherwise
		= (deviceEvent,getProcessConsoleOutFun att msg pState)
processIO deviceEvent=:(ConsoleErrEvent msg) pState
	# (atts,pState)			= accPIO ioStGetProcessAttributes pState
	  (hasAtt,att)= cselect isProcessConsoleErr undef atts
	| not hasAtt
		= (deviceEvent,pState)
	| otherwise
		= (deviceEvent,getProcessConsoleErrFun att msg pState)
// ...DvA

processIO _ _
	= processdeviceFatalError "processIO" "unexpected DeviceEvent"
