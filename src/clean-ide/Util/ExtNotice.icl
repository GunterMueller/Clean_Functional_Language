implementation module ExtNotice

import StdTuple, StdMisc, StdFunc
import StdId, StdPSt, StdWindow, StdTimer

:: Notice ls ps
	= Notice [String] (NoticeButton *(ls,ps)) [NoticeButton *(ls,ps)]

:: NoticeButton ps
	= NoticeButton String (IdFun ps)

instance Dialogs Notice
where
//	openDialog :: .ls (Notice .ls (PSt .l)) (PSt .l) -> (!ErrorReport, !PSt .l)
	openDialog ls notice ps
		#	(wId, ps)	= accPIO openId ps
			(okId,ps)	= accPIO openId ps
		=	openDialog ls (noticeToDialog wId okId notice) ps
	
//	openModalDialog :: .ls (Notice .ls (PSt .l)) (PSt .l) -> (!(!ErrorReport,!Maybe .ls),!PSt .l)
	openModalDialog ls notice ps
		#	(wId, ps)	= accPIO openId ps
			(okId,ps)	= accPIO openId ps
		=	openModalDialog ls (noticeToDialog wId okId notice) ps
	
//	getDialogType :: (Notice .ls .ps) -> WindowType
	getDialogType _
		= "Notice"

openNotice :: !(Notice .ls *(PSt .l)) !*(PSt .l) -> *PSt .l
openNotice notice ps
//	= snd (openModalDialog undef notice ps)
	# (_,ps)	= openModalDialog undef notice ps
	= ps

//noticeToDialog :: Id Id !(Notice .ls (PSt .l)) -> Dialog
noticeToDialog wid okid (Notice texts ok buttons)
	= Dialog "" (texts` :+: ok` :+: buttons`)
		[ WindowId wid
		, WindowOk okid
		, WindowCancel okid
		]
where
	texts`		= LayoutControl
					( ListLS
						[ TextControl text [ControlPos (Left,zero)]
						\\ text <- texts
						]
					)
					[ ControlHMargin 0 0
					, ControlVMargin 0 0
					, ControlItemSpace 3 3
					]
	ok`			= noticebutton ok [ControlPos (Right,zero), ControlId okid]
	buttons`	= ListLS
					[ noticebutton button [ControlPos (LeftOfPrev,zero)]
					\\ button <- buttons
					]
	noticebutton (NoticeButton text f) atts
		= ButtonControl text [ControlFunction f`:atts]
	where
		f` (ls,ps) = f (ls,closeWindow wid ps)

okNotice text ps :== openNotice (Notice text (NoticeButton "OK" (\x->x)) []) ps

:: TimedNotice ls ps
	= TimedNotice [String] TimerInterval (NoticeButton *(ls,ps)) [NoticeButton *(ls,ps)]

instance Dialogs TimedNotice
where
//	openDialog :: .ls (TimedNotice .ls (PSt .l)) (PSt .l) -> (!ErrorReport, !PSt .l)
	openDialog ls notice ps
		#	(wId, ps)	= accPIO openId ps
			(okId,ps)	= accPIO openId ps
		=	openDialog ls (timednoticeToDialog wId okId notice) ps
	
//	openModalDialog :: .ls (TimedNotice .ls (PSt .l)) (PSt .l) -> (!(!ErrorReport,!Maybe .ls),!PSt .l)
	openModalDialog ls notice ps
		#	(wId, ps)	= accPIO openId ps
			(okId,ps)	= accPIO openId ps
		=	openModalDialog ls (timednoticeToDialog wId okId notice) ps
	
//	getDialogType :: (TimedNotice .ls .ps) -> WindowType
	getDialogType _
		= "TimerNotice"

openTimedNotice :: !(TimedNotice .ls *(PSt .l)) !*(PSt .l) -> *PSt .l
openTimedNotice notice ps
	= snd (openModalDialog undef notice ps)

//timednoticeToDialog :: Id Id !(TimedNotice .ls (PSt .l)) -> Dialog
timednoticeToDialog wid okid (TimedNotice texts time ok buttons)
	= Dialog "" (texts` :+: ok` :+: buttons`)
		[ WindowId wid
		, WindowOk okid
		, WindowInit (noLS timestuff)
		]
where
	timestuff ps
		# (err,ps) = openTimer Void timer` ps
		| err <> NoError 
			# ps = okNotice ["Timer Creation Failed"] ps
			# ps = closeWindow wid ps
			= ps
		= ps
	where
		timer` = Timer time NilLS [TimerFunction (\_ (ls,ps)->(ls,closeWindow wid ps))]
	texts`		= LayoutControl
					( ListLS
						[ TextControl text [ControlPos (Left,zero)]
						\\ text <- texts
						]
					)
					[ ControlHMargin 0 0
					, ControlVMargin 0 0
					, ControlItemSpace 3 3
					]
	ok`			= noticebutton ok [ControlPos (Right,zero), ControlId okid]
	buttons`	= ListLS
					[ noticebutton button [ControlPos (LeftOfPrev,zero)]
					\\ button <- buttons
					]
	noticebutton (NoticeButton text f) atts
		= ButtonControl text [ControlFunction f`:atts]
	where
		f` (ls,ps) = f (ls,closeWindow wid ps)

okTimedNotice text time ps :== openTimedNotice (TimedNotice text time (NoticeButton "OK" (\x->x)) []) ps

