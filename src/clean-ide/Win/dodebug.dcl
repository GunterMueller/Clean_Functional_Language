definition module dodebug

import StdOverloaded
import StdControlDef, StdIOCommon, StdPictureDef
import devicefunctions, wstate, layout
import oswindow

trace_n` :: !msg .a -> .a | toString msg	// write toString msg and newline to stderr
										// before evaluating a
instance toString (a,b) | toString a & toString b
instance toString (a,b,c) | toString a & toString b & toString c
instance toString (a,b,c,d) | toString a & toString b & toString c & toString d
instance toString (a,b,c,d,e) | toString a & toString b & toString c & toString d & toString e
instance toString (a,b,c,d,e,f) | toString a & toString b & toString c & toString d & toString e & toString f
instance toString (a,b,c,d,e,f,g) | toString a & toString b & toString c & toString d & toString e & toString f & toString g
instance toString (Maybe x) | toString x
//instance toString SliderMove
//instance toString (DeviceEvent i o)
instance toString ControlUpdateInfo
//instance toString Colour
instance toString RGBColour
instance toString OSRect
instance toString Root
instance toString Relative
instance toString LayoutItem
instance toString ItemOffset
instance toString CrossCallInfo
toOSCrossCallInfoString :: CrossCallInfo -> String
toCleanCrossCallInfoString :: CrossCallInfo -> String
//instance toString DelayActivationInfo

//show :: ![WElementHandle .ls .ps] -> String
show`:: ![WElementHandle`]        -> String
listToString :: [x] -> String | toString x
//instance toString (WElementHandle .ls .ps)
//instance toString (WItemHandle    .ls .ps)
instance toString WElementHandle`
instance toString WItemHandle`
instance toString UpdateInfo

printStackNow :: !Int -> Int
