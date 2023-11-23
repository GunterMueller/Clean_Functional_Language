implementation module dodebug

import StdInt, StdList, StdOverloaded, StdString
import StdControlDef, StdIOCommon, StdPictureDef
import devicefunctions, wstate, layout
import oswindow, clCrossCall_12
import StdDebug

trace_n` :: !msg .a -> .a | toString msg	// write toString msg and newline to stderr
										// before evaluating a
trace_n` m a = trace_n m a

instance toString (a,b) | toString a & toString b where
	toString (a,b) = brackify (itemsList "," [toString a,toString b])
instance toString (a,b,c) | toString a & toString b & toString c where
	toString (a,b,c) = brackify (itemsList "," [toString a,toString b,toString c])
instance toString (a,b,c,d) | toString a & toString b & toString c & toString d where
	toString (a,b,c,d) = brackify (itemsList "," [toString a,toString b,toString c,toString d])
instance toString (a,b,c,d,e) | toString a & toString b & toString c & toString d & toString e where
	toString (a,b,c,d,e) = brackify (itemsList "," [toString a,toString b,toString c,toString d,toString e])
instance toString (a,b,c,d,e,f) | toString a & toString b & toString c & toString d & toString e & toString f where
	toString (a,b,c,d,e,f) = brackify (itemsList "," [toString a,toString b,toString c,toString d,toString e,toString f])
instance toString (a,b,c,d,e,f,g) | toString a & toString b & toString c & toString d & toString e & toString f & toString g where
	toString (a,b,c,d,e,f,g) = brackify (itemsList "," [toString a,toString b,toString c,toString d,toString e,toString f,toString g])
instance toString (Maybe x) | toString x where
	toString Nothing = "Nothing"
	toString (Just x) = brackify ("Just "+++toString x)
//instance toString SliderMove where
//	toString SliderIncSmall			= "SliderIncSmall"
//	toString SliderDecSmall			= "SliderDecSmall"
//	toString SliderIncLarge			= "SliderIncLarge"
//	toString SliderDecLarge			= "SliderDecLarge"
//	toString (SliderThumb thumb)	= brackify ("SliderThumb "+++toString thumb)
/*
instance toString (DeviceEvent i o) where
	toString (MenuTraceEvent _)			= "MenuTraceEvent"
	toString (ToolbarSelection _)		= "ToolbarSelection"
	toString (ReceiverEvent _)			= "ReceiverEvent"
	toString (TimerEvent _)				= "TimerEvent"
	toString (CompoundScrollAction _)	= "CompoundScrollAction"
	toString (ControlGetKeyFocus _)		= "ControlGetKeyFocus"
	toString (ControlKeyboardAction _)	= "ControlKeyboardAction"
	toString (ControlLooseKeyFocus _)	= "ControlLooseKeyFocus"
	toString (ControlMouseAction _)		= "ControlMouseAction"
	toString (ControlSelection _)		= "ControlSelection"
	toString (ControlSliderAction _)	= "ControlSliderAction"
	toString (WindowActivation _)		= "WindowActivation"
	toString (WindowCANCEL _)			= "WindowCANCEL"
	toString (WindowDeactivation _)		= "WindowDeactivation"
	toString (WindowInitialise _)		= "WindowInitialise"
	toString (WindowKeyboardAction _)	= "WindowKeyboardAction"
	toString (WindowMouseAction _)		= "WindowMouseAction"
	toString (WindowOK _)				= "WindowOK"
	toString (WindowRequestClose _)		= "WindowRequestClose"
	toString (WindowScrollAction _)		= "WindowScrollAction"
	toString (WindowSizeAction _)		= "WindowSizeAction"
	toString (WindowUpdate _)			= "WindowUpdate"
	toString ProcessRequestClose		= "ProcessRequestClose"
	toString (ProcessRequestOpenFiles _)= "ProcessRequestOpenFiles"
*/
instance toString ControlUpdateInfo where
	toString {cuItemNr,cuItemPtr,cuArea}
		= curlify (itemsList "," ((map recordFieldtoString (zip2 ["cuItemNr","cuItemPtr"] [cuItemNr,cuItemPtr]))++[recordFieldtoString ("cuArea",cuArea)]))
instance toString Colour where
	toString (RGB rgb)	= brackify ("RGB "+++toString rgb)
	toString Black		= "Black"
	toString White		= "White"
	toString DarkGrey	= "DarkGrey"
	toString Grey		= "Grey"
	toString LightGrey	= "LightGrey"
	toString Red		= "Red"
	toString Green		= "Green"
	toString Blue		= "Blue"
	toString Cyan		= "Cyan"
	toString Magenta	= "Magenta"
	toString Yellow		= "Yellow"
instance toString RGBColour where
	toString {r,g,b}	= curlify (itemsList "," (map recordFieldtoString [("r",r),("g",g),("b",b)]))
instance toString OSRect where
	toString {rleft,rtop,rright,rbottom}
						= curlify (itemsList "," (map recordFieldtoString [("left",rleft),("top",rtop),("right",rright),("bottom",rbottom)]))
instance toString Root where
	toString {rootItem,rootPos,rootTree}
		= curlify (itemsList "," [	recordFieldtoString ("rootItem",rootItem)
								 ,	recordFieldtoString ("rootPos", rootPos)
								 ,	recordFieldtoString ("rootTree",itemsList "," (map toString rootTree))
								 ])
instance toString Relative where
	toString {relativeItem,relativePos}
		= curlify (itemsList "," [	recordFieldtoString ("relativeItem",relativeItem)
								 ,	recordFieldtoString ("relativePos",relativePos)
								 ])
instance toString LayoutItem where
	toString {liId,liItemPos,liItemSize}
		= curlify (itemsList "," [	recordFieldtoString ("liId",      liId)
								 ,	recordFieldtoString ("liItemPos", liItemPos)
								 ,	recordFieldtoString ("liItemSize",liItemSize)
								 ])
instance toString ItemOffset where
	toString NoOffset			= "NoOffset"
	toString (OffsetVector v)	= brackify "OffsetVector "+++toString v
	toString (OffsetFun  i f)	= brackify "OffsetFun "+++toString i
instance toString CrossCallInfo where
	toString {ccMsg,p1,p2,p3,p4,p5,p6}
		= toString (ccMsgString ccMsg,p1,p2,p3,p4,p5,p6)
	where
		ccMsgString CcWmACTIVATE			= "CcWmACTIVATE"
		ccMsgString CcWmBUTTONCLICKED		= "CcWmBUTTONCLICKED"
		ccMsgString CcWmCHAR				= "CcWmCHAR"
		ccMsgString CcWmCLOSE				= "CcWmCLOSE"
		ccMsgString CcWmCOMBOSELECT			= "CcWmCOMBOSELECT"
		ccMsgString CcWmCOMMAND				= "CcWmCOMMAND"
		ccMsgString CcWmCREATE				= "CcWmCREATE"
		ccMsgString CcWmDDEEXECUTE			= "CcWmDDEEXECUTE"
		ccMsgString CcWmDEACTIVATE			= "CcWmDEACTIVATE"
		ccMsgString CcWmDRAWCLIPBOARD		= "CcWmDRAWCLIPBOARD"
		ccMsgString CcWmDRAWCONTROL			= "CcWmDRAWCONTROL"
		ccMsgString CcWmGETHSCROLLVAL		= "CcWmGETHSCROLLVAL"
		ccMsgString CcWmGETSCROLLBARINFO	= "CcWmGETSCROLLBARINFO"
		ccMsgString CcWmGETTOOLBARTIPTEXT	= "CcWmGETTOOLBARTIPTEXT"
		ccMsgString CcWmGETVSCROLLVAL		= "CcWmGETVSCROLLVAL"
		ccMsgString CcWmIDLEDIALOG			= "CcWmIDLEDIALOG"
		ccMsgString CcWmIDLETIMER			= "CcWmIDLETIMER"
		ccMsgString CcWmINITDIALOG			= "CcWmINITDIALOG"
		ccMsgString CcWmKEYBOARD			= "CcWmKEYBOARD"
		ccMsgString CcWmKILLFOCUS			= "CcWmKILLFOCUS"
//		ccMsgString CcWmLOSEMODELESSDLOG	= "CcWmLOSEMODELESSDLOG"
		ccMsgString CcWmMOUSE				= "CcWmMOUSE"
		ccMsgString CcWmNEWHTHUMB			= "CcWmNEWHTHUMB"
		ccMsgString CcWmNEWVTHUMB			= "CcWmNEWVTHUMB"
		ccMsgString CcWmPAINT				= "CcWmPAINT"
		ccMsgString CcWmPROCESSCLOSE		= "CcWmPROCESSCLOSE"
		ccMsgString CcWmPROCESSDROPFILES	= "CcWmPROCESSDROPFILES"
		ccMsgString CcWmSCROLLBARACTION		= "CcWmSCROLLBARACTION"
		ccMsgString CcWmSETFOCUS			= "CcWmSETFOCUS"
		ccMsgString CcWmSIZE				= "CcWmSIZE"
		ccMsgString CcWmSPECIALBUTTON		= "CcWmSPECIALBUTTON"
		ccMsgString CcWmTIMER				= "CcWmTIMER"
		ccMsgString CcWmZEROTIMER			= "CcWmZEROTIMER"
		ccMsgString msg						= "(Other message: "+++toString msg+++")"
toOSCrossCallInfoString :: CrossCallInfo -> String
toOSCrossCallInfoString cci = toString cci
toCleanCrossCallInfoString :: CrossCallInfo -> String
toCleanCrossCallInfoString cci = toString cci
//instance toString DelayActivationInfo where
//	toString (DelayActivated   wPtr)		= brackify ("DelayActivated "  +++toString wPtr)
//	toString (DelayDeactivated wPtr)		= brackify ("DelayDeactivated "+++toString wPtr)

curlify  x = "{"+++x+++"}"
brackify x = "("+++x+++")"
squarify x = "["+++x+++"]"

recordFieldtoString :: (String,a) -> String | toString a
recordFieldtoString (field,value) = field+++"="+++toString value

itemsList :: !String ![String] -> String
itemsList separator [x:xs]
	= x+++itemsList` xs
where
	itemsList` [x:xs]	= separator+++x+++itemsList` xs
	itemsList` _		= ""
itemsList _ _
	= ""


//show :: ![WElementHandle .ls .ps] -> String
//show itemHs = squarify (itemsList "\n," (map toString itemHs))
show` :: ![WElementHandle`] -> String
show` itemHs` = squarify (itemsList "\n," (map toString itemHs`))

listToString :: [x] -> String | toString x
listToString xs = squarify (itemsList "," (map toString xs))
/*
instance toString (WElementHandle .ls .ps) where
	toString (WListLSHandle itemHs) = brackify ("WListLSHandle "+++show itemHs)
	toString (WExtendLSHandle {wExtendItems}) = brackify ("WExtendLSHandle "+++show wExtendItems)
	toString (WChangeLSHandle {wChangeItems}) = brackify ("WChangeLSHandle "+++show wChangeItems)
	toString (WItemHandle itemH)			  = brackify ("WItemHandle "+++toString itemH)
instance toString (WItemHandle .ls .ps) where
	toString {wItemKind,wItemPos,wItemSize,wItems}
		= toString (wItemKind,wItemPos,wItemSize,show wItems)
*/
instance toString WElementHandle` where
	toString (WRecursiveHandle` itemHs wkind) = brackify (toString wkind+++" "+++show` itemHs)
	toString (WItemHandle` itemH)			  = brackify ("WItemHandle` "+++toString itemH)
instance toString WItemHandle` where
	toString {wItemKind`,wItemPos`,wItemSize`,wItems`}
		= toString (wItemKind`,wItemPos`,wItemSize`,show` wItems`)
instance toString WRecursiveKind where
	toString IsWListLSHandle	= "IsWListLSHandle"
	toString IsWExtendLSHandle	= "IsWExtendLSHandle"
	toString IsWChangeLSHandle	= "IsWChangeLSHandle"

instance toString UpdateInfo where
	toString info = "{" +++ toString info.updWIDS.wPtr +++ 
					"," +++ toString info.updWindowArea+++ 
//					"," +++ toString info.updControls+++ 
					"," +++ toString info.updGContext+++ 
					"}"

import code from "printStackNow.obj"

printStackNow :: !Int -> Int	// in 2.0.2 only works with stack trace only...
printStackNow stackDepth = code {
	ccall printStackNow "I:I"
	}

/*
Start = testPS 8

testPS n
	| n == 0 = printStackNow 10
	| testPS (dec n) == 0 = 0
							= 1
*/
