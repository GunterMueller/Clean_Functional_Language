implementation module typewin

import StdClass, StdInt, StdList, StdFunc,StdMisc
import StdPSt, StdWindow, StdControlReceiver, StdMenuElement
import EdLook, EdMessage, EdVisualText, EdWindow
import EdMouse, EdKeyboard

from StrictList import slFromList
from UtilStrictLists import StrictListToList,:: List,:!,IsEmptyList

import IDE,IdeState,UtilObjectIO
import morecontrols, colorpickcontrol, ioutil, colourclip
import StdClipboard

//--

isTypeWindow :: !Id !.TypeWinInfo -> Bool
isTypeWindow xId {TypeWinInfo | wId}
	= xId==wId

//--

:: TypeWinInfo =
	{ wId	:: !Id		// id of the types window
	, eId	:: !EditId	// receiver id
	, uId	:: !Id		// id of undo menu item
	, ids	:: ![Id]	// ids to disable when typewin is active
	, tfnt	:: !Font	// window font
	, tpos	:: !Vector2	// window pos
	, tsiz	:: !Size	// window size
	, sync	:: !SyntaxColours
	}

TW_GetInf :: !TypeWinInfo -> TypPrefs
TW_GetInf {tfnt,tpos,tsiz,sync} =
	{ typewinfont	= getFontDef tfnt
	, typewinpos	= tpos
	, typewinsiz	= tsiz
	, typewinsync	= sync
	}

TW_SetFnt :: !Font !TypeWinInfo -> TypeWinInfo
TW_SetFnt fnt twi = {twi & tfnt = fnt}

TW_GetSync :: !TypeWinInfo -> SyntaxColours
TW_GetSync {sync} = sync

TW_SetSync :: !SyntaxColours !TypeWinInfo -> TypeWinInfo
TW_SetSync sync twi = {twi & sync = sync}

TW_GetWind :: !TypeWinInfo -> Id
TW_GetWind {TypeWinInfo | wId} = wId

TW_SetUpd :: ![Id] !TypeWinInfo -> TypeWinInfo
TW_SetUpd ids twi = {twi & ids = ids}

class Typer env
where
	getTypeWinInfo :: !*env -> *(!TypeWinInfo, !*env)
	setTypeWinInfo :: !TypeWinInfo !*env -> *env

getTypeWinInf :: *(PSt *b) -> *(TypeWinInfo,*PSt *b) | Typer b
getTypeWinInf ps = accPLoc getTypeWinInfo ps

setTypeWinInf :: .TypeWinInfo *(PSt *b) -> *PSt *b | Typer b
setTypeWinInf twi ps = appPLoc (setTypeWinInfo twi) ps

//--- Types window

iniTypeWinInfo :: !Id !Id ![Id] !TypPrefs !*a -> *(.TypeWinInfo,*a) | Ids, accScreenPicture a
iniTypeWinInfo mId uId ids tprefs env
	# ((ok,twFont),env)	= accScreenPicture (openFont tprefs.typewinfont) env
	| not ok = abort "Unable to open font for Types window"
	# (wId,env) = openId env
	# (eId,env) = openEditId env
	= (	{wId	= wId
		,eId	= eId
		,uId	= uId
		,ids	= ids
		,tfnt	= twFont
		,tpos	= tprefs.typewinpos
		,tsiz	= tprefs.typewinsiz
		,sync	= tprefs.typewinsync
		},env)

//--

updateTypeWindow :: !Bool !String [WindowAttribute *(EditState,*(PSt *b))] ![String] !*(PSt *b) -> *PSt *b | Typer b
updateTypeWindow interact name atts message ps	// fun to update type info in type window, text :: !Text
	| not interact || isEmpty message
		= ps
	# message								= [quoteString name : message]
	# (twi=:{TypeWinInfo | wId,eId},ps)		= getTypeWinInf ps
	# (iswin,ps)							= isWindow wId ps
	# textfrag								= slFromList message
	| iswin
		// only update
		#! (_,ps)							= type_message eId (vAppendLines textfrag) ps
		= ps
	// open & update
	# text									= emptyText
	# ps									= openTypeWindow twi text atts ps
	#! (_,ps)								= type_message eId (vAppendLines textfrag) ps
	= ps
where
	quoteString s = "\""+++s+++"\""

maybe_type_win_message :: !Id .(EditMonad *(PSt *b) .c) !*(PSt *b) -> (Maybe .c,*(PSt *b)) | Typer b
maybe_type_win_message id message ps
	# (twi=:{TypeWinInfo | wId,eId},ps)	=  getTypeWinInf ps
	| id == wId = type_message eId message ps
	= (Nothing,ps)

maybe_type_win_message2 :: .(EditMonad *(PSt *b) .c) !*(PSt *b) -> (Maybe .c,*(PSt *b)) | Typer b
maybe_type_win_message2 message ps
	# (twi=:{eId},ps)	=  getTypeWinInf ps
	# (has,ps) = hasEditState eId ps
	| has
		= type_message eId message ps
	= (Nothing,ps)

type_win_message :: !.(EditMonad *(PSt *b) .c) !*(PSt *b) -> *(Maybe .c,*(PSt *b)) | Typer b
type_win_message message ps
	# (twi=:{eId},ps)	=  getTypeWinInf ps
	= type_message eId message ps

type_message :: !EditId !.(EditMonad *(PSt *b) .c) !*(PSt *b) -> *(Maybe .c,*(PSt *b))
type_message editId monad pState
	# (x,pState) = appEditState editId monad pState
	= (Just x,pState)

//---

openTypeWindow twi text atts ps
	# editId						= twi.eId
	# windowId						= twi.TypeWinInfo.wId
	# pathName						= "" 					// dummy pathName
	# title							= "Types"
	# tabs							= (4,True,False,False,True)
	# (editState, ps)				= initEditState windowId twi.uId pathName twi.tfnt tabs 0 twi.sync ps
	# (_, (editState, ps))			= setText text (editState, ps)
	# (fontInfo, (editState, ps))	= getFontInfo (editState, ps) 
	# (viewDomain, (editState, ps))	= computeViewDomain (editState, ps)
	# editLook						= editWindowLook editState
	# windowAttrs 
	  = [ WindowOuterSize  	twi.tsiz
		, WindowHMargin	  	0 0
		, WindowVMargin	  	0 0
		, WindowId		  	windowId
		, WindowViewDomain	viewDomain
		, WindowLook		True editLook
		, WindowHScroll		(altScrollFunction Horizontal fontInfo.metrics.fMaxWidth)
		, WindowVScroll		(alignScrollFunction Vertical fontInfo.FontInfo.lineHeight)
		, WindowPos			(Fix, OffsetVector twi.tpos)
		, WindowClose		(noLS (tw_close o tw_deactivate))	// be more careful if editable...
		, WindowActivate	(noLS (tw_activate))
		, WindowDeactivate 	(noLS (tw_deactivate))
		: atts
		]
	# receiver	  					= openEditReceiver editId
	# window						= Window title receiver windowAttrs
	# (_, ps)	 					= openWindow editState window ps
	= ps

//--

tw_maybe_close :: !Id !*(PSt *b) -> *(Bool,*(PSt *b)) | Typer b
tw_maybe_close win ps
	# (twi,ps)	= getTypeWinInf ps
	| isTypeWindow win twi
		# ps	= tw_deactivate ps
		# ps	= tw_close ps
		= (True,ps)
	= (False,ps)

tw_safe_close :: !*(PSt *b) -> *PSt *b | Typer b
tw_safe_close ps
	# (win,ps)	= accPIO getActiveWindow ps
	| isNothing win
		= tw_close ps
	# win = fromJust win
	# (twi,ps)	= getTypeWinInf ps
	| isTypeWindow win twi
		# ps	= tw_deactivate ps
		= tw_close ps
	= tw_close ps

tw_close :: !*(PSt *b) -> *PSt *b | Typer b
tw_close ps
	# (twi=:{TypeWinInfo | wId},ps)	= getTypeWinInf ps
	# (mpos,ps) = accPIO (getWindowPos wId) ps
	| isNothing mpos
		= ps
	# tpos		= fromJust mpos
	# (tsiz,ps) = accPIO (getWindowOuterSize wId) ps
	# twi		= {twi & tpos = tpos, tsiz = tsiz}
	# ps		= setTypeWinInf twi ps
	# ps		= closeWindow wId ps
	= ps

tw_activate ps
	# (twi,ps=:{io})	= getTypeWinInf ps
	# io = disableMenuElements twi.ids io
	= {ps & io = io}
tw_deactivate ps
	# (twi,ps=:{io})	= getTypeWinInf ps
	# io = enableMenuElements twi.ids io
	= {ps & io = io}

//-- type win options...

::TWC_LS =
	{ cur	:: TWC_CR	// current colour
	, txt	:: Colour
	, cmt	:: Colour
	, mod	:: Colour
	, bck	:: Colour
	, fn	:: String	// font name
	, fs	:: Int		// font size
	}

::TWC_CR
	= TXT
	| CMT
	| MOD
	| BCK

instance == TWC_CR
where
	(==) TXT TXT = True
	(==) CMT CMT = True
	(==) MOD MOD = True
	(==) BCK BCK = True
	(==) _ _ = False

typewinColours :: !*(PSt *a) -> *(PSt *a) | Typer a
typewinColours ps
	# (wloc,pane,watt,ps)= typewinPane ps
	# wdef			= Dialog "Types Window..." pane watt
	# (_,ps)		= openModalDialog wloc wdef ps
	= ps
				    
typewinPane ps
	# (twi,ps)		= accPLoc getTypeWinInfo ps
	# (fontNames, ps)
					= accPIO (accScreenPicture getFontNames) ps
//	# (fixed,ps)	= seqList (map (\f->accPIO (accScreenPicture (lisFixedWidth f))) fontNames) ps
	# (fixed,ps)	= accPIO (accScreenPicture (seqList (map lisFixedWidth fontNames))) ps
	# fontNames		= lfilter fixed fontNames
	# fontSizes		= [7, 8, 9, 10, 12, 14, 18, 24 ]
	# {typewinfont={fName=inifn,fSize=inifs},typewinsync=sync}
					= TW_GetInf twi
	# win			= TW_GetWind twi
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
		# ls		= {TWC_LS | ls & fn = name}
		= (ls,ps)
	sizefun size (ls,ps)
		# ls		= {TWC_LS | ls & fs = size}
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
						TXT -> {TWC_LS | ls & txt = col}
						CMT -> {TWC_LS | ls & cmt = col}
						MOD -> {TWC_LS | ls & mod = col}
						BCK -> {TWC_LS | ls & bck = col}
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
						TXT	-> {TWC_LS | ls & txt = col}
						CMT	-> {TWC_LS | ls & cmt = col}
						MOD	-> {TWC_LS | ls & mod = col}
						BCK	-> {TWC_LS | ls & bck = col}
			= updateTW win (ls,ps)
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
						TXT	-> {TWC_LS | ls & txt = col}
						CMT	-> {TWC_LS | ls & cmt = col}
						MOD	-> {TWC_LS | ls & mod = col}
						BCK	-> {TWC_LS | ls & bck = col}
			= updateTW win (ls,closeWindow dialogId ps)
	cancelFun win wini dialogId (ls,ps)
		= updateTW win (wini,closeWindow dialogId ps)
	setBoxCol cb1id cb2id cb3id cb4id (ls=:{cur,txt,cmt,mod,bck},ps)
		# (cId,col) = case cur of
						TXT	-> (cb1id,txt)
						CMT	-> (cb2id,cmt)
						MOD	-> (cb3id,mod)
						BCK	-> (cb4id,bck)
		# ps = appPIO (SetColourBox` cId (toRGBColour col)) ps
		= (ls,ps)
	updateTW win (ls=:{fn,fs,txt,cmt,mod,bck},ps)
		# (twi,ps)		= accPLoc getTypeWinInfo ps
		# sync			= TW_GetSync twi
		# sync			= sc_update sync
		# (font,ps)		= safeOpenFont {fName = fn, fSize = fs, fStyles = []} ps
		# twi			= TW_SetSync sync twi
		# twi			= TW_SetFnt font twi
		# ps			= appPLoc (setTypeWinInfo twi) ps
		# (_,ps)		= maybe_type_win_message2 (appFontInfo fi_update) ps
		# (_,ps)		= maybe_type_win_message2 (setFont font) ps
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
			, typedeclColour	= txt
			, commentColour		= cmt
			, stringColour		= mod
			, backgroundColour	= bck
			}
