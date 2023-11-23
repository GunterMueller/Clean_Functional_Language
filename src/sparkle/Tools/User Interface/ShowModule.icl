/*
** Program: Clean Prover System
** Module:  ShowModule (.icl)
** 
** Author:  Maarten de Mol
** Created: 28 February 2001
*/

implementation module
	ShowModule

import
	StdEnv,
	StdIO,
	ossystem,
	Depends,
	ShowTheorem,
	States,
	Predefined
from StdFunc import seq

// ------------------------------------------------------------------------------------------------------------------------
BG										:== RGB {r=220, g=170, b=120}
ControlBG1								:== RGB {r=240, g=190, b=140}
ControlBG2								:== RGB {r=250, g=200, b=150}
InfoBG									:== RGB {r=230, g=180, b=130}
IconFG									:== RGB {r=200, g=150, b=100}
// ------------------------------------------------------------------------------------------------------------------------



















// Nothing denotes the Predefined module
// ------------------------------------------------------------------------------------------------------------------------   
showModule :: !(Maybe ModulePtr) !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
showModule mb_ptr pstate
	# (opened, pstate)					= isWindowOpened (WinModule mb_ptr) True pstate
	| opened							= pstate
	# (winfo, pstate)					= new_Window (WinModule mb_ptr) pstate
	# window_id							= winfo.wiWindowId
	# window_rid						= fromJust winfo.wiNormalRId
	# (info_rid, pstate)				= accPIO openRId pstate
	# properties_id						= fromJust winfo.wiControlId
	# (properties_rid, pstate)			= accPIO openRId pstate
	# pos								= winfo.wiStoredPos
	# width								= winfo.wiStoredWidth
	# height							= winfo.wiStoredHeight
	# (mod, pstate)						= case mb_ptr of
											(Just ptr)	-> accHeaps (readPointer ptr) pstate
											Nothing		-> (CPredefined, pstate)
	# (window, pstate)					= moduleWin pos width height mb_ptr mod window_id window_rid info_rid properties_id properties_rid pstate
	= snd (openWindow Nothing window pstate)

// ------------------------------------------------------------------------------------------------------------------------   
// moduleWin :: !Vector2 !Int !Int !(Maybe ModulePtr) !CModule !Id !(RId WindowCommand) _ !Id _ !*PState -> (_, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
moduleWin pos width height mb_mod_ptr mod window_id window_rid info_rid properties_id properties_rid pstate
	# mod_ptr							= if (isJust mb_mod_ptr) (fromJust mb_mod_ptr) nilPtr
	# (mod, pstate)						= case mb_mod_ptr of
											(Just ptr)	-> accHeaps (readPointer ptr) pstate
											Nothing		-> (CPredefined, pstate)
	# (metrics, _)						= osDefaultWindowMetrics 42
	# the_control						= controls metrics mod
	# (real_size, pstate)				= controlSize the_control True (Just(5,5)) (Just(5,5)) (Just(5,5)) pstate
	# (pos, pstate)						= case (pos.vx == (-1) && pos.vy == (-1)) of
											True	-> placeWindow real_size pstate
											False	-> (pos, pstate)
	=	( Window ("Module info (" +++ mod.pmName +++ ")") the_control
			[ WindowId					window_id
			, WindowClose				(noLS (close_Window (WinModule mb_mod_ptr)))
			, WindowHMargin				5 5
			, WindowVMargin				5 5
			, WindowItemSpace			5 5
			, WindowLook				True (\_ {newFrame} -> seq [setPenColour BG, fill newFrame])
			, WindowViewSize			real_size
			, WindowPos					(LeftTop, OffsetVector pos)
			, WindowInit				(noLS refresh)
			]
		, pstate
		)
	where
		controls metrics mod
			=		Receiver			window_rid receiver
											[]
				:+:	MarkUpControl		[CmText "?"]
											[ MarkUpFontFace				"Times New Roman"
											, MarkUpTextSize				10
											, MarkUpBackgroundColour		BG
											, MarkUpWidth					(width + metrics.osmVSliderWidth + 2)
											, MarkUpNrLinesI				5 12
											, MarkUpReceiver				info_rid
											, MarkUpLinkStyle				False IconFG InfoBG False Blue InfoBG
											, MarkUpLinkStyle				False IconFG InfoBG False Red InfoBG
											, MarkUpEventHandler			(clickHandler globalEventHandler)
											]
				  							[ ControlResize					(\current old new -> {w = current.w + new.w - old.w, h = current.h})
											]
				:+:	boxedMarkUp			Black ResizeHorVer [CmText "?"]
											[ MarkUpBackgroundColour		InfoBG
											, MarkUpFontFace				"Times New Roman"
											, MarkUpTextSize				10
											, MarkUpHScroll
											, MarkUpVScroll
											, MarkUpWidth					width
											, MarkUpHeight					height
											, MarkUpLinkStyle				False Black ControlBG1 False Blue ControlBG1
											, MarkUpLinkStyle				False Black ControlBG2 False Blue ControlBG2
											, MarkUpEventHandler			(clickHandler globalEventHandler)
											, MarkUpReceiver				properties_rid
											]
											[ ControlPos					(Left, zero)
											, ControlId						properties_id
											]
		
		refresh :: !*PState -> *PState
		refresh pstate
			# mod_ptr					= if (isJust mb_mod_ptr) (fromJust mb_mod_ptr) nilPtr
			# (mod, pstate)				= case mb_mod_ptr of
											(Just ptr)	-> accHeaps (readPointer ptr) pstate
											Nothing		-> (CPredefined, pstate)
			# (mod_ptrs, pstate)		= modulesUsingModule mod_ptr pstate
			# (theorem_ptrs, pstate)	= theoremsUsingModule mod_ptr pstate
			# finfo						= buildInfo mb_mod_ptr mod_ptrs theorem_ptrs mod
			# pstate					= changeMarkUpText info_rid finfo pstate
			# (fimports, pstate)		= buildImports mod.pmImportedModules pstate
			# (fimported_by, pstate)	= buildImportedBy mod_ptrs pstate
			# (fused, pstate)			= buildUsed theorem_ptrs pstate
			# pstate					= changeMarkUpText properties_rid (fimports ++ fimported_by ++ fused) pstate
			= pstate
		
		receiver :: !WindowCommand !(!a, !*PState) -> (!a, !*PState)
		receiver CmdRefreshAlways (lstate, pstate)
			= (lstate, refresh pstate)
		receiver (CmdRefresh (ChangedProof ptr)) (lstate, pstate)
			= (lstate, refresh pstate)
		receiver (CmdRefresh (RemovedCleanModules ptrs)) (lstate, pstate)
			| isNothing mb_mod_ptr		= (lstate, refresh pstate)
			# mod_ptr					= fromJust mb_mod_ptr
			| isMember mod_ptr ptrs		= (lstate, close_Window (WinModule mb_mod_ptr) pstate)
			= (lstate, refresh pstate)
		receiver (CmdRefresh (AddedCleanModules _)) (lstate, pstate)
			= (lstate, refresh pstate)
		receiver command (lstate, pstate)
			= (lstate, pstate)













// ------------------------------------------------------------------------------------------------------------------------   
buildInfo :: !(Maybe ModulePtr) ![ModulePtr] ![TheoremPtr] !CModule -> MarkUpText WindowCommand
// ------------------------------------------------------------------------------------------------------------------------   
buildInfo mb_mod_ptr mod_ptrs theorem_ptrs mod
	# (info_font, info_code)			= IconSymbol InfoIcon
	# (view_font, view_code)			= IconSymbol ViewContentsIcon
	# (remove_font, remove_code)		= IconSymbol RemoveIcon
	# remove							= case mb_mod_ptr of
											Nothing		-> []
											Just ptr	-> [CmLink2 1 {toChar remove_code} (CmdRemoveModule ptr)]
	# fname								=	[ CmRight
											, CmBText				"Module:"
											, CmSpaces				1
											, CmAlign				"@RHS"
											, CmBackgroundColour	InfoBG
											, CmText				mod.pmName
											, CmSpaces 				1
											, CmFontFace			view_font
											, CmLink2				0 {toChar view_code} (CmdShowModuleContents mb_mod_ptr)
											, CmEndFontFace
											, CmFontFace			remove_font
											] ++ remove ++
											[ CmEndFontFace
											, CmFillLine
											, CmEndBackgroundColour
											]
	# fpath								=	[ CmRight
											, CmBText				"in path:"
											, CmSpaces				1
											, CmAlign				"@RHS"
											, CmBackgroundColour	InfoBG
											, CmText				mod.pmPath
											, CmFillLine
											, CmEndBackgroundColour
											]
	# nr_imports						= length mod.pmImportedModules
	# fimports							=	[ CmRight
											, CmBText				"imports:"
											, CmSpaces				1
											, CmAlign				"@RHS"
											, CmBackgroundColour	InfoBG
											, CmText				(mul_text nr_imports "module")
											, CmIText				" (see below)"
											, CmFillLine
											, CmEndBackgroundColour
											]
	# nr_imported_by					= length mod_ptrs
	# fimported_by						=	[ CmRight
											, CmBText				"imported by:"
											, CmSpaces				1
											, CmAlign				"@RHS"
											, CmBackgroundColour	InfoBG
											, CmText				(mul_text nr_imported_by "module")
											, CmIText				" (see below)"
											, CmFillLine
											, CmEndBackgroundColour
											]
	# nr_theorems_using					= length theorem_ptrs
	# ftheorems_using					=	[ CmRight
											, CmBText				"used in:"
											, CmSpaces				1
											, CmAlign				"@RHS"
											, CmBackgroundColour	InfoBG
											, CmText				(mul_text nr_theorems_using "theorem")
											, CmIText				" (see below)"
											, CmFillLine
											, CmEndBackgroundColour
											]
	= fname ++ [CmNewlineI False 3 Nothing] ++ fpath ++ [CmNewlineI False 3 Nothing] ++ fimports ++ [CmNewlineI False 3 Nothing] ++ fimported_by ++ [CmNewlineI False 3 Nothing] ++ ftheorems_using
	where
		mul_text :: !Int !String -> String
		mul_text 1 text
			= "1 " +++ text
		mul_text n text
			= toString n +++ " " +++ text +++ "s"

// ------------------------------------------------------------------------------------------------------------------------   
buildImports :: ![ModulePtr] !*PState -> (!MarkUpText WindowCommand, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
buildImports ptrs pstate
	| isEmpty ptrs						= (	[ CmBackgroundColour		ControlBG1
											, CmSpaces					1
											, CmFontFace				"Wingdings"
											, CmText					{toChar 159}
											, CmEndFontFace
											, CmSpaces					1
											, CmIText					"imports no modules"
											, CmFillLine
											, CmEndBackgroundColour
											, CmNewlineI				False 1 Nothing
											], pstate)
	# (names, pstate)					= accHeaps (getPointerNames ptrs) pstate
	# fmodules							= show names ptrs
	= (fmodules, pstate)
	where
		show :: ![CName] ![ModulePtr] -> MarkUpText WindowCommand
		show [name:names] [ptr:ptrs]
			=	[ CmBackgroundColour	ControlBG1
				, CmSpaces				1
				, CmFontFace			"Wingdings"
				, CmText				{toChar 159}
				, CmEndFontFace
				, CmSpaces				1
				, CmText				"imports module "
				, CmBold
				, CmLink2				0 name (CmdShowModule (Just ptr))
				, CmEndBold
				, CmFillLine
				, CmEndBackgroundColour
				, CmNewlineI			False 1 Nothing
				: show names ptrs
				]
		show [] []
			= []

// ------------------------------------------------------------------------------------------------------------------------   
buildImportedBy :: ![ModulePtr] !*PState -> (!MarkUpText WindowCommand, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
buildImportedBy ptrs pstate
	| isEmpty ptrs						= (	[ CmBackgroundColour		ControlBG2
											, CmSpaces					1
											, CmFontFace				"Wingdings"
											, CmText					{toChar 159}
											, CmEndFontFace
											, CmSpaces					1
											, CmIText					"not imported by any module"
											, CmFillLine
											, CmEndBackgroundColour
											, CmNewlineI				False 1 Nothing
											], pstate)
	# (names, pstate)					= accHeaps (getPointerNames ptrs) pstate
	# fmodules							= show names ptrs
	= (fmodules, pstate)
	where
		show :: ![CName] ![ModulePtr] -> MarkUpText WindowCommand
		show [name:names] [ptr:ptrs]
			=	[ CmBackgroundColour	ControlBG2
				, CmSpaces				1
				, CmFontFace			"Wingdings"
				, CmText				{toChar 159}
				, CmEndFontFace
				, CmSpaces				1
				, CmText				"imported by module "
				, CmBold
				, CmLink2				1 name (CmdShowModule (Just ptr))
				, CmEndBold
				, CmFillLine
				, CmEndBackgroundColour
				, CmNewlineI			False 1 Nothing
				: show names ptrs
				]
		show [] []
			= []

// ------------------------------------------------------------------------------------------------------------------------   
buildUsed :: ![TheoremPtr] !*PState -> (!MarkUpText WindowCommand, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
buildUsed ptrs pstate
	| isEmpty ptrs						= (	[ CmBackgroundColour		ControlBG1
											, CmSpaces					1
											, CmFontFace				"Wingdings"
											, CmText					{toChar 159}
											, CmEndFontFace
											, CmSpaces					1
											, CmIText					"not used in any theorem"
											, CmFillLine
											, CmEndBackgroundColour
											, CmNewlineI				False 1 Nothing
											], pstate)
	# (names, pstate)					= accHeaps (getPointerNames ptrs) pstate
	# ftheorems							= show names ptrs
	= (ftheorems, pstate)
	where
		show :: ![CName] ![TheoremPtr] -> MarkUpText WindowCommand
		show [name:names] [ptr:ptrs]
			=	[ CmBackgroundColour	ControlBG1
				, CmSpaces				1
				, CmFontFace			"Wingdings"
				, CmText				{toChar 159}
				, CmEndFontFace
				, CmSpaces				1
				, CmText				"used in theorem "
				, CmBold
				, CmLink2				0 name (CmdShowTheorem ptr)
				, CmEndBold
				, CmFillLine
				, CmEndBackgroundColour
				, CmNewlineI			False 1 Nothing
				: show names ptrs
				]
		show [] []
			= []