implementation module errwin

import StdBool, StdFunc, StdMisc, StdChar, StdArray
import StdPSt, StdWindow, StdControlClass, StdControlReceiver, StdMenuElement
import StdClipboard, colourclip, StdPathname
import FilteredListBox

import morecontrols, colorpickcontrol, ioutil

from	IDE			import OpenModule
from	IdeState	import :: General, getErrInfo, setErrInfo, :: ErrorInfo, :: MenuIds, getMenuIds, :: ErrPrefs
from	IdeState	import :: SearchMenuIds, :: PLMMessage, :: PLMReply, :: MIn, :: EditMenuLS, getInteract, writeLog
from	EdClient	import lineSelection
import EdClient
import UtilObjectIO

/*
ADD:
- error type selection...
- sort by error type...
- find...
- copy...

Means we should really build a custom window for this...
*/

sr_find_err :: !Bool !*(PSt *General) -> *PSt *General
sr_find_err forward ps
	# (errinfo,ps)	= getErrInfo ps
	= exec_next_filtered forward errinfo.infoId fifi ps
where
	fifi errmsg ps
		| not_empty = OpenModule path (lineSelection (inc lnr)) ps
		= ps
	where
		(path,lnr)	= ParseErrorMsg errmsg
		not_empty	= path <> EmptyPathname

//--- Error window handling

countnums [message:messages] (e,w,i)
	| IsErrorMsg message
		= countnums (dropWhile first_char_is_space messages) (inc e,w,i)
	| IsWarningMsg message
		= countnums messages (e,inc w,i)
		= countnums messages (e,w,inc i)
countnums [] nums
	= nums

checkWindowExistence id io
	# (st,io)	= getWindowsStack io
	= (isMember id st,io)

updateErrorWindow :: !([String]) !*(PSt *General) -> *PSt *General;
updateErrorWindow messages ps
	# (interact, ps) = getInteract ps
	| not interact
		=	seq (map writeLog messages) ps
	// interact
		=	updateErrorWindowInteractive messages ps

updateErrorWindowInteractive :: !([String]) !*(PSt *General) -> *PSt *General;
updateErrorWindowInteractive [] ps = ps	// or should we always show it?
updateErrorWindowInteractive messages ps
	#! (errinfo,ps)	= getErrInfo ps
	#! (isOpen,ps)	= accPIO (checkWindowExistence errinfo.errorId) ps
	#! ps			= case isOpen of
						True	-> ps
						_		-> err_open errinfo ps
	#! ps			= appendFilteredListBoxItems errinfo.infoId messages ps
	#! (numerr,numwrn,numinf)
					= countnums messages (errinfo.err_count,errinfo.wrn_count,errinfo.inf_count)
	# err			= (errinfo.err_countId,toString numerr)
	# wrn			= (errinfo.wrn_countId,toString numwrn)
	# inf			= (errinfo.inf_countId,toString numinf)
	#! cts			= case (numerr==errinfo.err_count,numwrn==errinfo.wrn_count,numinf==errinfo.inf_count) of
						(False,False,False)	-> [err,wrn,inf]
						(False,False,True)	-> [err,wrn]
						(False,True,False)	-> [err,inf]
						(False,True,True)	-> [err]
						(True,False,False)	-> [wrn,inf]
						(True,False,True)	-> [wrn]
						(True,True,False)	-> [inf]
						(True,True,True)	-> []
	#! ps			= appPIO (setControlTexts cts) ps
	#! errinfo		= {errinfo & err_count = numerr, wrn_count = numwrn, inf_count = numinf}
	#! ps			= setErrInfo errinfo ps
	= ps

err_open :: !(ErrorInfo (PSt *General)) !*(PSt *General) -> *PSt *General
err_open errinfo ps
	#! (menuIds=:{searchIds},ps)	= getMenuIds ps
	#! (inf_size,ps)				= controlSize (infobar errinfo) True Nothing Nothing Nothing ps
	# (elb)							= FilteredListBoxControl [] [] errinfo.infoId
					[ ControlOuterSize errinfo.err_size
					, ControlResize (err_resize inf_size.Size.h)
					, ControlPen
						[ PenColour errinfo.err_forg
						, PenBack errinfo.err_back
						, PenFont errinfo.err_font
						]
					, ControlPos (Fix,OffsetVector {zero & vy = inf_size.Size.h})
					, (flbMouse fifi)
					, (flbKeyboard fifi)
					]
	#! (win_size,ps)				= controlSize elb True Nothing Nothing Nothing ps
	# (dback,ps) = GetDialogBackgroundColour ps
	#! wdef							= Window "Errors & Warnings"
					( infobar errinfo :+: elb
					)
					[ WindowId errinfo.errorId
					, WindowClose (noLS(err_close` o ew_deactivate))
					, WindowPos (LeftTop,OffsetVector errinfo.err_offset)
					, WindowViewSize win_size
					, WindowInitActive errinfo.infoId.fcontrolId
					, WindowPen [PenBack dback]
					, WindowActivate (noLS (ew_activate errinfo.infoId.fcontrolId))
					, WindowDeactivate (noLS ew_deactivate)
					]
	#! ldef							= (errinfo.err,errinfo.wrn,errinfo.inf)
	#! (err,ps)						= openWindow ldef wdef ps
	| err == NoError
		# ps = appPIO (enableMenuElements [searchIds.nextIds!!1]) ps
		= setFilter errinfo.infoId (makeFilter errinfo.err errinfo.wrn errinfo.inf) ps
	= ps
where
	fifi errmsg ps
		| not_empty = OpenModule path (lineSelection (inc lnr)) ps
		= ps
	where
		(path,lnr)	= ParseErrorMsg errmsg
		not_empty	= path <> EmptyPathname

	infobar {err,err_buttonId,err_count,err_countId,wrn,wrn_buttonId,wrn_count,wrn_countId,inf,inf_buttonId,inf_count,inf_countId}
		= LayoutControl
			(	errButton err err_buttonId
			:+: errCount err_count err_countId
			:+: wrnButton wrn wrn_buttonId
			:+: wrnCount wrn_count wrn_countId
			:+: infButton inf inf_buttonId
			:+: infCount inf_count inf_countId
			)
			[ ControlResize inf_resize
			, ControlPos (Fix,zero)
			]
	wrnButton button buttonId
		= CheckControl [("Warnings:",Nothing,toMark button,wrnFun)] (Rows 1)
			[ControlId buttonId
			]
	wrnCount count countId
//		= EditControl (toString count) (ContentWidth "8888") 1
//			[ ControlSelectState Unable
		= TextControl (toString count)
			[ ControlWidth (ContentWidth "8888")
			, ControlId countId
			]
	errButton button buttonId
		= CheckControl [("Errors:",Nothing,toMark button,errFun)] (Rows 1)
			[ControlId buttonId
			]
	errCount count countId
//		= EditControl (toString count) (ContentWidth "8888") 1
//			[ ControlSelectState Unable
		= TextControl (toString count)
			[ ControlWidth (ContentWidth "8888")
			, ControlId countId
			]
	infButton button buttonId
		= CheckControl [("Info:",Nothing,toMark button,infFun)] (Rows 1)
			[ControlId buttonId
			]
	infCount count countId
//		= EditControl (toString count) (ContentWidth "8888") 1
//			[ ControlSelectState Unable
		= TextControl (toString count)
			[ ControlWidth (ContentWidth "8888")
			, ControlId countId
			]
	wrnFun ((err,wrn,inf),ps)
		# wrn = not wrn
		# (ei,ps) = getErrInfo ps
		# ps = setErrInfo {ei & wrn = wrn} ps
		# ps = setFilter ei.infoId (makeFilter err wrn inf) ps
		= ((err,wrn,inf),ps)
	errFun ((err,wrn,inf),ps)
		# err = not err
		# (ei,ps) = getErrInfo ps
		# ps = setErrInfo {ei & err = err} ps
		# ps = setFilter ei.infoId (makeFilter err wrn inf) ps
		= ((err,wrn,inf),ps)
	infFun ((err,wrn,inf),ps)
		# inf = not inf
		# (ei,ps) = getErrInfo ps
		# ps = setErrInfo {ei & inf = inf} ps
		# ps = setFilter ei.infoId (makeFilter err wrn inf) ps
		= ((err,wrn,inf),ps)

	makeFilter err wrn inf [str:strings]
		| IsErrorMsg str
			| err
				# (error_strings,strings) = span first_char_is_space strings
				= [str:error_strings++makeFilter err wrn inf strings]
				= makeFilter err wrn inf (dropWhile first_char_is_space strings)
		| IsWarningMsg str
			| wrn
				= [str:makeFilter err wrn inf strings]
				= makeFilter err wrn inf strings
			| inf
				= [str:makeFilter err wrn inf strings]
				= makeFilter err wrn inf strings
	makeFilter err wrn inf []
		= []

	err_resize ih oc ow nw
		= {w = nw.w, h = nw.Size.h - ih}
	inf_resize oc ow nw
		= {oc & w = nw.w}

first_char_is_space s = size s>0 && s.[0]==' '

ew_activate cId ps
	# ({mn_cut,mn_cpy,mn_pst,mn_clr,mg_edt,searchIds},ps=:{io})
			= getMenuIds ps
	// disable Edit menu stuff
	# io = disableMenuElements [mn_cut/*,mn_cpy*/,mn_pst,mn_clr:mg_edt] io
	// disable Search menu stuff
	# io = disableMenuElements searchIds.findIds io
	# io = disableMenuElements searchIds.gotoIds io
	# ps = {ps & io = io}
//	# ps = setActiveControl cId ps
	= ps

ew_deactivate ps
	# ({mn_cut,mn_cpy,mn_pst,mn_clr,mg_edt,searchIds},ps=:{io})
			= getMenuIds ps
	// enable Edit menu stuff
	# io = enableMenuElements [mn_cut/*,mn_cpy*/,mn_pst,mn_clr:mg_edt] io
	// enable Search menu stuff
	# io = enableMenuElements searchIds.findIds io
	# io = enableMenuElements searchIds.gotoIds io
	= {ps & io = io}

err_close` ps
	# (errinf,ps)		= getErrInfo ps
	= err_close errinf ps

err_close :: !(ErrorInfo (PSt *General)) !*(PSt *General) -> *PSt *General
err_close errinf ps
	# (errinf,ps)		= err_close_info errinf ps
	# ({searchIds},ps)	= getMenuIds ps
	# ps				= appPIO (disableMenuElements [searchIds.nextIds!!1]) ps
	= setErrInfo errinf ps

ew_is_active :: !*(PSt *General) -> (!Bool,!*PSt *General)
ew_is_active ps
	# (win,ps)		= accPIO getActiveWindow ps
	# (errInf,ps)	= getErrInfo ps
	| isNothing win
		= (False,ps)
	# win			= fromJust win
	| win == errInf.errorId
		= (True,ps)
	= (False,ps)

ew_safe_close			:: !*(PSt *General) -> *PSt *General
ew_safe_close ps
	# (win,ps)		= accPIO getActiveWindow ps
	# (errInf,ps)	= getErrInfo ps
	| isNothing win
		= err_close errInf ps
	# win			= fromJust win
	| win == errInf.errorId
		# ps		= ew_deactivate ps
		= err_close errInf ps
	= err_close errInf ps

ew_maybe_close :: !Id !*(PSt *General) -> (Bool,*PSt *General)
ew_maybe_close win ps
	# (errInf,ps) = getErrInfo ps
	| win == errInf.errorId
		# ps				= ew_deactivate ps
		# ps = err_close errInf ps
		= (True,ps)
	= (False,ps)

err_close_info :: (ErrorInfo .a) *(PSt .b) -> ((ErrorInfo .a),*PSt .b)
err_close_info errinfo ps
	# (err_pos,ps)		= accPIO (getWindowPos errinfo.errorId) ps
	# (wdef,ps)			= accPIO (getWindow errinfo.errorId) ps
	# wdef				= fromJust wdef
	# (ok,err_siz)		= getControlOuterSize errinfo.infoId.fcontrolId wdef
	# errinfo			= if (isNothing err_pos || not ok) errinfo {errinfo & err_offset = fromJust err_pos, err_size = err_siz}
	# errinfo			= {errinfo & err_count = 0, wrn_count = 0, inf_count = 0}
	# ps				= closeWindow errinfo.errorId ps
	= (errinfo,ps)

// error window options

:: EWO =
	{ fn	:: !String		// font name
	, fs	:: !Int			// font size
	, fc	:: !Colour		// foreground colour
	, bc	:: !Colour		// background colour
	, cur	:: !EWO_LS
	}

:: EWO_LS = TXT | BCK

instance == EWO_LS
where
	(==) TXT TXT = True
	(==) BCK BCK = True
	(==) _ _ = False


err_options :: !*(PSt *General) -> *PSt *General;
err_options ps
    # (dialogId,ps)	= openId ps
    # (okId,ps)		= openId ps
    # (cancelId,ps)	= openId ps
	# (fcid,ps)		= openId  ps
	# (bcid,ps)		= openId  ps
	# (rgbid,ps)	= openRGBId ps
	# (fontNames, ps) = accPIO (accScreenPicture getFontNames) ps
	// no fixed width filtering for error-window...!
	# fontSizes		= [7,8,9,10,11,12]
	# (errinf,ps)	= getErrInfo ps
	# font			= errinf.err_font
	# fdef			= getFontDef font
	# inifn			= fdef.fName
	# inifs			= fdef.fSize
	# inifc			= errinf.err_forg
	# inibc			= errinf.err_back
	# (lsid,ps)		= openRId ps
	# inistate		= {fn = inifn, fs = inifs, fc = inifc, bc = inibc, cur = TXT}
    # controls		=
    	(LayoutControl 
		(	FontNameSizeControl inifn inifs fontNames fontSizes fontfun sizefun [ left ]
		:+:	RGBColourPickControl` rgbid inifc fcid (Just (Left, zero))
		) []

		:+: LayoutControl
		(	TextControl "Text:" [ left , ControlWidth (ContentWidth "Background: ")]
		:+: ColourBoxControl` (toRGBColour inifc) fcid (mfilter,mfun rgbid lsid fcid bcid TXT) Nothing
		:+: TextControl "Background:" [ left, ControlWidth (ContentWidth "Background: ")]
		:+: ColourBoxControl` (toRGBColour inibc) bcid (mfilter,mfun rgbid lsid fcid bcid BCK) Nothing
		) []
		
	   	:+:	ButtonControl "Ok"
  			[ ControlId okId
  			, ControlFunction (okFun rgbid lsid dialogId) 
  			, ControlPos (Right, zero)
  			, ControlWidth (ContentWidth "Cancel")
  			]
    	:+:	ButtonControl "Cancel"
  			[ ControlPos (LeftOfPrev, zero) 
  			, ControlFunction (cancelFun inistate dialogId)
  			, ControlId cancelId
  			] 
		:+: ButtonControl "Apply"
			[ ControlPos (LeftOfPrev,zero)
			, ControlFunction (applyFun rgbid lsid)
			]
  		:+: ButtonControl "Paste"
  			[ ControlPos (LeftOfPrev,zero)
  			, ControlFunction (pasteFun rgbid fcid bcid)
  			]
  		:+: ButtonControl "Copy"
  			[ ControlPos (LeftOfPrev,zero)
  			, ControlFunction (copyFun rgbid)
  			]

  		:+: Receiver lsid lsfun []
		)
	# dialog		=
		Dialog "Error Window..." controls 
  		[ WindowId		dialogId 
  		, WindowOk		okId
  		, WindowCancel	cancelId
  		, WindowClose	(cancelFun inistate dialogId)
		, WindowInit	(setBoxCol fcid bcid)
  		]
	# (_,ps) = openModalDialog inistate dialog ps
	= ps
where
	lsfun f (ls,ps)
		= f (ls,ps)
	okFun rgbid lsid dialogId (ls,ps)
		# ps = getColourBoxColour rgbid cont ps
		= (ls,ps)
	where
		cont col ps
			| isNothing col
				= ps
			# col = fromJust col
			# (_,ps) = asyncSend lsid (cont2 col) ps
			= ps
		cont2 col (ls=:{cur},ps)
			# ls	= case cur of
						TXT -> {ls & fc = col}
						BCK -> {ls & bc = col}
			# (ls,ps)= apply (ls,ps)
			= (ls,closeWindow dialogId ps)
	cancelFun inistate dialogId (ls,ps)
		# ls		= inistate
		# (ls,ps)	= apply (ls,ps)
		= (ls,closeWindow dialogId ps)
	applyFun rgbid lsid (ls,ps)
		# ps = getColourBoxColour rgbid cont ps
		= (ls,ps)
	where
		cont col ps
			| isNothing col
				= ps
			# col = fromJust col
			# (_,ps) = asyncSend lsid (cont2 col) ps
			= ps
		cont2 col (ls=:{cur},ps)
			# ls	= case cur of
						TXT -> {ls & fc = col}
						BCK -> {ls & bc = col}
			= apply (ls,ps)
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
	pasteFun rgbId fcid bcid (ls=:{cur},ps)
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
						TXT -> {ls & fc = col}
						BCK -> {ls & bc = col}
		# (ls,ps)	= setBoxCol fcid bcid (ls,ps)
		# ps		= setColourBoxColour` rgbId col ps
		= (ls,ps)
	setBoxCol fcid bcid (ls=:{cur,fc,bc},ps)
		# (cId,col) = case cur of
						TXT	-> (fcid,fc)
						BCK	-> (bcid,bc)
		# ps = appPIO (SetColourBox` cId (toRGBColour col)) ps
		= (ls,ps)
	mfilter (MouseDown _ _ _) = True
	mfilter _ = False
	mfun rgbid lsid fcid bcid act _ (ls=:{cur,fc,bc},ps)
		| act == cur = (ls,ps)
		# ps = getColourBoxColour rgbid cont ps
		= (ls,ps)
	where
		cont col ps
			| isNothing col = ps
			# col = fromJust col
			# ps	= appPIO (case act of
								TXT	-> SetColourBox` fcid (case cur of
									TXT	-> toRGBColour col
									_	-> toRGBColour fc
									)
								_	-> SetColourBox fcid (case cur of
									TXT	-> toRGBColour col
									_	-> toRGBColour fc
									)
							) ps
			# ps	= appPIO (case act of
								BCK	-> SetColourBox` bcid (case cur of
									BCK	-> toRGBColour col
									_	-> toRGBColour bc
									)
								_	-> SetColourBox bcid (case cur of
									BCK	-> toRGBColour col
									_	-> toRGBColour bc
									)
							) ps
			# cId = case act of
						TXT -> fcid
						BCK -> bcid
			# col` = case act of
						TXT -> fc
						BCK -> bc
			# ps	= setColourBoxId rgbid cId ps
			# ps	= setColourBoxColour` rgbid col` ps
			# (_,ps) = asyncSend lsid (cont2 col) ps
			= ps
		cont2 col (ls=:{cur},ps)
			# ls	= case cur of
						TXT -> {ls & fc = col, cur = act}
						BCK -> {ls & bc = col, cur = act}
			= (ls,ps)
	apply (ls=:{fc,bc,fn,fs},ps)
		# (errinf,ps)	= getErrInfo ps
		# lbId			= errinf.infoId
		# (fnt,ps)	= accScreenPicture (safeOpenFixedFont {fName = fn, fSize = fs, fStyles = []}) ps
		# pen		= [PenFont fnt, PenColour fc, PenBack bc] 
		# ps		= setFilteredListBoxPen lbId pen ps
		# errinf	= {errinf & err_font = fnt, err_forg = fc, err_back = bc}
		# ps		= setErrInfo errinf ps
		= (ls,ps)
    left = ControlPos (Left, zero)
	fontfun name (ls,ps)
		# ls		= {EWO | ls & fn = name}
		= (ls,ps)
	sizefun size (ls,ps)
		# ls		= {EWO | ls & fs = size}
		= (ls,ps)


err_init :: !ErrPrefs *World -> *(.ErrorInfo .c,*World)
err_init {err_pos, err_siz, err_forc, err_bacc, err_fname, err_fsize, err_err, err_wrn, err_inf} w
	# (errorId,w)	= openId w
	# (infoId,w)	= openFilteredListBoxId w
	# (ebId,w) = openId w
	# (ecId,w) = openId w
	# (wbId,w) = openId w
	# (wcId,w) = openId w
	# (ibId,w) = openId w
	# (icId,w) = openId w
	# fdef			= {fName = err_fname, fSize = err_fsize, fStyles = []}
	# (efnt,w) = accScreenPicture (safeOpenFixedFont fdef) w
	# errinfo		=
		{ errorId		= errorId
		, infoId		= infoId
		, err_offset	= err_pos
		, err_font		= efnt			// now start using font in ExtListBox
		, err_size		= err_siz
		, err_forg		= err_forc
		, err_back		= err_bacc
		, err_buttonId	= ebId
		, err_countId	= ecId
		, err_count		= 0
		, err			= err_err
		, wrn_buttonId	= wbId
		, wrn_countId	= wcId
		, wrn_count		= 0
		, wrn			= err_wrn
		, inf_buttonId	= ibId
		, inf_countId	= icId
		, inf_count		= 0
		, inf			= err_inf
		}
	= (errinfo,w)

err_shut :: !(ErrorInfo .a) -> ErrPrefs
err_shut info
	# fdef					= getFontDef info.err_font
	# prefs					=
						 		{ err_pos		= info.err_offset
						 		, err_siz		= info.err_size
						 		, err_fname		= fdef.fName
						 		, err_fsize		= fdef.fSize
						 		, err_forc		= info.err_forg
						 		, err_bacc		= info.err_back
						 		, err_err		= info.err
						 		, err_wrn		= info.wrn
						 		, err_inf		= info.inf
						 		}
	= prefs

IsErrorMsg	:: !String -> Bool
IsErrorMsg msg = type
where
	msglen	= size msg
	type
		| msglen > 5 && msg%(0,4)	== "Error"				= True
		| msglen > 12 && msg%(0,11)	== "Syntax error"		= True
		| msglen > 11 && msg%(0,10)	== "Parse error"		= True
		| msglen > 11 && msg%(0,10)	== "Check error"		= True
		| msglen > 11 && msg%(0,10)	== "Check Error"		= True
		| msglen > 10 && msg%(0,9)	== "Type error"			= True
		| msglen > 10 && msg%(0,9)	== "Link error"			= True
		| msglen > 12 && msg%(0,11)	== "Linker error"		= True
		| msglen > 16 && msg%(0,15)	== "Uniqueness error"	= True
		| msglen > 16 && msg%(0,15)	== "Undefined symbol"	= True
		| msglen > 17 && msg%(0,16)	== "Overloading error"	= True
															= False
IsWarningMsg	:: !String -> Bool
IsWarningMsg msg = type
where
	msglen	= size msg
	type
		| msglen > 7 && msg%(0,6)	== "Warning"			= True
		| msglen > 12 && msg%(0,11)	== "Type warning"		= True
		| msglen > 13 && msg%(0,12)	== "Parse warning"		= True
		| msglen > 12 && msg%(0,11)	== "Link warning"		= True
		| msglen > 14 && msg%(0,13)	== "Linker warning"		= True
															= False
//
// Extract module name and line number from error message.
//
											
ParseErrorMsg	:: !String -> (!Modulename, !Int);
ParseErrorMsg msg
	|	open < msglen	&& comma1 < msglen	&& comma2 < msglen	=  (path, linenr2);
	|	open < msglen	&& comma1 < msglen	&& close1 < msglen	=  (path, linenr1);
	|	open < msglen	&& close2 < msglen						=  (path, 0); 	
																=  (EmptyPathname, 0);
where 
	path	= msg % (inc open, dec comma1);
	linenr1	= dec` (SubStringToInt 0 (inc comma1) (dec comma2) msg);
	linenr2	= dec` (SubStringToInt 0 (inc comma1) (dec close1) msg);
	msglen	= size msg;
	open	= FindOpenChar msg msglen 0;
	close1	= FindCloseChar msg msglen (inc comma1);
	close2	= FindCloseChar msg msglen (inc open);
	comma1	= FindCommaChar msg msglen (inc open);
	comma2	= FindCommaChar msg msglen (inc comma1);
	
	dec`	:: !Int -> Int;
	dec` n | n == 0	= 0;
					= dec n;
	
//	FindOpenChar	:: !String !Int !Int -> Int;
FindOpenChar str len pos	:==  FindChar '[' str len pos;

//	FindCloseChar	:: !String !Int !Int -> Int;
FindCloseChar str len pos	:==  FindChar ']' str len pos;

//	FindCommaChar	:: !String !Int !Int -> Int;
FindCommaChar str len pos	:==  FindChar ',' str len pos;

//	FindQuoteChar	:: !String !Int !Int -> Int;
FindQuoteChar str len pos	:== FindChar '\"' str len pos;
	
//	FindColonChar	:: !String !Int !Int -> Int;
FindColonChar str len pos	:== FindChar ':' str len pos;
	
FindChar	:: !Char !String !Int !Int -> Int;
FindChar c line linelen pos
	| pos >= linelen		=  pos;
	| c ==  line.[pos]		=  pos;
							=  FindChar c line linelen (inc pos);
		
SubStringToInt :: !Int !Int !Int String -> Int;
SubStringToInt acc start stop str
	| start > stop	= acc;
	# curc	= str.[start];
	| isDigit curc
		# acc`	= 10 * acc + toInt curc - toInt '0';
		= SubStringToInt acc` (inc start) stop str;
	= acc;
