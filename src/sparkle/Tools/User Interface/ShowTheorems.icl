/*
** Program: Clean Prover System
** Module:  ShowTheorems (.icl)
** 
** Author:  Maarten de Mol
** Created: 14 March 2001
*/

implementation module
	ShowTheorems

import
	StdEnv,
	StdIO,
	ossystem,
	Depends,
	Hints,
	MdM_IOlib,
	ShowProof,
	ShowTheorem,
	States,
	FileMonad
from StdFunc import seq

// ------------------------------------------------------------------------------------------------------------------------   
LightBlue							:== RGB {r=224, g=227, b=253}
MyGreen								:== RGB {r=  0, g=150, b= 75}
// ------------------------------------------------------------------------------------------------------------------------   

// ------------------------------------------------------------------------------------------------------------------------   
:: FilterCommand =
// ------------------------------------------------------------------------------------------------------------------------   
	  ChangeSectionStatus	!SectionPtr
	| AddAllSections
	| RemoveAllSections

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
normalize [CmLink2 num text _:ftext]	= [CmText text: normalize ftext]
normalize [command:ftext]				= [command: normalize ftext]
normalize []							= []

// ------------------------------------------------------------------------------------------------------------------------   
:: TheoremInfo =
// ------------------------------------------------------------------------------------------------------------------------   
	{ tiName					:: !CName
	, tiPointer					:: !TheoremPtr
	, tiProved					:: !Bool
	, tiInitial					:: !CPropH
	, tiSectionName				:: !CName
	}

// ------------------------------------------------------------------------------------------------------------------------   
showWith :: !String ![String] -> String
// ------------------------------------------------------------------------------------------------------------------------   
showWith sep [text:texts]
	| isEmpty texts 					= text
	= text +++ sep +++ showWith sep texts
showWith sep []
	= ""

// ------------------------------------------------------------------------------------------------------------------------   
separate :: !String -> [String]
// ------------------------------------------------------------------------------------------------------------------------   
separate text
	= find [] 0 (size text)
	where
		find :: ![Char] !Int !Int -> [String]
		find acc index max
			| index >= max				= case isEmpty acc of
											True	-> []
											False	-> [toString acc]
			# char						= text.[index]
			| char <> ' '				= find (acc ++ [char]) (index+1) max
			= case isEmpty acc of
				True	-> find [] (index+1) max
				False	-> [toString acc: find [] (index+1) max]
















// ------------------------------------------------------------------------------------------------------------------------   
inFilter :: !Bool !Theorem !TheoremFilter !*PState -> (!Bool, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
inFilter check_section theorem filter pstate
	# in_status							= case filter.tfStatus of
											DontCare	-> True
											Proved		-> isEmpty theorem.thProof.pLeafs
											Unproved	-> not (isEmpty theorem.thProof.pLeafs)
	| not in_status						= (False, pstate)
	# in_section						= case check_section of
											True	-> isMember theorem.thSection filter.tfSections
											False	-> True
	| not in_section					= (False, pstate)
	# in_name_filter					= checkNameFilter filter.tfName theorem.thName
	| not in_name_filter				= (False, pstate)
	# (names, pstate)					= accHeaps (check_used_theorems theorem.thProof.pUsedTheorems filter.tfUsing) pstate
	# (names, pstate)					= accHeapsProject (check_used_symbols theorem.thProof.pUsedSymbols names) pstate
	# names								= check_logic_operators theorem.thInitial names
	| not (isEmpty names)				= (False, pstate)
	= (True, pstate)
	where
		check_used_theorems :: ![TheoremPtr] ![CName] !*CHeaps -> (![CName], !*CHeaps)
		check_used_theorems [ptr:ptrs] names heaps
			# (name, heaps)				= getPointerName ptr heaps
			# names						= removeMember name names
			= check_used_theorems ptrs names heaps
		check_used_theorems [] names heaps
			= (names, heaps)
		
		check_used_symbols :: ![HeapPtr] ![CName] !*CHeaps !*CProject -> (![CName], !*CHeaps, !*CProject)
		check_used_symbols [ptr:ptrs] names heaps prj
			# (_, name, heaps, prj)		= getDefinitionName ptr heaps prj
			# names						= removeMember name names
			= check_used_symbols ptrs names heaps prj
		check_used_symbols [] names heaps prj
			= (names, heaps, prj)
		
		check_logic_operators :: !CPropH ![CName] -> [CName]
		check_logic_operators (CNot p) names
			# names						= removeMember "~" names
			= check_logic_operators p names
		check_logic_operators (CAnd p q) names
			# names						= removeMember "/\\" names
			= check_logic_operators p (check_logic_operators q names)
		check_logic_operators (COr p q) names
			# names						= removeMember "\\/" names
			= check_logic_operators p (check_logic_operators q names)
		check_logic_operators (CIff p q) names
			# names						= removeMember "<=>" names
			# names						= removeMember "<->" names
			= check_logic_operators p (check_logic_operators q names)
		check_logic_operators (CImplies p q) names
			# names						= removeMember "=>" names
			# names						= removeMember "->" names
			= check_logic_operators p (check_logic_operators q names)
		check_logic_operators (CExprForall _ p) names
			= check_logic_operators p names
		check_logic_operators (CExprExists _ p) names
			= check_logic_operators p names
		check_logic_operators (CPropForall _ p) names
			= check_logic_operators p names
		check_logic_operators (CPropExists _ p) names
			= check_logic_operators p names
		check_logic_operators _ names
			= names

// ------------------------------------------------------------------------------------------------------------------------   
getTheorems :: !TheoremFilter !*PState -> (![TheoremInfo], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
getTheorems filter pstate
	# section_ptrs						= filter.tfSections
	= accumulate_theorems section_ptrs [] pstate
	where
		accumulate_theorems :: ![SectionPtr] ![TheoremInfo] !*PState -> (![TheoremInfo], !*PState)
		accumulate_theorems [ptr:ptrs] acc pstate
			# (section, pstate)			= accHeaps (readPointer ptr) pstate
			# (acc, pstate)				= extend section.seName section.seTheorems acc pstate
			= accumulate_theorems ptrs acc pstate
		accumulate_theorems [] acc pstate
			= (acc, pstate)
		
		extend :: !CName ![TheoremPtr] ![TheoremInfo] !*PState -> (![TheoremInfo], !*PState)
		extend section_name [ptr:ptrs] acc pstate
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# (in_filter, pstate)		= inFilter False theorem filter pstate
			# info						=	{ tiName			= theorem.thName
											, tiPointer			= ptr
											, tiProved			= isEmpty theorem.thProof.pLeafs
											, tiInitial			= theorem.thInitial
											, tiSectionName		= section_name
											}
			= case in_filter of
				True	-> extend section_name ptrs [info:acc] pstate
				False	-> extend section_name ptrs acc pstate
		extend section_name [] acc pstate
			= (acc, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
showProp :: !CPropH !*PState -> (!MarkUpText a, !MarkUpText a, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
showProp p pstate
	# (foralls, rule)					= split p
	# (finfo, pstate)					= makeFormatInfo pstate
	# (_, fforalls, pstate)				= case foralls of
											CTrue	-> (OK, [], pstate)
											_		-> accErrorHeapsProject (FormattedShow finfo foralls) pstate
	# fforalls							= removeCmLink (normalize fforalls)
	# fforalls							= remove_after_dot fforalls
	# (_, frule, pstate)				= accErrorHeapsProject (FormattedShow finfo rule) pstate
	# frule								= removeCmLink (normalize frule)
	= (fforalls, frule, pstate)
	where
		split :: !CPropH -> (!CPropH, !CPropH)
		split (CExprForall var p)
			# (p, q)					= split p
			= (CExprForall var p, q)
		split (CExprExists var p)
			# (p, q)					= split p
			= (CExprExists var p, q)
		split (CPropForall var p)
			# (p, q)					= split p
			= (CPropForall var p, q)
		split (CPropExists var p)
			# (p, q)					= split p
			= (CPropExists var p, q)
		split other
			= (CTrue, other)
		
		remove_after_dot :: !(MarkUpText a) -> MarkUpText a
		remove_after_dot [CmText ".":_]	= []
		remove_after_dot [cmd:cmds]		= [cmd: remove_after_dot cmds]
		remove_after_dot []				= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
showList :: !Bool !Bool ![TheoremInfo] ![TheoremPtr] ![TheoremPtr] !Colour !*PState -> (!MarkUpText WindowCommand, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
showList show_sections show_props infos true false bg pstate
	# (info_font, info_code)			= IconSymbol InfoIcon
	# (recycle_font, recycle_code)		= IconSymbol RecycleIcon
	# (prove_font, prove_code)			= IconSymbol ProveIcon
	# (rename_font, rename_code)		= IconSymbol RenameIcon
	# (move_font, move_code)			= IconSymbol MoveIcon
	# (remove_icon, remove_code)		= IconSymbol RemoveIcon
	= show info_font info_code recycle_font recycle_code prove_font prove_code rename_font rename_code move_font move_code remove_icon remove_code infos pstate
	where
		show :: !CName !Int !CName !Int !CName !Int !CName !Int !CName !Int !CName !Int ![TheoremInfo] !*PState -> (!MarkUpText WindowCommand, !*PState)
		show info_font info_code recycle_font recycle_code prove_font prove_code rename_font rename_code move_font move_code remove_font remove_code [info:infos] pstate
			# (fforalls, frule, pstate)	= showProp info.tiInitial pstate
			# fstart_icons				=	[ CmFontFace			info_font
											, CmLink2				0 {toChar info_code} (CmdShowTheorem info.tiPointer)
											, CmEndFontFace
											, CmFontFace			recycle_font
											, CmLink2				0 {toChar recycle_code} (CmdShowTheoremsUsing info.tiPointer)
											, CmEndFontFace
											, CmFontFace			prove_font
											, CmLink2				0 {toChar prove_code} (CmdProve info.tiPointer)
											, CmEndFontFace
											]
			# fproved					=	[ CmFontFace			"Wingdings"
											, CmColour				MyGreen
											, CmText				{toChar 252}
											, CmEndColour
											, CmEndFontFace
											]
			# falmostproved				=	[ CmFontFace			"Webdings"
											, CmColour				Brown
											, CmText				{toChar 113}
											, CmEndColour
											, CmEndFontFace
											]
			# funproved					=	[ CmFontFace			"Wingdings"
											, CmColour				Red
											, CmText				{toChar 251}
											, CmEndColour
											, CmEndFontFace
											]
			# fstatus					= case (isMember info.tiPointer true) of
											True	-> fproved
											False	-> case info.tiProved of
														True	-> falmostproved
														False	-> funproved
			# fname						=	[ CmSpaces				1
											] ++ fstatus ++
											[ CmBold
											, CmLink2				1 info.tiName (CmdShowTheorem info.tiPointer)
											, CmEndBold
											]
			# fsection					=	[ CmAlign				"@SECTION"
											, CmSize				7
											, CmColour				Grey
											, CmIText				(" (" +++ info.tiSectionName +++ ")")
											, CmEndColour
											, CmEndSize
											]
			# fend_icons				= 	[ CmAlign				"@ICONS"
											, CmSpaces				1
											, CmFontFace			rename_font
											, CmLink2				0 {toChar rename_code} (CmdRenameTheorem info.tiPointer)
											, CmEndFontFace
											, CmFontFace			move_font
											, CmLink2				0 {toChar move_code} (CmdMoveTheorem info.tiPointer)
											, CmEndFontFace
											, CmFontFace			remove_font
											, CmLink2				2 {toChar remove_code} (CmdRemoveTheorem info.tiPointer)
											, CmEndFontFace
											]
			# finitial					=	[ CmAlign				"@INITIAL"
											, CmSpaces				2
											, CmColour				Grey
											, CmFontFace			"Courier New"
											, CmSize				8
											, CmText				"("
											: fforalls] ++
											[ CmText				(if (isEmpty fforalls) "" ".")
											, CmBold
											] ++ frule ++
											[ CmEndBold
											, CmText				")"
											, CmEndSize
											, CmEndFontFace
											, CmEndColour
											]
			# finitial					= case show_props of
											True	-> finitial
											False	-> []
			# ftheorem					= case show_sections of
											True	-> fstart_icons ++ fname ++ fsection ++ fend_icons ++ finitial ++ [CmNewlineI False 1 (Just bg)]
											False	-> fstart_icons ++ fname ++ fend_icons ++ finitial ++ [CmNewlineI False 1 (Just bg)]
			# (finfos, pstate)			= show info_font info_code recycle_font recycle_code prove_font prove_code rename_font rename_code move_font move_code remove_font remove_code infos pstate
			= (ftheorem ++ finfos, pstate)
		show _ _ _ _ _ _ _ _ _ _ _ _ [] pstate
			= ([], pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
showFilter :: !TheoremFilter !Int !Colour !*PState -> (!MarkUpText a, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
showFilter filter nr_defs bg pstate
	# fproved							= case filter.tfStatus of
											DontCare	->	[ CmText		"all theorems"
															]
											Proved		->	[ CmText		"all "
															, CmColour		MyGreen
															, CmBText		"proved"
															, CmEndColour
															, CmText		" theorems"
															]
											Unproved	->	[ CmText		"all "
															, CmColour		Red
															, CmBText		"unproved"
															, CmEndColour
															, CmText		" theorems"
															]
											
	# fkind								=	[ CmBText				"Showing: "
											, CmAlign				"@RHS"
											, CmBackgroundColour	(changeColour 10 bg)
											] ++ fproved ++
//											, CmText				"all theorems"
											[ CmIText				(" (" +++ toString nr_defs +++ ")")
											, CmFillLine
											, CmEndBackgroundColour
											]
	# (section_names, pstate)			= accHeaps (getPointerNames filter.tfSections) pstate
	# section_names						= sort section_names
	# fsections							=	[ CmRight
											, CmBText				"from: "
											, CmAlign				"@RHS"
											, CmBackgroundColour	(changeColour 10 bg)
											, CmText				(showWith ", " section_names)
											, CmFillLine
											, CmEndBackgroundColour
											]
	# fnamed							=	[ CmRight
											, CmBText				"named: "
											, CmAlign				"@RHS"
											, CmBackgroundColour	(changeColour 10 bg)
											, CmColour				Red
											, CmBText				(if filter.tfName.nfPositive "" "not ")
											, CmEndColour
											, CmText				{c \\ c <- filter.tfName.nfFilter}
											, CmFillLine
											, CmEndBackgroundColour
											]
	# fusing							= 	[ CmRight
											, CmBText				"using: "
											, CmAlign				"@RHS"
											, CmBackgroundColour	(changeColour 10 bg)
											, CmText				(showWith ", " filter.tfUsing)
											, CmFillLine
											, CmEndBackgroundColour
											]
	= (fkind ++ [CmNewlineI False 3 Nothing] ++ fsections ++ [CmNewlineI False 3 Nothing] ++ fnamed ++ [CmNewlineI False 3 Nothing] ++ fusing ++ [CmNewlineI False 3 Nothing], pstate)
















// ------------------------------------------------------------------------------------------------------------------------   
showTheorems :: !Bool !(Maybe TheoremFilter) !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
showTheorems check_duplicate Nothing pstate
	# filter							=	{ tfSections	= []
											, tfName		= {nfFilter = ['*'], nfPositive = True}
											, tfUsing		= []
											, tfStatus		= DontCare
											}
	# (mb_filter, pstate)				= changeFilter filter pstate
	| isNothing mb_filter				= pstate
	= showTheorems check_duplicate mb_filter pstate
showTheorems check_duplicate (Just filter) pstate
	# (ids, pstate)						= pstate!ls.stUnregisteredWindows
	# (opened, id, pstate)				= case check_duplicate of
											True	-> already_opened ids pstate
											False	-> (False, undef, pstate)
	| opened							= setActiveWindow id pstate
	# (id, rid, pstate)					= new_UnregisteredWindow "TheoremList" pstate
	# (extended_bg, pstate)				= pstate!ls.stDisplayOptions.optTheoremListWindowBG
	# bg								= toColour 0 extended_bg
	# (window, pstate)					= theWindow bg filter id rid pstate
	# lstate							=	{ lFilter		= filter
											, lTheorems		= []			// filled in in INIT of window
											, lShowProps	= False
											}
	# (_, pstate)						= openWindow lstate window pstate
	= pstate
	where
		already_opened :: ![(Id, RId WindowCommand,String)] !*PState -> (!Bool, Id, !*PState)
		already_opened [(id,rid,_): ids] pstate
			# (_, pstate)				= syncSend rid (CmdCheckTheoremFilter filter) pstate
			# (same, pstate)			= pstate!ls.stDuplicate
			| same						= (True, id, pstate)
			= already_opened ids pstate
		already_opened [] pstate
			= (False, undef, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
:: LState =
// ------------------------------------------------------------------------------------------------------------------------   
	{ lFilter							:: !TheoremFilter
	, lTheorems							:: ![TheoremPtr]
	, lShowProps						:: !Bool
	}

// ------------------------------------------------------------------------------------------------------------------------   
//theWindow :: !Colour !TheoremFilter !Id !(RId WindowCommand) !*PState -> (_, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
theWindow bg filter id rid pstate
	# (metrics, _)						= osDefaultWindowMetrics 42
	# (filter_rid, pstate)				= accPIO openRId pstate
	# (list_rid, pstate)				= accPIO openRId pstate
	# (sliders_bid, pstate)				= accPIO openButtonId pstate
	# (props_bid, pstate)				= accPIO openButtonId pstate
	# (change_bid, pstate)				= accPIO openButtonId pstate
	# the_controls						= controls filter_rid list_rid sliders_bid props_bid change_bid metrics
	# (real_size, pstate)				= controlSize the_controls True (Just (5,5)) (Just (5,5)) (Just (5,5)) pstate
	# (vector, pstate)					= placeWindow real_size pstate
	=	( Window "List of theorems"
			the_controls
			[ WindowId					id
			, WindowPos					(LeftTop, OffsetVector vector)
			, WindowClose				(noLS (close_UnregisteredWindow id))
			, WindowViewSize			real_size
			, WindowHMargin				5 5
			, WindowVMargin				5 5
			, WindowItemSpace			5 5
			, WindowLook				True (\_ {newFrame} -> seq [setPenColour bg, fill newFrame])
			, WindowInit				(receive filter_rid list_rid sliders_bid props_bid change_bid CmdRefreshAlways)
			]
		, pstate
		)
	where
		controls filter_rid list_rid sliders_bid props_bid change_bid metrics
			=		Receiver			rid (receive filter_rid list_rid sliders_bid props_bid change_bid)
											[]
				:+: MarkUpControl		[CmBText "?"]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	bg
											, MarkUpWidth				(302 + metrics.osmVSliderWidth)
											, MarkUpNrLinesI			4 9
											, MarkUpReceiver			filter_rid
											]
				  							[ ControlResize				(\current old new -> {w = current.w + new.w - old.w, h = current.h})
											]
				:+: boxedMarkUp			Black ResizeHorVer [CmIText "creating"]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpHScroll
											, MarkUpVScroll
											, MarkUpWidth				300
											, MarkUpHeight				400
											, MarkUpBackgroundColour	(changeColour 20 bg)
											, MarkUpReceiver			list_rid
											, MarkUpLinkStyle			False (changeColour (-20) bg) (changeColour 20 bg) False Blue (changeColour 20 bg)
											, MarkUpLinkStyle			False Black (changeColour 20 bg) False Blue (changeColour 20 bg)
											, MarkUpLinkStyle			False (changeColour (-20) bg) (changeColour 20 bg) False Red (changeColour 20 bg)
											, MarkUpEventHandler		(sendHandler rid)
											]
											[ ControlPos				(Left, zero)
											]
				:+: MarkUpButton		"change filter" bg (snd o asyncSend rid CmdChangeFilter) change_bid
											[ ControlPos				(Right, zero)
											]
				:+: MarkUpButton		"show propositions" bg (snd o asyncSend rid CmdTogglePropositions) props_bid
											[ ControlPos				(LeftOf (fst3 change_bid), zero)
											]
				:+: MarkUpButton		"reset sliders" bg (redrawMarkUpSliders list_rid) sliders_bid
											[ ControlPos				(LeftBottom, zero)
											]
		
//		refresh :: _ _ !Bool !TheoremFilter !*PState -> (![TheoremPtr], !*PState)
		refresh filter_rid list_rid show_props filter pstate
			# (extended_bg, pstate)		= pstate!ls.stDisplayOptions.optTheoremListWindowBG
			# bg						= toColour 0 extended_bg
			# (infos, pstate)			= getTheorems filter pstate
			# ptrs						= [info.tiPointer \\ info <- infos]
			# (true, false, pstate)		= areTheoremsProved ptrs [] [] pstate
			# infos						= sortBy (\i1 i2 -> i1.tiName < i2.tiName) infos
			# (ftheorems, pstate)		= showList (length filter.tfSections <> 1) show_props infos true false bg pstate
			# pstate					= changeMarkUpText list_rid ftheorems pstate
			# (ffilter, pstate)			= showFilter filter (length infos) bg pstate
			# pstate					= changeMarkUpText filter_rid ffilter pstate
			= (ptrs, pstate)
				
//		receive :: _ _ _ _ _ !WindowCommand !(!LState, !*PState) -> (!LState, !*PState)
		receive filter_rid list_rid _ _ _ CmdRefreshAlways (lstate, pstate)
			# (ptrs, pstate)			= refresh filter_rid list_rid lstate.lShowProps lstate.lFilter pstate
			# lstate					= {lstate & lTheorems = ptrs}
			= (lstate, pstate)
		receive filter_rid list_rid _ _ _ (CmdRefresh (ChangedProofStatus ptr)) (lstate, pstate)
			# (ptrs, pstate)			= refresh filter_rid list_rid lstate.lShowProps lstate.lFilter pstate
			# lstate					= {lstate & lTheorems = ptrs}
			= (lstate, pstate)
		receive filter_rid list_rid _ _ _ (CmdRefresh (CreatedTheorem ptr)) (lstate, pstate)
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# (in_filter, pstate)		= inFilter True theorem lstate.lFilter pstate
			| not in_filter				= (lstate, pstate)
			# (ptrs, pstate)			= refresh filter_rid list_rid lstate.lShowProps lstate.lFilter pstate
			# lstate					= {lstate & lTheorems = ptrs}
			= (lstate, pstate)
		receive filter_rid list_rid _ _ _ (CmdRefresh (MovedTheorem theorem_ptr section_ptr)) (lstate, pstate)
			# in_selection				= isMember theorem_ptr lstate.lTheorems
			# (theorem, pstate)			= accHeaps (readPointer theorem_ptr) pstate
			# (in_filter, pstate)		= inFilter True theorem lstate.lFilter pstate
			# update					= in_selection || in_filter
			| not update				= (lstate, pstate)
			# (ptrs, pstate)			= refresh filter_rid list_rid lstate.lShowProps lstate.lFilter pstate
			# lstate					= {lstate & lTheorems = ptrs}
			= (lstate, pstate)
		receive filter_rid list_rid _ _ _ (CmdRefresh (RemovedSection ptr)) (lstate, pstate)
			# have_to_remove			= lstate.lFilter.tfSections == [ptr]
			| have_to_remove			= (lstate, close_UnregisteredWindow id pstate)
			# in_selection				= isMember ptr lstate.lFilter.tfSections
			| not in_selection			= (lstate, pstate)
			# lstate					= {lstate & lFilter.tfSections = removeMember ptr lstate.lFilter.tfSections}
			# (ptrs, pstate)			= refresh filter_rid list_rid lstate.lShowProps lstate.lFilter pstate
			# lstate					= {lstate & lTheorems = ptrs}
			= (lstate, pstate)
		receive filter_rid list_rid _ _ _ (CmdRefresh (RemovedTheorem ptr)) (lstate, pstate)
			# in_selection				= isMember ptr lstate.lTheorems
			| not in_selection			= (lstate, pstate)
			# (ptrs, pstate)			= refresh filter_rid list_rid lstate.lShowProps lstate.lFilter pstate
			# lstate					= {lstate & lTheorems = ptrs}
			= (lstate, pstate)
		receive filter_rid list_rid _ _ _ (CmdRefresh (RenamedSection ptr)) (lstate, pstate)
			# in_filter					= isMember ptr lstate.lFilter.tfSections
			= case in_filter of
				True	-> (lstate, snd (refresh filter_rid list_rid lstate.lShowProps lstate.lFilter pstate))
				False	-> (lstate, pstate)
		receive filter_rid list_rid _ _ _ (CmdRefresh (RenamedTheorem ptr)) (lstate, pstate)
			# in_selection				= isMember ptr lstate.lTheorems
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# (in_filter, pstate)		= inFilter True theorem lstate.lFilter pstate
			# update					= in_selection || in_filter
			| not update				= (lstate, pstate)
			# (ptrs, pstate)			= refresh filter_rid list_rid lstate.lShowProps lstate.lFilter pstate
			# lstate					= {lstate & lTheorems = ptrs}
			= (lstate, pstate)
		receive filter_rid list_rid sliders_bid props_bid change_bid (CmdRefreshBackground old_bg new_bg) (lstate, pstate)
			# new_look					= \_ {newFrame} -> seq [setPenColour new_bg, fill newFrame]
			# pstate					= appPIO (setWindowLook id True (True, new_look)) pstate
			# pstate					= changeMarkUpColour filter_rid True old_bg new_bg pstate
			# pstate					= changeMarkUpColour filter_rid True (changeColour 10 old_bg) (changeColour 10 new_bg) pstate
			# pstate					= changeMarkUpColour list_rid False old_bg new_bg pstate
			# pstate					= changeMarkUpColour list_rid False (changeColour 20 old_bg) (changeColour 20 new_bg) pstate
			# pstate					= changeMarkUpColour list_rid False (changeColour (-20) old_bg) (changeColour (-20) new_bg) pstate
			# pstate					= changeMarkUpColour (snd3 sliders_bid) True old_bg new_bg pstate
			# pstate					= changeMarkUpColour (snd3 props_bid) True old_bg new_bg pstate
			# pstate					= changeMarkUpColour (snd3 change_bid) True old_bg new_bg pstate
			# (ptrs, pstate)			= refresh filter_rid list_rid lstate.lShowProps lstate.lFilter pstate
			# lstate					= {lstate & lTheorems = ptrs}
			= (lstate, pstate)
		
		receive filter_rid list_rid _ _ _ CmdChangeFilter (lstate, pstate)
			# (mb_filter, pstate)		= changeFilter lstate.lFilter pstate
			| isNothing mb_filter		= (lstate, pstate)
			# filter					= fromJust mb_filter
			# (ptrs, pstate)			= refresh filter_rid list_rid lstate.lShowProps filter pstate
			# lstate					= {lstate & lFilter = filter, lTheorems = ptrs}
			= (lstate, pstate)
		receive _ _ _ _ _ (CmdCheckTheoremFilter filter) (lstate, pstate)
			# pstate					= {pstate & ls.stDuplicate = filter == lstate.lFilter}
			= (lstate, pstate)
		receive _ _ _ _ _ (CmdMoveTheorem ptr) (lstate, pstate)
			# pstate					= moveTheorem ptr pstate
			= (lstate, pstate)
		receive _ _ _ _ _ (CmdProve ptr) (lstate, pstate)
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			= (lstate, openProof ptr theorem pstate)
		receive _ _ _ _ _ (CmdRemoveTheorem ptr) (lstate, pstate)
			# pstate					= removeTheorem ptr pstate
			= (lstate, pstate)
		receive _ _ _ _ _ (CmdRenameTheorem ptr) (lstate, pstate)
			# pstate					= renameTheorem ptr pstate
			= (lstate, pstate)
		receive _ _ _ _ _ (CmdShowTheorem ptr) (lstate, pstate)
			= (lstate, openTheorem ptr pstate)
		receive _ _ _ _ _ (CmdShowTheoremsUsing ptr) (lstate, pstate)
			# (all_sections, pstate)	= pstate!ls.stSections
			# (name, pstate)			= accHeaps (getPointerName ptr) pstate
			# new_filter				=	{ tfSections		= all_sections
											, tfName			= {nfFilter = ['*'], nfPositive = True}
											, tfUsing			= [name]
											, tfStatus			= DontCare
											}
			# pstate					= showTheorems False (Just new_filter) pstate
			= (lstate, pstate)
		receive filter_rid list_rid _ props_bid _ CmdTogglePropositions (lstate, pstate)
			# new_toggle				= not lstate.lShowProps
			# pstate					= case new_toggle of
											True	-> changeButtonText props_bid "hide propositions" pstate
											False	-> changeButtonText props_bid "show propositions" pstate
			# (ptrs, pstate)			= refresh filter_rid list_rid new_toggle lstate.lFilter pstate
			# lstate					= { lstate	& lTheorems			= ptrs
													, lShowProps		= new_toggle
										  }
			= (lstate, pstate)
		receive _ _ _ _ _ command (lstate, pstate)
			= (lstate, pstate)






















// ------------------------------------------------------------------------------------------------------------------------   
changeFilter :: !TheoremFilter !*PState -> (!Maybe TheoremFilter, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
changeFilter filter pstate
	# bgcolour							= getDialogBackgroundColour
	# (metrics, _)						= osDefaultWindowMetrics 42
	# (dialog_id, pstate)				= accPIO openId pstate
	# (dialog_rid, pstate)				= accPIO openRId pstate
	# (kinds_id, pstate)				= accPIO openId pstate
	# (sections_id, pstate)				= accPIO openId pstate
	# (sections_rid, pstate)			= accPIO openRId pstate
	# (name_id, pstate)					= accPIO openId pstate
	# (positive_id, pstate)				= accPIO openId pstate
	# (using_id, pstate)				= accPIO openId pstate
	# (status_id, pstate)				= accPIO openId pstate
	# (ok_id, pstate)					= accPIO openId pstate
	# (cancel_id, pstate)				= accPIO openId pstate
	# (fsections, pstate)				= showSections filter pstate
	# dialog							= filter_dialog dialog_id dialog_rid kinds_id sections_id sections_rid name_id positive_id using_id status_id ok_id cancel_id fsections bgcolour metrics
	# ((_, mb_mb_filter), pstate)		= openModalDialog (Just filter) dialog pstate
	= case mb_mb_filter of
		Nothing			-> (Nothing, pstate)
		Just mb_filter	-> (mb_filter, pstate)
	where
		filter_dialog dialog_id dialog_rid kinds_id sections_id sections_rid name_id positive_id using_id status_id ok_id cancel_id fsections bgcolour metrics
			= Dialog "Change theorem filter"
				(		Receiver		dialog_rid (receive sections_rid)
											[]
					:+: MarkUpControl	[CmBText "Showing:"]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	bgcolour
											]
											[]
					:+: boxedMarkUp		Black DoNotResize [CmText "all theorems"]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	White
											, MarkUpWidth				(300+metrics.osmVSliderWidth)
											]
											[ ControlId					kinds_id
											]
					:+: MarkUpControl	[ CmRight
										, CmBText						"from:"
										, CmAlign						"@END"
										, CmNewline
										, CmRight
										, CmSize						8
										, CmText						"["
										, CmLink						"add all" AddAllSections
										, CmText						"]"
										, CmAlign						"@END"
										, CmNewline
										, CmRight
										, CmText						"["
										, CmLink						"remove all" RemoveAllSections
										, CmText						"]"
										, CmAlign						"@END"
										, CmEndSize
										]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	bgcolour
											, MarkUpLinkStyle			False DarkGrey bgcolour False Blue bgcolour
											, MarkUpEventHandler		(sendHandler dialog_rid)
											]
											[ ControlPos				(LeftOf sections_id, zero)
											]
					:+: boxedMarkUp		Black DoNotResize fsections
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	White
											, MarkUpHScroll
											, MarkUpVScroll
											, MarkUpWidth				300
											, MarkUpHeight				400
											, MarkUpLinkStyle			False Black LightBlue False Blue LightBlue
											, MarkUpLinkStyle			False Black White False Blue White
											, MarkUpReceiver			sections_rid
											, MarkUpEventHandler		(sendHandler dialog_rid)
											]
											[ ControlPos				(Below kinds_id, zero)
											, ControlId					sections_id
											]
					:+: MarkUpControl	[CmBText "named:"]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	bgcolour
											]
											[ ControlPos				(LeftOf name_id, zero)
											]
					:+: EditControl		{c \\ c <- filter.tfName.nfFilter} (PixelWidth (300+metrics.osmVSliderWidth+2)) 1
											[ ControlPos				(Below sections_id, zero)
											, ControlId					name_id
											]
					:+:	MarkUpControl	[CmBText "mode:"]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	bgcolour
											]
											[ ControlPos				(LeftOf positive_id, zero)
											]
					:+:	PopUpControl	[("positive (all that pass the name filter)", id),
										 ("negative (all that do NOT pass the name filter)",id)] (if filter.tfName.nfPositive 1 2)
										 	[ ControlPos				(Below name_id, zero)
										 	, ControlId					positive_id
										 	, ControlWidth				(PixelWidth (300+metrics.osmVSliderWidth+2))
										 	]
					:+:	MarkUpControl	[CmBText "using:"]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	bgcolour
											]
											[ ControlPos				(LeftOf using_id, zero)
											]
					:+:	EditControl		(showWith " " filter.tfUsing) (PixelWidth (300+metrics.osmVSliderWidth+2)) 1
											[ ControlPos				(Below positive_id, zero)
											, ControlId					using_id
											]
					:+:	MarkUpControl	[CmBText "status:"]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	bgcolour
											]
											[ ControlPos				(LeftOf status_id, zero)
											]
					:+:	PopUpControl	[("all theorems (both proved and unproved)", id),
										 ("only proved theorems",id),
										 ("only unproved theorems",id)]
										 (case filter.tfStatus of
										 	DontCare	-> 1
										 	Proved		-> 2
										 	Unproved	-> 3
										 )
										 	[ ControlPos				(Below using_id, zero)
										 	, ControlId					status_id
										 	, ControlWidth				(PixelWidth (300+metrics.osmVSliderWidth+2))
										 	]
					:+: ButtonControl	"Ok"
											[ ControlId					ok_id
											, ControlPos				(Right, zero)
											, ControlFunction			(accept dialog_id name_id positive_id using_id status_id)
											]
					:+: ButtonControl	"Cancel"
											[ ControlId					cancel_id
											, ControlPos				(LeftOf ok_id, zero)
											, ControlFunction			(refuse dialog_id)
											, ControlHide
											]
				)
				[ WindowId				dialog_id
				, WindowClose			(refuse dialog_id)
				, WindowOk				ok_id
				, WindowCancel			cancel_id
				]
		
		refuse :: !Id !(!Maybe TheoremFilter, !*PState) -> (!Maybe TheoremFilter, !*PState)
		refuse dialog_id (_, pstate)
			= (Nothing, closeWindow dialog_id pstate)
		
		accept :: !Id !Id !Id !Id !Id !(!Maybe TheoremFilter, !*PState) -> (!Maybe TheoremFilter, !*PState)
		accept dialog_id name_id positive_id using_id status_id (Just filter, pstate)
			// wstate
			# (mb_wstate, pstate)		= accPIO (getWindow dialog_id) pstate
			| isNothing mb_wstate		= (Just filter, pstate)
			# wstate					= fromJust mb_wstate
			// named
			# (ok, mb_text)				= getControlText name_id wstate
			| not ok					= (Just filter, pstate)
			| isNothing mb_text			= (Just filter, pstate)
			# named						= fromJust mb_text
			// positive named?
			# (ok, mb_index)			= getPopUpControlSelection positive_id wstate
			| not ok					= (Just filter, pstate)
			| isNothing mb_index		= (Just filter, pstate)
			# positive_index			= fromJust mb_index
			// using
			# (ok, mb_text)				= getControlText using_id wstate
			| not ok					= (Just filter, pstate)
			| isNothing mb_text			= (Just filter, pstate)
			# using						= sort (separate (fromJust mb_text))
			// status
			# (ok, mb_index)			= getPopUpControlSelection status_id wstate
			| not ok					= (Just filter, pstate)
			| isNothing mb_index		= (Just filter, pstate)
			# status					= case (fromJust mb_index) of
											1	-> DontCare
											2	-> Proved
											3	-> Unproved
			// make filter
			# filter					= {filter	& tfName.nfFilter		= [c \\ c <-: named]
													, tfName.nfPositive		= (positive_index == 1)
													, tfUsing				= using
													, tfStatus				= status
										  }
//			# pstate					= snd (asyncSend window_rid (CmdSetDefinitionFilter filter) pstate)
			= (Just filter, closeWindow dialog_id pstate)
		
		receive :: !(RId (MarkUpMessage FilterCommand)) !FilterCommand !(!Maybe TheoremFilter, !*PState) -> (!Maybe TheoremFilter, !*PState)
		receive sections_rid (ChangeSectionStatus ptr) (Just filter, pstate)
			# sections					= change ptr filter.tfSections
			# filter					= {filter & tfSections = sections}
			# (fsections, pstate)		= showSections filter pstate
			# pstate					= changeMarkUpText sections_rid fsections pstate
			= (Just filter, pstate)
			where
				change :: !SectionPtr ![SectionPtr] -> [SectionPtr]
				change sec_ptr [ptr:ptrs]
					| sec_ptr == ptr
						= ptrs
						= [ptr: change sec_ptr ptrs]
				change sec_ptr []
					= [sec_ptr]
		receive sections_rid AddAllSections (Just filter, pstate)
			# (all_sections, pstate)	= pstate!ls.stSections
			# filter					= {filter & tfSections = all_sections}
			# (fsections, pstate)		= showSections filter pstate
			# pstate					= changeMarkUpText sections_rid fsections pstate
			= (Just filter, pstate)
		receive sections_rid RemoveAllSections (Just filter, pstate)
			# filter					= {filter & tfSections = []}
			# (fsections, pstate)		= showSections filter pstate
			# pstate					= changeMarkUpText sections_rid fsections pstate
			= (Just filter, pstate)
		receive sections_rid change (Just filter, pstate)
			= (Just filter, pstate)
		
		showSections :: !TheoremFilter !*PState -> (!MarkUpText FilterCommand, !*PState)
		showSections filter pstate
			# (all_ptrs, pstate)		= pstate!ls.stSections
			# (section_infos, pstate)	= show all_ptrs filter.tfSections pstate
			# section_infos				= sortBy (\(n1,_)(n2,_) -> n1 < n2) section_infos
			= (flatten (map snd section_infos), pstate)
			where
				show :: ![SectionPtr] ![SectionPtr] !*PState -> (![(CName, MarkUpText FilterCommand)], !*PState)
				show [ptr:ptrs] in_ptrs pstate
					# (name, pstate)	= accHeaps (getPointerName ptr) pstate
					# fsection			= case isMember ptr in_ptrs of
											True	->	[ CmBackgroundColour	LightBlue
														, CmColour				MyGreen
														, CmFontFace			"Wingdings"
														, CmBText				{toChar 252}
														, CmEndFontFace
														, CmEndColour
														, CmText				" "
														, CmLink2				0 name (ChangeSectionStatus ptr)
														, CmFillLine
														, CmEndBackgroundColour
														, CmNewlineI			False 1 Nothing
														]
											False	->	[ CmColour				White
														, CmFontFace			"Wingdings"
														, CmBText				{toChar 252}
														, CmEndFontFace
														, CmEndColour
														, CmText				" "
														, CmLink2				1 name (ChangeSectionStatus ptr)
														, CmNewlineI			False 1 Nothing
														]
					# info				= (name, fsection)
					# (infos, pstate)	= show ptrs in_ptrs pstate
					= ([info:infos], pstate)
				show [] _ pstate
					= ([], pstate)




















// -------------------------------------------------------------------------------------------------------------------------------------------------
moveTheorem :: !TheoremPtr !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
moveTheorem ptr pstate
	# (theorem, pstate)					= accHeaps (readPointer ptr) pstate
	# (section, pstate)					= accHeaps (readPointer theorem.thSection) pstate
	# (section_ptrs, pstate)			= pstate!ls.stSections
	# (section_names, pstate)			= accHeaps (getPointerNames section_ptrs) pstate
	# (section_ptrs, section_names)		= unzip (sortBy (\(_,n1)(_,n2) -> n1<n2) (zip2 section_ptrs section_names))
	# (dialog_id, pstate)				= accPIO openId pstate
	# (edit_id, pstate)					= accPIO openId pstate
	# (ok_id, pstate)					= accPIO openId pstate
	# (cancel_id, pstate)				= accPIO openId pstate
	= snd (openModalDialog 0 (dialog theorem.thName section.seName section_ptrs section_names dialog_id edit_id ok_id cancel_id) pstate)
	where
		dialog theorem_name old_section_name section_ptrs section_names dialog_id edit_id ok_id cancel_id
			= Dialog "Move Theorem"
				(     MarkUpControl		[CmText "Move theorem ", CmBText theorem_name, CmText " from section ", CmBText old_section_name, CmText " to"]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	getDialogBackgroundColour
											]
											[]
				  :+: PopUpControl		[(name,id) \\ name <- section_names] 1
				  							[ ControlId			edit_id
				  							]
				  :+: ButtonControl		"Ok"
				  							[ ControlPos		(Right, zero)
				  							, ControlId			ok_id
				  							, ControlFunction	(noLS (accept section_ptrs dialog_id edit_id))
				  							]
				  :+: ButtonControl		"Cancel"
				  							[ ControlPos		(LeftTop, zero)
				  							, ControlId			cancel_id
				  							, ControlFunction	(noLS (closeWindow dialog_id))
				  							, ControlHide
				  							]
				)
				[ WindowId				dialog_id
				, WindowClose			(noLS (closeWindow dialog_id))
				, WindowOk				ok_id
				, WindowCancel			cancel_id
				]
		
		accept :: ![SectionPtr] !Id !Id !*PState -> *PState
		accept section_ptrs dialog_id edit_id pstate
			# (mb_wstate, pstate)		= accPIO (getWindow dialog_id) pstate
			| isNothing mb_wstate		= pstate
			# wstate					= fromJust mb_wstate
			# (ok, mb_index)			= getPopUpControlSelection edit_id wstate
			| not ok					= pstate
			| isNothing mb_index		= pstate
			# index						= fromJust mb_index
			# new_section_ptr			= section_ptrs !! (index - 1)
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# old_section_ptr			= theorem.thSection
			# theorem					= {theorem & thSection = new_section_ptr}
			# pstate					= appHeaps (writePointer ptr theorem) pstate
			# (old_section, pstate)		= accHeaps (readPointer old_section_ptr) pstate
			# old_section				= {old_section & seTheorems = removeMember ptr old_section.seTheorems}
			# pstate					= appHeaps (writePointer old_section_ptr old_section) pstate
			# (new_section, pstate)		= accHeaps (readPointer new_section_ptr) pstate
			# new_section				= {new_section & seTheorems = [ptr:new_section.seTheorems]}
			# pstate					= appHeaps (writePointer new_section_ptr new_section) pstate
			# pstate					= broadcast Nothing (MovedTheorem ptr new_section_ptr) pstate
			= closeWindow dialog_id pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
renameTheorem :: !TheoremPtr !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
renameTheorem ptr pstate
	# (theorem, pstate)					= accHeaps (readPointer ptr) pstate
	# (dialog_id, pstate)				= accPIO openId pstate
	# (edit_id, pstate)					= accPIO openId pstate
	# (ok_id, pstate)					= accPIO openId pstate
	# (cancel_id, pstate)				= accPIO openId pstate
	= snd (openModalDialog 0 (dialog theorem.thName dialog_id edit_id ok_id cancel_id) pstate)
	where
		dialog old_name dialog_id edit_id ok_id cancel_id
			= Dialog "Rename Theorem"
				(     MarkUpControl		[CmText "Rename theorem ", CmBText old_name, CmText " to"]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	getDialogBackgroundColour
											]
											[]
				  :+: EditControl		old_name (PixelWidth 320) 1
				  							[ ControlId			edit_id
				  							]
				  :+: ButtonControl		"Ok"
				  							[ ControlPos		(Right, zero)
				  							, ControlId			ok_id
				  							, ControlFunction	(noLS (accept dialog_id edit_id))
				  							]
				  :+: ButtonControl		"Cancel"
				  							[ ControlPos		(LeftTop, zero)
				  							, ControlId			cancel_id
				  							, ControlFunction	(noLS (closeWindow dialog_id))
				  							, ControlHide
				  							]
				)
				[ WindowId				dialog_id
				, WindowClose			(noLS (closeWindow dialog_id))
				, WindowOk				ok_id
				, WindowCancel			cancel_id
				]
		
		accept :: !Id !Id !*PState -> *PState
		accept dialog_id edit_id pstate
			# (mb_wstate, pstate)		= accPIO (getWindow dialog_id) pstate
			| isNothing mb_wstate		= pstate
			# wstate					= fromJust mb_wstate
			# (ok, mb_text)				= getControlText edit_id wstate
			| not ok					= pstate
			| isNothing mb_text			= pstate
			# text						= fromJust mb_text
			| text == ""				= setActiveControl edit_id (showError (pushError (X_Internal "Invalid (empty) name.") OK) pstate)
			# check						= and [isValidNameChar c \\ c <-: text]
			| not check					= setActiveControl edit_id (showError (pushError (X_Internal "Invalid (illegal characters) name.") OK) pstate)
			# (all_ptrs, pstate)		= allTheorems pstate
			# all_ptrs					= removeMember ptr all_ptrs
			# (all_names, pstate)		= accHeaps (getPointerNames all_ptrs) pstate
			| isMember text all_names	= setActiveControl edit_id (showError (pushError (X_Internal "Invalid (duplicate) name.") OK) pstate)
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# theorem					= {theorem & thName = text}
			# pstate					= appHeaps (writePointer ptr theorem) pstate
			# pstate					= broadcast Nothing (RenamedTheorem ptr) pstate
			= closeWindow dialog_id pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
removeTheorem :: !TheoremPtr !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
removeTheorem ptr pstate
	# (theorem, pstate)					= accHeaps (readPointer ptr) pstate
	# (used_by, pstate)					= theoremsUsingTheorem ptr pstate
	| not (isEmpty used_by)
		# (theorem, pstate)				= accHeaps (readPointer (hd used_by)) pstate
		= showError [X_RemoveTheorem theorem.thName ("used by theorem " +++ theorem.thName)] pstate
	# frectify							= [CmText "Remove theorem ", CmBText theorem.thName, CmText " from memory?"]
	# (ok, pstate)						= rectifyDialog frectify pstate
	| not ok							= pstate
	# (section, pstate)					= accHeaps (readPointer theorem.thSection) pstate
	# section							= {section & seTheorems = removeMember ptr section.seTheorems}
	# pstate							= appHeaps (writePointer theorem.thSection section) pstate
	# pstate							= setTheoremHint True ptr DummyValue Nothing pstate
	# pstate							= broadcast Nothing (RemovedTheorem ptr) pstate
	= pstate