definition module dodebug

from StdOverloaded	import class toString
from StdPictureDef	import :: Colour
import StdMaybe
import ostoolbox,ostypes
from deviceevents	import :: DeviceEvent, :: SchedulerEvent, :: MsgEvent, :: ControlUpdateInfo

abort` :: !a -> .b	| toString a	// stop reduction and print argument
abort`` :: !.a !b -> .a | toString b

trace_n` :: !msg .a -> .a | toString msg	// write toString msg and newline to stderr
										// before evaluating a
trace_l :: ![a] .b -> .b | toString a
assert :: {#.Char} !.(.a -> (.Bool,.b)) .a -> .b
trace_rgn :: !{#.Char} !Int -> Int
trace_col :: !{#.Char} !Colour -> Colour
assertPort :: !Int !*OSToolbox -> (!Bool,!*OSToolbox)
//		# tb = assert "updateScroll: wrong port" (assertPort wPtr) tb

instance toString OSRect
instance toString (l,r) | toString l & toString r
instance toString (a,b,c) | toString a & toString b & toString c
instance toString (a,b,c,d) | toString a & toString b & toString c & toString d
instance toString (a,b,c,d,e) | toString a & toString b & toString c & toString d & toString e
instance toString (a,b,c,d,e,f) | toString a & toString b & toString c & toString d & toString e & toString f

//instance toString Colour
//instance toString RGBColour

instance toString (Maybe a) | toString a

pretty :: ![a] -> String | toString a

instance toString DeviceEvent
instance toString SchedulerEvent
instance toString MsgEvent
instance toString ControlUpdateInfo

DebugStr :: !String !.a -> .a
DebugStr` :: !msg !.a -> .a | toString msg
