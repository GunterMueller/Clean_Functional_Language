implementation module conswin

import StdClass, StdInt, StdList, StdFunc, StdMisc
import StdPSt, StdWindow, StdControlReceiver, StdMenuElement
import EdLook, EdMessage, EdVisualText, EdWindow
import EdMouse, EdKeyboard

from StrictList import slFromList
from UtilStrictLists import StrictListToList,:: List,:!,IsEmptyList

import IDE,IdeState,UtilObjectIO

//--

isConsoleWindow :: !Id !.ConsWinInfo -> Bool
isConsoleWindow xId {ConsWinInfo | wId}
	= xId==wId

//--

:: ConsWinInfo =
	{ wId	:: !Id		// id of the console window
	, eId	:: !EditId	// receiver id
	, uId	:: !Id		// id of undo menu item
//	, oId	:: !Id		// id of options menu item
	, ids	:: ![Id]	// ids to disable when console is active
	, tfnt	:: !Font	// window font
	, tpos	:: !Vector2	// window pos
	, tsiz	:: !Size	// window size
	, sync	:: !SyntaxColours
	}

class Consoler env
where
	getConsWinInfo :: !*env -> *(!ConsWinInfo, !*env)
	setConsWinInfo :: !ConsWinInfo !*env -> *env

getConsWinInf :: *(PSt *b) -> *(ConsWinInfo,*PSt *b) | Consoler b
getConsWinInf ps = accPLoc getConsWinInfo ps

setConsWinInf :: .ConsWinInfo *(PSt *b) -> *PSt *b | Consoler b
setConsWinInf twi ps = appPLoc (setConsWinInfo twi) ps


//--- Console window

iniConsWinInfo :: !Id !Id ![Id] !ConPrefs !*a -> *(.ConsWinInfo,*a) | accScreenPicture, Ids a
iniConsWinInfo mId uId ids prefs env
	# ((ok,cwFont),env)	= accScreenPicture (openFont prefs.conswinfont) env
	| not ok = abort "Unable to open font for Console window"
	# (wId,env) = openId env
	# (eId,env) = openEditId env
	= (	{wId=wId
		,eId=eId
		,uId=uId
		,ids=ids
		,tfnt=cwFont
		,tpos=prefs.conswinpos
		,tsiz=prefs.conswinsiz
		,sync=prefs.conswinsync
		},env)

getConPrefs :: !ConsWinInfo -> ConPrefs
getConPrefs {tfnt,tpos,tsiz,sync} =
	{ conswinfont	= getFontDef tfnt
	, conswinpos	= tpos
	, conswinsiz	= tsiz
	, conswinsync	= sync
	}

getConWind :: !ConsWinInfo -> Id
getConWind {ConsWinInfo | wId} = wId

getConSync {sync} = sync
setConSync sync cons = {cons & sync = sync}
setConFont font cons = {cons & tfnt = font}

//--

updateConsoleWindowI :: !String [WindowAttribute *(EditState,*(PSt *b))] !*(PSt *b) -> *PSt *b | Consoler b
updateConsoleWindowI message atts ps
	= updateConsoleWindow message atts ps

updateConsoleWindowO :: !String [WindowAttribute *(EditState,*(PSt *b))] !*(PSt *b) -> *PSt *b | Consoler b
updateConsoleWindowO message atts ps
	= updateConsoleWindow message atts ps

updateConsoleWindowE :: !String [WindowAttribute *(EditState,*(PSt *b))] !*(PSt *b) -> *PSt *b | Consoler b
updateConsoleWindowE message atts ps
	= updateConsoleWindow message atts ps

updateConsoleWindow :: !String [WindowAttribute *(EditState,*(PSt *b))] !*(PSt *b) -> *PSt *b | Consoler b
updateConsoleWindow message atts ps
	# textfrag								= stringToStrings message
	# (twi=:{ConsWinInfo | wId,eId},ps)					= getConsWinInf ps
	# (iswin,ps)							= isWindow wId ps
	| iswin
		// only update
		#! (_,ps)							= cons_message eId (vAppendText textfrag) ps
		= ps
	// open & update
	# text									= newText
	# ps									= openConsoleWindow twi text atts ps
	#! (_,ps)								= cons_message eId (vAppendText textfrag) ps
	= ps

maybe_cons_win_message2 :: .(EditMonad *(PSt *b) .c) !*(PSt *b) -> (Maybe .c,*(PSt *b)) | Consoler b
maybe_cons_win_message2 message ps
	# (twi=:{eId},ps)		= getConsWinInf ps
	# (has,ps)				= hasEditState eId ps
	| has
		= cons_message eId message ps
	= (Nothing,ps)

cons_message editId monad pState
	# (x,pState)					= appEditState editId monad pState
	= (Just x,pState)

//---

openConsoleWindow cwi text atts ps
	# editId						= cwi.eId
	# windowId						= cwi.ConsWinInfo.wId
	# pathName						= "" 									// dummy pathname
	# title							= "Console"
	# tabs							= (4,True,False,False,True)
	# (editState, ps)				= initEditState windowId cwi.uId pathName cwi.tfnt tabs 0 cwi.sync ps
	# (_, (editState, ps))			= setText text (editState, ps)
	# (fontInfo, (editState, ps))	= getFontInfo (editState, ps) 
	# (viewDomain, (editState, ps))	= computeViewDomain (editState, ps)
//	# (editState,editLook)			= editWindowLook editState
	# editLook						= editWindowLook editState
	# windowAttrs 
	  = [ WindowOuterSize  	cwi.tsiz
		, WindowHMargin	  	0 0
		, WindowVMargin	  	0 0
		, WindowId		  	windowId
		, WindowViewDomain	viewDomain
		, WindowLook		True editLook
		, WindowHScroll		(altScrollFunction Horizontal fontInfo.metrics.fMaxWidth)
		, WindowVScroll		(alignScrollFunction Vertical fontInfo.FontInfo.lineHeight)
		, WindowPos			(Fix, OffsetVector cwi.tpos)
		, WindowClose		(noLS (cw_close o cw_deactivate))				// be careful here if editable...
		, WindowActivate	(noLS (cw_activate))
		, WindowDeactivate 	(noLS (cw_deactivate))
		: atts
		]
	# receiver	  					= openEditReceiver editId
	# window						= Window title receiver windowAttrs
	# (_, ps)	 					= openWindow editState window ps
	= ps

//--

cons_safe_close :: !*(PSt *b) -> *PSt *b | Consoler b
cons_safe_close ps
	# (win,ps)	= accPIO getActiveWindow ps
	| isNothing win
		= cw_close ps
	# win = fromJust win
	# (twi,ps)	= getConsWinInf ps
	| isConsoleWindow win twi
		# ps	= cw_deactivate ps
		= cw_close ps
	= cw_close ps

cw_close :: !*(PSt *b) -> *PSt *b | Consoler b
cw_close ps
	# (twi=:{ConsWinInfo | wId},ps)	= getConsWinInf ps
	# (mpos,ps) = accPIO (getWindowPos wId) ps
	| isNothing mpos
		= ps
	# tpos		= fromJust mpos
	# (tsiz,ps) = accPIO (getWindowOuterSize wId) ps
	# twi		= {twi & tpos = tpos, tsiz = tsiz}
	# ps		= setConsWinInf twi ps
	# ps		= closeWindow wId ps
	= ps

cw_activate ps
	# (twi,ps=:{io})	= getConsWinInf ps
//	# io = enableMenuElements [twi.oId] io
	# io = disableMenuElements twi.ids io
	= {ps & io = io}

cw_deactivate ps
	# (twi,ps=:{io})	= getConsWinInf ps
//	# io = disableMenuElements [twi.oId] io
	# io = enableMenuElements twi.ids io
	= {ps & io = io}

//-- cons win options...

import morecontrols, colorpickcontrol, ioutil, colourclip
import StdClipboard

::CWC_LS =
	{ cur	:: CWC_CR	// current colour
	, txt	:: Colour
	, cmt	:: Colour
	, mod	:: Colour
	, bck	:: Colour
	, fn	:: String	// font name
	, fs	:: Int		// font size
	}

::CWC_CR
	= TXT
	| CMT
	| MOD
	| BCK

instance == CWC_CR
where
	(==) TXT TXT = True
	(==) CMT CMT = True
	(==) MOD MOD = True
	(==) BCK BCK = True
	(==) _ _ = False

conswinColours :: !*(PSt *a) -> *(PSt *a) | Consoler a
conswinColours ps
	# (wloc,pane,watt,ps)= conswinPane ps
	# wdef			= Dialog "Console Window..." pane watt
	# (_,ps)		= openModalDialog wloc wdef ps
	= ps
				    
conswinPane ps
	# (twi,ps)		= accPLoc getConsWinInfo ps
	# (fontNames, ps)
					= accPIO (accScreenPicture getFontNames) ps	
	// filter fixed width fonts....
//	# (fixed,ps)	= seqList (map (\f->accPIO (accScreenPicture (lisFixedWidth f))) fontNames) ps
	# (fixed,ps)	= accPIO (accScreenPicture (seqList (map lisFixedWidth fontNames))) ps
	# fontNames		= lfilter fixed fontNames
	# fontSizes		= [7, 8, 9, 10, 12, 14, 18, 24 ]
	# {conswinfont={fName=inifn,fSize=inifs},conswinsync=sync}
					= getConPrefs twi
	# win			= getConWind twi
	# (rgbid,ps)	= openRGBId  ps
 	# (wId,ps)		= openId ps
 	# (okId,ps)		= openId ps
 	# (cancelId,ps)	= openId ps
 	# (cb1id,ps)	= openId ps
 	# (cb2id,ps)	= openId ps
 	# (cb3id,ps)	= openId ps
 	# (cb4id,ps)	= openId ps
 	# (lsid,ps)		= openRId ps
	# wloc			= {fn=inifn,fs=inifs,cur = TXT,txt=sync.textColour,cmt=sync.commentColour,mod=sync.stringColour,bck=sync.backgroundColour}
	# wdef			= 	(LayoutControl 
						(	FontNameSizeControl inifn inifs fontNames fontSizes fontfun sizefun [ left ]
						:+:	RGBColourPickControl` rgbid sync.textColour cb1id (Just (Left, zero))
						) []

						:+: LayoutControl
						(	TextControl "Text:" [ left , ControlWidth (ContentWidth "Background: ")]
						:+: ColourBoxControl` (toRGBColour sync.textColour) cb1id (mfilter,mfun rgbid lsid cb1id cb2id cb3id cb4id TXT) Nothing//(Just (Left, zero))
						:+: TextControl "Modules:" [ left , ControlWidth (ContentWidth "Background: ")]
						:+: ColourBoxControl` (toRGBColour sync.stringColour) cb3id (mfilter,mfun rgbid lsid cb1id cb2id cb3id cb4id MOD) Nothing//(Just (Left, zero))
						:+: TextControl "Comments:" [ left, ControlWidth (ContentWidth "Background: ")]
						:+: ColourBoxControl` (toRGBColour sync.commentColour) cb2id (mfilter,mfun rgbid lsid cb1id cb2id cb3id cb4id CMT) Nothing//(Just (Left, zero))
						:+: TextControl "Background:" [ left, ControlWidth (ContentWidth "Background: ")]
						:+: ColourBoxControl` (toRGBColour sync.backgroundColour) cb4id (mfilter,mfun rgbid lsid cb1id cb2id cb3id cb4id BCK) Nothing//(Just (Left, zero))
						) []
						
					   	:+:	ButtonControl "Ok"
				  			[ ControlId okId
				  			, ControlFunction (okFun win rgbid lsid wId) 
				  			, ControlPos (Right, zero)
				  			, ControlWidth (ContentWidth "Cancel")
				  			]
				    	:+:	ButtonControl "Cancel"
				  			[ ControlPos (LeftOfPrev, zero) 
				  			, ControlFunction (cancelFun win wloc wId)
				  			, ControlId cancelId
				  			] 
						:+: ButtonControl "Apply"
							[ ControlPos (LeftOfPrev,zero)
							, ControlFunction (applyFun win rgbid lsid)
							]
				  		:+: ButtonControl "Paste"
				  			[ ControlPos (LeftOfPrev,zero)
				  			, ControlFunction (pasteFun rgbid cb1id cb2id cb3id cb4id)
				  			]
				  		:+: ButtonControl "Copy"
				  			[ ControlPos (LeftOfPrev,zero)
				  			, ControlFunction (copyFun rgbid)
				  			]

				  		:+: Receiver lsid lsfun []
						)
	# (dback,ps) = GetDialogBackgroundColour ps
	# watt		=		[ WindowPen		[PenBack dback]
						, WindowClose 	(cancelFun win wloc wId)
						, WindowId		wId
						, WindowOk		okId
						, WindowCancel	cancelId
						, WindowInit	(setBoxCol cb1id cb2id cb3id cb4id)
						]
	= (wloc,wdef,watt,ps)
where
	fontfun name (ls,ps)
		# ls		= {CWC_LS | ls & fn = name}
		= (ls,ps)
	sizefun size (ls,ps)
		# ls		= {CWC_LS | ls & fs = size}
		= (ls,ps)
	lsfun f (ls,ps)
		= f (ls,ps)
    left = ControlPos (Left, zero)
	mfilter (MouseDown _ _ _) = True
	mfilter _ = False
	mfun rgbid lsid cb1id cb2id cb3id cb4id act _ (ls=:{cur,txt,cmt,mod,bck},ps)
		| act == cur = (ls,ps)
		# ps = getColourBoxColour rgbid cont ps
		= (ls,ps)
	where
		cont col ps
			| isNothing col = ps
			# col = fromJust col
			# ps	= appPIO (case act of
								TXT	-> SetColourBox` cb1id (case cur of
									TXT	-> toRGBColour col
									_	-> toRGBColour txt
									)
								_	-> SetColourBox cb1id (case cur of
									TXT	-> toRGBColour col
									_	-> toRGBColour txt
									)
							) ps
			# ps	= appPIO (case act of
								CMT	-> SetColourBox` cb2id (case cur of
									CMT	-> toRGBColour col
									_	-> toRGBColour cmt
									)
								_	-> SetColourBox cb2id (case cur of
									CMT	-> toRGBColour col
									_	-> toRGBColour cmt
									)
							) ps
			# ps	= appPIO (case act of
								MOD	-> SetColourBox` cb3id (case cur of
									MOD	-> toRGBColour col
									_	-> toRGBColour mod
									)
								_	-> SetColourBox cb3id (case cur of
									MOD	-> toRGBColour col
									_	-> toRGBColour mod
									)
							) ps
			# ps	= appPIO (case act of
								BCK	-> SetColourBox` cb4id (case cur of
									BCK	-> toRGBColour col
									_	-> toRGBColour bck
									)
								_	-> SetColourBox cb4id (case cur of
									BCK	-> toRGBColour col
									_	-> toRGBColour bck
									)
							) ps
			# cId = case act of
						TXT -> cb1id
						CMT -> cb2id
						MOD -> cb3id
						BCK -> cb4id
			# col` = case act of
						TXT -> txt
						CMT -> cmt
						MOD -> mod
						BCK -> bck
			# ps	= setColourBoxId rgbid cId ps
			# ps	= setColourBoxColour` rgbid col` ps
			# (_,ps) = asyncSend lsid (cont2 col) ps
			= ps
		cont2 col (ls=:{cur},ps)
			# ls	= case cur of
						TXT -> {ls & txt = col, cur = act}
						CMT -> {ls & cmt = col, cur = act}
						MOD -> {ls & mod = col, cur = act}
						BCK -> {ls & bck = col, cur = act}
			= (ls,ps)
	toStringC :: !Colour -> String
	toStringC c = toString c
	copyFun rgbid (ls,ps)
		# ps = getColourBoxColour rgbid cont ps
		= (ls,ps)
	where
		cont col ps
			| isNothing col
				= ps
			# col = fromJust col
			# ps	= setClipboard [toClipboard (toString col)] ps
			= ps
	pasteFun rgbId cb1id cb2id cb3id cb4id (ls=:{cur},ps)
		// get clipboard
		// and put in active colour control
		# (its,ps)	= getClipboard ps
		| isEmpty its
			= (ls,ps)
		# its		= map fromClipboard its
		# its		= filter isJust its
		| isEmpty its
			= (ls,ps)
		# it		= fromJust (hd its)
		| it <> toStringC (fromString it)
			= (ls,ps)
		# col		= fromString it
		# ls		= case cur of
						TXT -> {CWC_LS | ls & txt = col}
						CMT -> {CWC_LS | ls & cmt = col}
						MOD -> {CWC_LS | ls & mod = col}
						BCK -> {CWC_LS | ls & bck = col}
		# (ls,ps)	= setBoxCol cb1id cb2id cb3id cb4id (ls,ps)
		# ps		= setColourBoxColour` rgbId col ps
		= (ls,ps)
	applyFun win rgbid lsid (ls=:{cur},ps)
		# ps = getColourBoxColour rgbid cont ps
		= (ls,ps)
	where
		cont col ps
			| isNothing col
				= ps
			# col = fromJust col
			# (_,ps) = asyncSend lsid (cont2 col) ps
			= ps
		cont2 col (ls,ps)
			# ls = case cur of
						TXT	-> {CWC_LS | ls & txt = col}
						CMT	-> {CWC_LS | ls & cmt = col}
						MOD	-> {CWC_LS | ls & mod = col}
						BCK	-> {CWC_LS | ls & bck = col}
			= updateCW win (ls,ps)
	okFun win rgbid lsid dialogId (ls=:{cur},ps)
		# ps = getColourBoxColour rgbid cont ps
		= (ls,ps)
	where
		cont col ps
			| isNothing col
				= ps
			# col = fromJust col
			# (_,ps) = asyncSend lsid (cont2 col) ps
			= ps
		cont2 col (ls,ps)
			# ls = case cur of
						TXT	-> {CWC_LS | ls & txt = col}
						CMT	-> {CWC_LS | ls & cmt = col}
						MOD	-> {CWC_LS | ls & mod = col}
						BCK	-> {CWC_LS | ls & bck = col}
			= updateCW win (ls,closeWindow dialogId ps)
	cancelFun win wini dialogId (ls,ps)
		= updateCW win (wini,closeWindow dialogId ps)
	setBoxCol cb1id cb2id cb3id cb4id (ls=:{cur,txt,cmt,mod,bck},ps)
		# (cId,col) = case cur of
						TXT	-> (cb1id,txt)
						CMT	-> (cb2id,cmt)
						MOD	-> (cb3id,mod)
						BCK	-> (cb4id,bck)
		# ps = appPIO (SetColourBox` cId (toRGBColour col)) ps
		= (ls,ps)
	updateCW win (ls=:{txt,cmt,mod,bck,fn,fs},ps)
		# (twi,ps)		= accPLoc getConsWinInfo ps
		# sync			= getConSync twi
		# sync			= sc_update sync
		# (font,ps)		= safeOpenFont {fName = fn, fSize = fs, fStyles = []} ps
		# twi			= setConSync sync twi
		# twi			= setConFont font twi
		# ps			= appPLoc (setConsWinInfo twi) ps
		# (_,ps)		= maybe_cons_win_message2 (appFontInfo fi_update) ps
		# (_,ps)		= maybe_cons_win_message2 (setFont font) ps
		# ps			= appPIO (updateWindow win Nothing) ps
		= (ls,ps)
	where	
		fi_update fi =
			{ fi
			& syntaxColours = sc_update fi.syntaxColours
			}
		
		sc_update sc =
			{ sc
			& textColour		= txt
			, commentColour		= cmt
			, stringColour		= mod
			, backgroundColour	= bck
			}
