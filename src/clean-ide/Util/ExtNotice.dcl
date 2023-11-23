definition module ExtNotice

// notices inspired by Object IO Tutorial

import StdWindow, StdTimerDef

:: Notice ls ps
	= Notice [String] (NoticeButton *(ls,ps)) [NoticeButton *(ls,ps)]

:: NoticeButton ps
	= NoticeButton String (IdFun ps)

instance Dialogs Notice

openNotice :: !(Notice .ls *(PSt .l)) !*(PSt .l) -> *PSt .l

okNotice text ps
	:== openNotice (Notice text (NoticeButton "OK" (\x->x)) []) ps

:: TimedNotice ls ps
	= TimedNotice [String] TimerInterval (NoticeButton *(ls,ps)) [NoticeButton *(ls,ps)]

instance Dialogs TimedNotice

openTimedNotice :: !(TimedNotice .ls *(PSt .l)) !*(PSt .l) -> *PSt .l

okTimedNotice text time ps
	:== openTimedNotice (TimedNotice text time (NoticeButton "OK" (\x->x)) []) ps
