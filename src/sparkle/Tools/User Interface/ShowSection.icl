/*
** Program: Clean Prover System
** Module:  ShowSection (.icl)
** 
** Author:  Maarten de Mol
** Created: 19 January 2000
*/

implementation module 
	ShowSection

import 
	StdEnv,
	StdIO,
	States,
	ShowTheorem

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: TheoremInfo =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ infoTheorem					:: !Theorem
	, infoTheoremPtr				:: !TheoremPtr
	}

// -------------------------------------------------------------------------------------------------------------------------------------------------
MyGreen									:== RGB {r=  0, g=150, b= 75}
MyRed									:== RGB {r=150, g=  0, b=  0}
LightRed1								:== RGB {r=250, g=140, b=140}
LightRed2								:== RGB {r=210, g=100, b=100}
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
normalize :: !(MarkUpText a) -> MarkUpText a
// -------------------------------------------------------------------------------------------------------------------------------------------------
normalize [CmColour _:ftext]			= normalize ftext
normalize [CmEndColour:ftext]			= normalize ftext
normalize [CmBackgroundColour _:ftext]	= normalize ftext
normalize [CmEndBackgroundColour:ftext]	= normalize ftext
normalize [CmBold:ftext]				= normalize ftext
normalize [CmEndBold:ftext]				= normalize ftext
normalize [CmItalic:ftext]				= normalize ftext
normalize [CmEndItalic:ftext]			= normalize ftext
normalize [CmBText text:ftext]			= [CmText text: normalize ftext]
normalize [CmIText text:ftext]			= [CmText text: normalize ftext]
normalize [CmLink text _:ftext]			= [CmText text: normalize ftext]
normalize [command:ftext]				= [command: normalize ftext]
normalize []							= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
areMembers :: ![TheoremPtr] ![TheoremPtr] -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
areMembers [ptr:ptrs] pool
	| isMember ptr pool					= areMembers ptrs pool
	= False
areMembers [] pool
	= True

// -------------------------------------------------------------------------------------------------------------------------------------------------
openSection :: !SectionPtr !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
openSection ptr pstate
	# (opened, pstate)					= isWindowOpened (WinSection ptr) True pstate
	| opened							= pstate
	# (winfo, pstate)					= new_Window (WinSection ptr) pstate
	# window_id							= winfo.wiWindowId
	# window_rid						= fromJust winfo.wiSpecialRId
	# window_pos						= winfo.wiStoredPos
	# window_width						= winfo.wiStoredWidth
	# window_height						= winfo.wiStoredHeight
	# (section, pstate)					= accHeaps (readPointer ptr) pstate
	# (ftext, pstate)					= showTheorems section.seTheorems pstate
	= MarkUpWindow ("SECTION " +++ section.seName) ftext
		[ MarkUpFontFace				"Times New Roman"
		, MarkUpTextSize				10
		, MarkUpBackgroundColour		LightRed1
		, MarkUpReceiver				window_rid
		, MarkUpEventHandler			(clickHandler (event_handler window_id window_rid))
		, MarkUpLinkStyle				False Black LightRed1 False Black LightRed2
		, MarkUpWidth					window_width
		, MarkUpHeight					window_height
		]
		[ WindowId						window_id
		, WindowClose					(noLS (close_Window (WinSection ptr)))
		, WindowPos						(LeftTop, OffsetVector window_pos)
		] pstate
	where
		event_handler :: !Id !(RId (MarkUpMessage WindowCommand)) !WindowCommand !*PState -> *PState
		event_handler window_id rid (CmdShowTheorem ptr) pstate
			= openTheorem ptr pstate
		event_handler window_id rid CmdRefreshAlways pstate
			# (section, pstate)			= accHeaps (readPointer ptr) pstate
			# (ftext, pstate)			= showTheorems section.seTheorems pstate
			# pstate					= changeMarkUpText rid ftext pstate
			= pstate
		event_handler window_id rid (CmdRefresh any) pstate
			# (section, pstate)			= accHeaps (readPointer ptr) pstate
			# (ftext, pstate)			= showTheorems section.seTheorems pstate
			# pstate					= changeMarkUpText rid ftext pstate
			= pstate
		
		// needed because (Below id, zero) does not function properly
		below :: !Id !*PState -> (!ItemPos, !*PState)
		below id pstate
			# (mb_vector, pstate)		= accPIO (getWindowPos id) pstate
			| isNothing mb_vector		= ((LeftTop, zero), pstate)
			# vector					= fromJust mb_vector
			# (size, pstate)			= accPIO (getWindowOuterSize id) pstate
			= ((LeftTop, OffsetVector {vx=vector.vx,vy=vector.vy+size.h}), pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
showTheorems :: ![TheoremPtr] !*PState -> (!MarkUpText WindowCommand, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
showTheorems ptrs pstate
	# (finfo, pstate)					= makeFormatInfo pstate
	# (theorems, pstate)				= accHeaps (readPointers ptrs) pstate
	# infos								= [empty_info ptr theorem \\ ptr <- ptrs & theorem <- theorems]
	# infos								= sortBy (\i1 i2 -> i1.infoTheorem.thName < i2.infoTheorem.thName) infos
	# (true, pstate)					= accHeaps (findProved infos) pstate
	# (ftheorems, pstate)				= case (isEmpty infos) of
											True	-> ([CmIText "no theorems"], pstate)
											False	-> show 0 infos true finfo pstate
	= (ftheorems, pstate)
	where
		empty_info ptr theorem
			=	{ infoTheorem			= theorem
				, infoTheoremPtr		= ptr
				}
	
		show :: !Int ![TheoremInfo] ![TheoremPtr] !FormatInfo !*PState -> (!MarkUpText WindowCommand, !*PState)
		show num [info:infos] true finfo pstate
			# (ftexts, pstate)			= show (num+1) infos true finfo pstate
			# (_, finitial, pstate)		= accErrorHeapsProject (FormattedShow finfo info.infoTheorem.thInitial) pstate
			# finitial					= [CmFontFace "Courier New", CmSize 8, CmColour DarkGrey] ++ normalize (removeCmLink finitial) ++ [CmEndColour, CmEndSize, CmEndFontFace]
			# proved					= isEmpty info.infoTheorem.thProof.pLeafs
			# dependable				= areMembers info.infoTheorem.thProof.pUsedTheorems true
			# fproved					= case proved && dependable of
											True	-> [CmLabel (toString num) True] ++ checked ++ [CmText " ", CmAlign "T"]
											False	-> [CmLabel (toString num) True] ++ unchecked ++ [CmText " ", CmAlign "T"]
			# fname						=	[ CmBold
											, CmLink	info.infoTheorem.thName (CmdShowTheorem info.infoTheoremPtr)
											, CmText	": "
											, CmEndBold
											, CmAlign	"P"
											]
			= (fproved ++ fname ++ finitial ++ [CmNewline] ++ ftexts, pstate)
			where
				checked					=	[ CmColour		MyGreen
											, CmFontFace	"Wingdings"
											, CmBText		{toChar 252}
											, CmEndFontFace
											, CmEndColour
											]
				unchecked				=	[ CmColour		MyRed
											, CmFontFace	"Wingdings"
											, CmBText		{toChar 251}
											, CmEndFontFace
											, CmEndColour
											]
		show num [] true finfo pstate
			= ([], pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
findProved :: ![TheoremInfo] !*CHeaps -> (![TheoremPtr], !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
findProved infos heaps
	# (_, true, false, heaps)			= add_multiple_to_pool [info.infoTheoremPtr \\ info <- infos] [] [] heaps
	= (true, heaps)
	where
		add_to_pool :: !TheoremPtr ![TheoremPtr] ![TheoremPtr] !*CHeaps -> (!Bool, ![TheoremPtr], ![TheoremPtr], !*CHeaps)
		add_to_pool ptr true false heaps
			| isMember ptr true			= (True, true, false, heaps)
			| isMember ptr false		= (False, true, false, heaps)
			# (theorem, heaps)			= readPointer ptr heaps
			# proof_finished			= isEmpty theorem.thProof.pLeafs
			| not proof_finished		= (False, true, [ptr:false], heaps)
			# (ok, true, false, heaps)	= add_multiple_to_pool theorem.thProof.pUsedTheorems true false heaps
			| ok						= (True, [ptr:true], false, heaps)
			| not ok					= (False, true, [ptr:false], heaps)
		
		add_multiple_to_pool :: ![TheoremPtr] ![TheoremPtr] ![TheoremPtr] !*CHeaps -> (!Bool, ![TheoremPtr], ![TheoremPtr], !*CHeaps)
		add_multiple_to_pool [ptr:ptrs] true false heaps
			# (ok1, true, false, heaps)	= add_to_pool ptr true false heaps
			# (ok2, true, false, heaps)	= add_multiple_to_pool ptrs true false heaps
			= (ok1 && ok2, true, false, heaps)
		add_multiple_to_pool [] true false heaps
			= (True, true, false, heaps)