implementation module dodebug

import StdEnv,StdPictureDef
from	quickdraw import QGetPort, :: GrafPtr
import Platform

assert :: {#.Char} !.(.a -> (.Bool,.b)) .a -> .b
assert txt test env
	# (ok,env)	= test env
	| ok = env
	= abort txt

import osrgn,StdDebug

abort` :: !a -> .b	| toString a	// stop reduction and print argument
abort` a = abort (toString a)

abort`` :: !.a !b -> .a | toString b
abort`` a b = abort (toString b)

trace_l :: ![a] .b -> .b | toString a
trace_l [] e = e
trace_l [h:t] e
	#! e = trace_n` h e
	= trace_l t e

trace_rgn :: !{#.Char} !Int -> Int
trace_rgn txt rgn
	# (isRect,rct,_)= osgetrgnbox rgn OSNewToolbox
	# rgn			= trace_n` (txt+++xxx rct isRect) rgn
	= rgn
where
	xxx {rleft,rtop,rright,rbottom} isRect =
			"[("+++toString rleft+++
			","+++toString rtop +++
			"),("+++toString rright+++
			","+++toString rbottom+++
			")] "+++toString isRect

trace_col :: !{#.Char} !Colour -> Colour
trace_col txt col
	= trace_n` (txt+++xxx col) col
where
	xxx colour = case colour of
							Black	-> "BlackColor"
							White	-> "WhiteColor"
							Red		-> "RedColor"
							Green	-> "GreenColor"
							Blue	-> "BlueColor"
							Cyan	-> "CyanColor"
							Magenta	-> "MagentaColor"
							Yellow	-> "YellowColor"
							RGB rgb		-> "rgb"
							DarkGrey	-> "DarkGrey"
							Grey		-> "Grey"
							LightGrey	-> "LightGrey"


assertPort :: !Int !*OSToolbox -> (!Bool,!*OSToolbox)
assertPort p tb
	# (q,tb)	= QGetPort tb
	= (p==q,tb)
		
instance toString OSRect
where
	toString {rleft,rtop,rright,rbottom} = "{("+++toString rleft+++","+++toString rtop+++"),("+++toString rright+++","+++toString rbottom+++")}"

instance toString (l,r) | toString l & toString r
where
	toString (l,r) = "("+++toString l+++","+++toString r+++")"

instance toString (a,b,c) | toString a & toString b & toString c
where
	toString (a,b,c) = "("+++toString a+++","+++toString b+++","+++toString c+++")"

instance toString (a,b,c,d) | toString a & toString b & toString c & toString d
where
	toString (a,b,c,d) = "("+++toString a+++","+++toString b+++","+++toString c+++","+++toString d+++")"

instance toString (a,b,c,d,e) | toString a & toString b & toString c & toString d & toString e
where
	toString (a,b,c,d,e) = "("+++toString a+++","+++toString b+++","+++toString c+++","+++toString d+++","+++toString e+++")"

instance toString (a,b,c,d,e,f) | toString a & toString b & toString c & toString d & toString e & toString f
where
	toString (a,b,c,d,e,f) = "("+++toString a+++","+++toString b+++","+++toString c+++","+++toString d+++","+++toString e+++","+++toString f+++")"

instance toString Colour where
	toString (RGB rgb)	=  "(RGB "+++toString rgb+++")"
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
	toString {r,g,b}	= "{"+++ (itemsList "," (map recordFieldtoString [("r",r),("g",g),("b",b)]))+++"}"

itemsList :: !String ![String] -> String
itemsList separator [x:xs]
	= x+++itemsList` xs
where
	itemsList` [x:xs]	= separator+++x+++itemsList` xs
	itemsList` _		= ""
itemsList _ _
	= ""

curlify  x = "{"+++x+++"}"
brackify x = "("+++x+++")"
squarify x = "["+++x+++"]"

recordFieldtoString :: (String,a) -> String | toString a
recordFieldtoString (field,value) = field+++"="+++toString value

pretty :: ![a] -> String | toString a
pretty l = brackify (itemsList "," (map toString l))

import StdMaybe

instance toString (Maybe a) | toString a
where
	toString Nothing = "Nothing"
	toString (Just a) = "Just "+++.toString a

import deviceevents

instance toString MsgEvent
where
	toString (QASyncMessage msg)	= "QASyncMessage"
	toString (ASyncMessage msg)		= "ASyncMessage"
	toString (SyncMessage msg)		= "SyncMessage"

instance toString ControlUpdateInfo
where
	toString
		{	cuItemNr			//:: !Int						// The wItemNr of the control
		,	cuItemPtr			//:: !OSWindowPtr				// The wItemPtr to the control (can be OSNoWindowPtr)
		,	cuArea				//:: !OSRect					// The update area of the control (in window coordinates)
		} = "{"+++toString cuItemNr +:+ toString cuItemPtr +:+ toString cuArea+++"}"

(+:+) infixr 5 :: String String -> String
(+:+) l r = l +++ ","+++ r

instance toString DeviceEvent where
	toString (MenuTraceEvent _)			= "MenuTraceEvent"
	toString (ToolbarSelection _)		= "ToolbarSelection"
	toString (ReceiverEvent _)			= "ReceiverEvent"
	toString (InternetEvent _)				= "InternetEvent"
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
	toString ProcessRequestClipboardChanged		= "ProcessRequestClipboardChanged"

instance toString SchedulerEvent
where
	toString (ScheduleOSEvent event=:(a,b,c,d,e,f,g) list)
		= "ScheduleOSEvent: " +++ toString (a,b,c) +++ toString (d,e,f,g)
	toString (ScheduleMsgEvent event)		= "ScheduleMsgEvent"
	toString (ScheduleTimerEvent event)		= "ScheduleTimerEvent"

DebugStr :: !String !.a -> .a
DebugStr s a
	| onOSX
		# s = {toChar (size s)} +++ s
		| 42 == DebugStr s 42 = a
		= a
	= trace_n s a
where
	DebugStr :: !String !*Int -> *Int
	DebugStr _ _ = code {
		ccall DebugStr "Ps:V:I"
		}

trace_n` :: !msg .a -> .a | toString msg	// write toString msg and newline to stderr
										// before evaluating a
trace_n` m a
	= DebugStr (toString m) a
//	= trace_n m a

DebugStr` :: !msg !.a -> .a | toString msg
DebugStr` msg a
	= DebugStr (toString msg) a
