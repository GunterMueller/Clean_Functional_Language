implementation module finder

import StdArray, StdEnum, StdTuple, StdFunc, StdMisc
import EdClient, EdFind, EdText
import IdeState
import ioutil, ExtNotice


:: WorkType
	= Find
	| Replace
	| ReplaceAll

instance == WorkType
where
	(==) Find Find = True
	(==) Replace Replace = True
	(==) ReplaceAll ReplaceAll = True
	(==) _ _ = False

//--- search routines

sr_find :: !*(PSt *General) -> *PSt *General
sr_find pstate			// Find
	#	(finfo,pstate)		= getFI pstate
		(fId,pstate)		= openId pstate
		(okId,pstate)		= openId pstate
		(findId,pstate)		= openId pstate
		(replId,pstate)		= openId pstate
		(cancelId,pstate)	= openId pstate
	#	(win,pstate)		= accPIO getActiveWindow pstate
		(twi,pstate)		= accPLoc getTypeWinInfo pstate
	| isNothing win
		= pstate
	# win					= fromJust win
	#	istypewin			= isTypeWindow win twi 
	| istypewin
		# (_,pstate)		= openModalDialog undef (edef finfo fId okId findId replId cancelId) pstate
		= pstate
	# (_,pstate)			= openModalDialog undef (fdef finfo fId okId findId replId cancelId win) pstate
	= pstate
where
	fdef finfo fId okId findId replId cancelId windId =
		Dialog "Find"
		(	TextControl "Find:"
				[]
		:+: PopUpControl [(unfixspecials ff,id)\\ ff <- finfo.fi_find] 0
				[ ControlPos		(Left,zero)
				, ControlId			findId
				, ControlKeyboard	filterReturnKeys Able (noLS1 (\_->findKey))	// Should remove enter from string...
				, ControlDeactivate	(noLS findKey)
				, ControlWidth		(PixelWidth 300)
				]
		:+:	TextControl "Replace With:"
				[ ControlPos		(Left,zero)
				]
		:+: PopUpControl [(unfixspecials rp,id)\\ rp <- finfo.fi_repl] 0
				[ ControlPos		(Left,zero)
				, ControlId			replId
				, ControlKeyboard	filterReturnKeys Able (noLS1 (\_->replKey))	// Should remove enter from string...
				, ControlDeactivate	(noLS replKey)
				, ControlWidth		(PixelWidth 300)
				]
		:+: CheckControl
				[ ("Ignore Case"	,Nothing, toMark finfo.fi_ic, noLS flipIC)
				, ("Wrap Around"	,Nothing, toMark finfo.fi_wa, noLS flipWA)
				, ("Backward"		,Nothing, toMark finfo.fi_bw, noLS flipBW)
				, ("Match Words"	,Nothing, toMark finfo.fi_mw, noLS flipMW)
				, ("Use Reg Exp"	,Nothing, toMark finfo.fi_re, noLS flipRE)
				] (Columns 2)
				[ ControlPos (Left,zero)
				]
		:+: ButtonControl "Cancel"
				[ ControlFunction	(noLS (closeWindow fId))
				, ControlPos		(Left,zero)
				, ControlId			cancelId
				]
		:+: ButtonControl "Replace All"
				[ ControlFunction	(noLS (lrepa fId findId replId windId))
				]
		:+: ButtonControl "Replace"
				[ ControlFunction	(noLS (lrepl fId findId replId windId))
				]
		:+: ButtonControl "Find"
				[ ControlFunction	(noLS (lfind fId findId replId windId))
				, ControlId			okId
				]
		)
		[ WindowId		fId
		, WindowOk		okId
		, WindowCancel	cancelId
		, WindowClose	(noLS (closeWindow fId))
		]
	where
		// Hmmm... these two should at least check if find/repl string already in list...
		findKey ps=:{io}
			# (wst,io)	= getWindow fId io
			# title		= fromJust (snd (getControlText findId (fromJust wst)))
			# io		= openPopUpControlItems findId 0 [(title,id)] io
			# io		= selectPopUpControlItem findId 0 io
			= {ps & io=io}

		replKey ps=:{io}
			# (wst,io)	= getWindow fId io
			# title		= fromJust (snd (getControlText replId (fromJust wst)))
			# io		= openPopUpControlItems replId 0 [(title,id)] io
			# io		= selectPopUpControlItem replId 0 io
			= {ps & io=io}

	edef finfo fId okId findId replId cancelId =
		Dialog "Find"
		(	TextControl "Find:"
				[]
		:+: PopUpControl [(unfixspecials ff,id)\\ ff <- finfo.fi_find] 0
				[ ControlPos		(Left,zero)
				, ControlId			findId
				, ControlKeyboard	filterReturnKeys Able (noLS1 (\_->findKey))
				, ControlDeactivate	(noLS findKey)
				, ControlWidth		(PixelWidth 300)
				]
		:+: CheckControl
				[ ("Ignore Case"	,Nothing, toMark finfo.fi_ic, noLS flipIC)
				, ("Wrap Around"	,Nothing, toMark finfo.fi_wa, noLS flipWA)
				, ("Backward"		,Nothing, toMark finfo.fi_bw, noLS flipBW)
				, ("Match Words"	,Nothing, toMark finfo.fi_mw, noLS flipMW)
				, ("Use Reg Exp"	,Nothing, toMark finfo.fi_re, noLS flipRE)
				] (Columns 2)
				[ ControlPos (Left,zero)
				]
		:+: ButtonControl "Cancel"
				[ ControlFunction	(noLS (closeWindow fId))
				, ControlPos		(Left,zero)
				, ControlId			cancelId
				]
		:+: ButtonControl "Find"
				[ ControlFunction	(noLS (tfind fId findId replId))
				, ControlId			okId
				]
		)
		[ WindowId		fId
		, WindowOk		okId
		, WindowCancel	cancelId
		, WindowClose	(noLS (closeWindow fId))
		]
	where
		tfind :: !Id !Id !Id !*(PSt *General) -> *PSt *General
		tfind dlogId findId replId pstate
			#	(wstate,pstate)		= accPIO (getWindow dlogId) pstate
			| isNothing wstate = pstate
			#	wstate				= fromJust wstate
				find				= getControlText findId wstate
				find				= snd find
			| isNothing find = pstate
			#	find				= fixspecials (fromJust find)
				pstate				= closeWindow dlogId pstate
		
				(fi,pstate)			= getFI pstate
				fi					=	{ fi
										& fi_find = removeDup [find:fi.fi_find]
										}
				pstate				= setFI fi pstate
			= sr_types_worker Find fi pstate

		findKey ps=:{io}
			# (wst,io)	= getWindow fId io
			# title		= fromJust (snd (getControlText findId (fromJust wst)))
			# io		= openPopUpControlItems findId 0 [(title,id)] io
			# io		= selectPopUpControlItem findId 0 io
			= {ps & io=io}

	flipIC ps
		#	(fi,ps)	= getFI ps
		= setFI {fi & fi_ic = not fi.fi_ic} ps
	flipWA ps
		#	(fi,ps)	= getFI ps
		= setFI {fi & fi_wa = not fi.fi_wa} ps
	flipBW ps
		#	(fi,ps)	= getFI ps
		= setFI {fi & fi_bw = not fi.fi_bw} ps
	flipMW ps
		#	(fi,ps)	= getFI ps
		= setFI {fi & fi_mw = not fi.fi_mw} ps
	flipRE ps
		#	(fi,ps)	= getFI ps
		= setFI {fi & fi_re = not fi.fi_re} ps
		
	lfind :: !Id !Id !Id !Id !*(PSt *General) -> *PSt *General
	lfind dlogId findId replId windId pstate
		#	(wstate,pstate)		= accPIO (getWindow dlogId) pstate
			wstate				= fromJust wstate
			find				= getControlText findId wstate
			repl				= getControlText replId wstate
			find				= fromJust (snd find)
			find				= fixspecials find
			repl				= fromJust (snd repl)
			repl				= fixspecials repl
			pstate				= closeWindow dlogId pstate
	
			(fi,pstate)			= getFI pstate
			fi					=	{ fi
									& fi_find = removeDup [find:fi.fi_find]
									, fi_repl = removeDup [repl:fi.fi_repl]
									}
			pstate				= setFI fi pstate
		= sr_worker windId Find fi pstate

	lrepl :: !Id !Id !Id !Id !*(PSt *General) -> *PSt *General
	lrepl dlogId findId replId windId pstate
		#	(wstate,pstate)		= accPIO (getWindow dlogId) pstate
			wstate				= fromJust wstate
			find				= getControlText findId wstate
			repl				= getControlText replId wstate
			find				= fromJust (snd find)
			find				= fixspecials find
			repl				= fromJust (snd repl)
			repl				= fixspecials repl
			pstate				= closeWindow dlogId pstate
	
			(fi,pstate)			= getFI pstate
			fi					=	{ fi
									& fi_find = removeDup [find:fi.fi_find]
									, fi_repl = removeDup [repl:fi.fi_repl]
									}
			pstate				= setFI fi pstate
		= sr_worker windId Replace fi pstate

	lrepa :: !Id !Id !Id !Id !*(PSt *General) -> *PSt *General
	lrepa dlogId findId replId windId pstate
		#	(wstate,pstate)		= accPIO (getWindow dlogId) pstate
			wstate				= fromJust wstate
			find				= getControlText findId wstate
			repl				= getControlText replId wstate
			find				= fromJust (snd find)
			find				= fixspecials find
			repl				= fromJust (snd repl)
			repl				= fixspecials repl
			pstate				= closeWindow dlogId pstate
	
			(fi,pstate)			= getFI pstate
			fi					=	{ fi
									& fi_find = removeDup [find:fi.fi_find]
									, fi_repl = removeDup [repl:fi.fi_repl]
									}
			pstate				= setFI fi pstate
		= sr_worker windId ReplaceAll fi pstate

fixspecials string
	# string = [c \\ c <-: string]
	# string = fixspecials string
	# string = {c \\ c <- string}
	= string
where
	fixspecials [] = []
	fixspecials [h:t]
		# (h,t) = case h of
						'\\' -> fixspecials` t
						c	-> (c,t)
		# t = fixspecials t
		= [h:t]
	fixspecials` [] = ('\\',[])
	fixspecials` [h:t] = case h of
							'\\' -> ('\\',t)
							't' -> ('\t',t)
							c	-> (c,t)

unfixspecials string
	# string = [c \\ c <-: string]
	= unfixspecials string
where
	unfixspecials [] = ""
	unfixspecials [h:t]
		# h = case h of
						'\\' -> "\\\\"
						'\t' -> "\\t"
						c	-> {c}
		# t = unfixspecials t
		= h+++t
	
// Find Again
sr_find_next :: !*(PSt *General) -> *PSt *General
sr_find_next pstate
	# (finfo,pstate)		= getFI pstate
	#	(win,pstate)		= accPIO getActiveWindow pstate
		(twi,pstate)		= accPLoc getTypeWinInfo pstate
	| isNothing win
		= pstate
	# win					= fromJust win
	# istypewin				= isTypeWindow win twi 
	| istypewin
		= sr_types_worker Find finfo pstate
	= sr_worker win Find finfo pstate

// Worker funs
sr_worker :: !Id !WorkType !FindInfo !*(PSt *General) -> *PSt *General
sr_worker wId work_type finfo pstate
  	# (maybesel,pstate)	= message wId msgGetSelection pstate
  	| isNothing maybesel
  		= pstate
  	# (_,pos)			= fromJust maybesel
  	| isEmpty finfo.fi_find
  		= pstate
  	# fnd				= hd finfo.fi_find
  	| size fnd == 0
  		= pstate
  	| (work_type == Replace || work_type == ReplaceAll) && isEmpty finfo.fi_repl
  		= pstate
  	# rep				= hd finfo.fi_repl
/* Removed due to popular demand...
  	| (work_type == Replace || work_type == ReplaceAll) && size rep == 0
  		= pstate
*/
  	= case work_type of
		Find
			# fri =
				{ fr_pos			= pos
				, fr_search			= fnd
				, fr_replace		= ""
				, fr_ignore_case	= finfo.fi_ic
				, fr_match_words	= finfo.fi_mw
				, fr_backwards		= finfo.fi_bw
				, fr_wraparound		= finfo.fi_wa
				, fr_regexp			= finfo.fi_re
				}
			# (res,pstate)	= message wId (msgFind fri) pstate
			| (isNothing res) || (fromJust res == False)
				-> appPIO beep pstate
			-> pstate
		Replace
			# fri =
				{ fr_pos			= pos
				, fr_search			= fnd
				, fr_replace		= rep
				, fr_ignore_case	= finfo.fi_ic
				, fr_match_words	= finfo.fi_mw
				, fr_backwards		= finfo.fi_bw
				, fr_wraparound		= finfo.fi_wa
				, fr_regexp			= finfo.fi_re
				}
			# (res,pstate)	= message wId (msgReplace fri) pstate
			| (isNothing res) || (fromJust res == False)
				-> appPIO beep pstate
			-> pstate
		ReplaceAll
			# fri =
				{ fr_pos			= pos
				, fr_search			= fnd
				, fr_replace		= rep
				, fr_ignore_case	= finfo.fi_ic
				, fr_match_words	= finfo.fi_mw
				, fr_backwards		= finfo.fi_bw
				, fr_wraparound		= finfo.fi_wa
				, fr_regexp			= finfo.fi_re
				}
			# (res,pstate)	= message wId (msgReplaceAll fri) pstate
			| isNothing res
				-> appPIO beep pstate
			-> okNotice [toString (fromJust res)+++" occurences replaced."] pstate

sr_types_worker :: !WorkType !FindInfo !*(PSt *General) -> *PSt *General
sr_types_worker work_type finfo pstate
  	# (maybesel,pstate)	= type_win_message msgGetSelection pstate
  	| isNothing maybesel
  		= pstate
  	# (_,pos)			= fromJust maybesel
  	| isEmpty finfo.fi_find
  		= pstate
  	# fnd				= hd finfo.fi_find
  	| size fnd == 0
  		= pstate
/* Removed due to pointless...
  	| (work_type == Replace || work_type == ReplaceAll) && isEmpty finfo.fi_repl
  		= pstate
  	# rep				= hd finfo.fi_repl
  	| (work_type == Replace || work_type == ReplaceAll) && size rep == 0
  		= pstate
*/
  	= case work_type of
		Find
			# fri =
				{ fr_pos			= pos
				, fr_search			= fnd
				, fr_replace		= ""
				, fr_ignore_case	= finfo.fi_ic
				, fr_match_words	= finfo.fi_mw
				, fr_backwards		= finfo.fi_bw
				, fr_wraparound		= finfo.fi_wa
				, fr_regexp			= finfo.fi_re
				}
			# (res,pstate)	= type_win_message (msgFind fri) pstate
			| (isNothing res) || (fromJust res == False)
				-> appPIO beep pstate
			-> pstate
		_
			-> abort "Can only find in types window?!"


// Find Selection
sr_find_sel :: !*(PSt *General) -> *PSt *General
sr_find_sel pstate
	#	(win,pstate)		= accPIO getActiveWindow pstate
		(twi,pstate)		= accPLoc getTypeWinInfo pstate
	| isNothing win
		= pstate
	# win					= fromJust win
	#	istypewin			= isTypeWindow win twi 
	# (maybesel,pstate)		= case istypewin of
								True	-> type_win_message msgGetSelection pstate
								False	-> message win msgGetSelection pstate
  	| isNothing maybesel
  		= pstate
  	# (sel,_)				= fromJust maybesel
  	| size sel == 0
  		= sr_find pstate
  	# (fi,pstate)			= getFI pstate
  	# fi					=	{ fi
  								& fi_find = removeDup [sel:fi.fi_find]
  								, fi_re = False		// switch off regexp searching
  								}
  	# pstate				= setFI fi pstate
	| istypewin
		= sr_types_worker Find fi pstate
	= sr_worker win Find fi pstate

// Replace & Find Again
// Rethink wanted behaviour...
sr_rep_find :: !*(PSt *General) -> *PSt *General
sr_rep_find pstate
	#	(win,pstate)		= accPIO getActiveWindow pstate
		(twi,pstate)		= accPLoc getTypeWinInfo pstate
	| isNothing win
		= pstate
	# win					= fromJust win
	#	istypewin			= isTypeWindow win twi 
	| istypewin
		= pstate
	# (finfo,pstate)		= getFI pstate
	| isEmpty finfo.fi_repl
		= pstate
  	| finfo.fi_re
  		= regexp_replace_find win finfo pstate
	# (maybesel,pstate)		= message win msgGetSelection pstate
  	| isNothing maybesel
  		= pstate
  	# (sel,_)				= fromJust maybesel
  	| sel == ""
  		= sr_worker win Find finfo pstate
  	#	(_,pstate)			= message win (msgReplaceSelection (hd finfo.fi_repl)) pstate
	| isEmpty finfo.fi_find
		= pstate
	| size (hd finfo.fi_find) == 0
		= pstate
	= sr_worker win Find finfo pstate

regexp_replace_find wId finfo pstate
	# srch					= finfo.fi_find
	| isEmpty srch
		= pstate
	# srch					= hd srch
	# repl					= finfo.fi_repl
	| isEmpty repl
		= pstate
	# repl					= hd repl
	# (maybesel,pstate)		= message wId msgGetSelection pstate
	# (maybetext,pstate)	= message wId msgGetText pstate
  	| isNothing maybesel || isNothing maybetext
  		= pstate
	# (_,sel)				= fromJust maybesel
	# text					= fromJust maybetext
	# (line,_)				= getLine sel.start.row text
	# result				= regexpLineReplace sel finfo.fi_bw finfo.fi_wa finfo.fi_ic finfo.fi_mw srch repl line
	| isNothing result
		= pstate
	# result				= fromJust result
  	# (_,pstate)			= message wId (msgReplaceSelection result) pstate
	= sr_worker wId Find finfo pstate

//--- jump to ... stuff

sr_goto_cursor :: !*(PSt *General) -> *PSt *General
sr_goto_cursor pstate	// Goto cursor
	#	(win,pstate)		= accPIO getActiveWindow pstate
		(twi,pstate)		= accPLoc getTypeWinInfo pstate
	| isNothing win
		= pstate
	# win					= fromJust win
	#	istypewin			= isTypeWindow win twi 
	| istypewin
		# (_,pstate)		= type_win_message msgScrollToCursor pstate
		= pstate
	#	(_,pstate)			= message win msgScrollToCursor pstate
	= pstate

sr_goto_line :: !*(PSt *General) -> *PSt *General
sr_goto_line pstate
	# (win,pstate)			= accPIO getActiveWindow pstate
	| isNothing win
		= pstate
	# win					= fromJust win
	# (twi,pstate)			= accPLoc getTypeWinInfo pstate
	# istypewin				= isTypeWindow win twi 
	# (maybesel,pstate)		= case istypewin of
								True	-> type_win_message msgGetSelection pstate
								False	-> message win msgGetSelection pstate
	| isNothing maybesel
		= pstate
	# (_,{end=pos})			= fromJust maybesel
	# (gId,pstate)			= openId pstate
	# (okId,pstate)			= openId pstate
	# (cancelId,pstate)		= openId pstate
	# (lineId,pstate)		= openId pstate
	# (_,pstate)			= openModalDialog undef (gdef pos.row gId okId cancelId lineId istypewin win) pstate
	= pstate
where
	gdef linenr gId okId cancelId lineId istypewin win =
		Dialog "Goto Line"
		(	TextControl "Goto Line:" []
		:+: EditControl (toString (inc linenr)) (ContentWidth "888888") 1
				[ ControlId lineId
//				, ControlKeyboard escFilter Able (noLS1 (const (closeWindow gId)))
				, ControlActivate (noLS (appPIO (setEditControlSelection lineId 1 0)))
				]
		:+:	ButtonControl "Cancel"
				[ ControlPos (Left,zero)
				, ControlFunction (noLS (closeWindow gId))
				, ControlId cancelId
				]
		:+: ButtonControl "OK"
				[ ControlId okId
				, ControlFunction (noLS (goto))
				]
		)
		[ WindowId gId
		, WindowOk okId
		, WindowCancel cancelId
		, WindowClose (noLS (closeWindow gId))
		]
	where
		goto pstate
			#	(wstate,pstate)		= accPIO (getWindow gId) pstate
				wstate				= fromJust wstate
				line				= getControlText lineId wstate
				line				= fromJust (snd line)
				pstate				= closeWindow gId pstate
				line				= dec (toInt line)
				(_,pstate)			= case istypewin of
										True	-> type_win_message (msgScrollToLine line) pstate
										False	-> message win (msgScrollToLine line) pstate
			= pstate

sr_goto_selection :: !*(PSt *General) -> *PSt *General
sr_goto_selection pstate
	# (win,pstate)			= accPIO getActiveWindow pstate
	| isNothing win
		= pstate
	# win					= fromJust win
	# (twi,pstate)			= accPLoc getTypeWinInfo pstate
	# istypewin				= isTypeWindow win twi 
	# (maybesel,pstate)		= case istypewin of
								True	-> type_win_message msgGetSelection pstate
								False	-> message win msgGetSelection pstate
	| isNothing maybesel
		= pstate
	# (_,{end=pos})			= fromJust maybesel
	# (gotoIds,pstate)		= accPIO (openIds numIds) pstate
	# (_,pstate)			= openModalDialog undef (gdef gotoIds pos istypewin win) pstate
	= pstate
where
	gId		= 0
	okId	= 1
	cancelId= 2
	flId	= 3
	fcId	= 4
	tlId	= 5
	tcId	= 6
	numIds	= 7
	textWidth = ContentWidth "From column:"
	gdef idslist pos istypewin win =
		Dialog "Goto Selection"
		(	TextControl "From line:"
				[ ControlWidth textWidth
				]
		:+: EditControl (toString (inc pos.row)) (ContentWidth "888888") 1
				[ ControlId (idslist!!flId)
				, ControlKeyboard escFilter Able (noLS1 (const (closeWindow (idslist!!gId))))
				, ControlActivate (noLS (appPIO (setEditControlSelection (idslist!!flId) 1 0)))
				]
		:+:	TextControl "From column:"
				[ ControlPos (Left,zero)
				, ControlWidth textWidth
				]
		:+: EditControl (toString (pos.col)) (ContentWidth "888888") 1
				[ ControlId (idslist!!fcId)
				, ControlKeyboard escFilter Able (noLS1 (const (closeWindow (idslist!!gId))))
				, ControlActivate (noLS (appPIO (setEditControlSelection (idslist!!fcId) 1 0)))
				]
		:+:	TextControl "To line:"
				[ ControlPos (Left,zero)
				, ControlWidth textWidth
				]
		:+: EditControl (toString (inc pos.row)) (ContentWidth "888888") 1
				[ ControlId (idslist!!tlId)
				, ControlKeyboard escFilter Able (noLS1 (const (closeWindow (idslist!!gId))))
				, ControlActivate (noLS (appPIO (setEditControlSelection (idslist!!tlId) 1 0)))
				]
		:+:	TextControl "To column:"
				[ ControlPos (Left,zero)
				, ControlWidth textWidth
				]
		:+: EditControl (toString (pos.col)) (ContentWidth "888888") 1
				[ ControlId (idslist!!tcId)
				, ControlKeyboard escFilter Able (noLS1 (const (closeWindow (idslist!!gId))))
				, ControlActivate (noLS (appPIO (setEditControlSelection (idslist!!tcId) 1 0)))
				]
		:+:	ButtonControl "Cancel"
				[ ControlPos (Left,zero)
				, ControlFunction (noLS (closeWindow (idslist!!gId)))
				, ControlId (idslist!!cancelId)
				]
		:+: ButtonControl "OK"
				[ ControlId (idslist!!okId)
				, ControlFunction (noLS (goto))
				]
		)
		[ WindowId (idslist!!gId)
		, WindowOk (idslist!!okId)
		, WindowCancel (idslist!!cancelId)
		, WindowClose (noLS (closeWindow (idslist!!gId)))
		]
	where
		goto pstate
			#	(wstate,pstate)		= accPIO (getWindow (idslist!!gId)) pstate
			| isNothing wstate
				= pstate
			#	wstate				= fromJust wstate
				fl					= getControlText (idslist!!flId) wstate
				fc					= getControlText (idslist!!fcId) wstate
				tl					= getControlText (idslist!!tlId) wstate
				tc					= getControlText (idslist!!tcId) wstate
				fl					= fromJust (snd fl)
				fc					= fromJust (snd fc)
				tl					= fromJust (snd tl)
				tc					= fromJust (snd tc)
				pstate				= closeWindow (idslist!!gId) pstate
				fl					= dec (toInt fl)
				fc					= toInt fc
				tl					= dec (toInt tl)
				tc					= toInt tc
				sel					= {start={row=fl,col=fc},end={row=tl,col=tc}}
				(_,pstate)			= case istypewin of
										True	-> type_win_message (msgChangeSelection sel) pstate
										False	-> message win (msgChangeSelection sel) pstate
			= pstate

