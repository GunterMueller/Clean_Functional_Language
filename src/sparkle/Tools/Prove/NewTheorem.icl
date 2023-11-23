/*
** Program: Clean Prover System
** Module:  NewTheorem (.icl)
** 
** Author:  Maarten de Mol
** Created: 30 October 2000
*/

implementation module 
	NewTheorem

import 
	StdEnv,
	StdIO,
	States,
	ShowTheorem,
	ShowSection,
	Operate,
	BindLexeme,
	FileMonad

// -------------------------------------------------------------------------------------------------------------------------------------------------
newTheorem :: !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
newTheorem pstate
	# (opened, pstate)			= isWindowOpened DlgNewTheorem True pstate
	| opened					= pstate
	# (winfo, pstate)			= new_Window DlgNewTheorem pstate
	# dialog_id					= winfo.wiWindowId
	# (dialog, pstate)			= NewTheoremDLG dialog_id pstate
	= snd (openModalDialog Nothing dialog pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
// NewTheoremDLG :: !Id !*PState -> (_, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
NewTheoremDLG own_id pstate
	# (name_id, pstate)			= accPIO openId pstate
	# (section_id, pstate)		= accPIO openId pstate
	# (prop_id, pstate)			= accPIO openId pstate
	# (section_ptrs, pstate)	= pstate!ls.stSections
	# (section_names, pstate)	= accHeaps (getPointerNames section_ptrs) pstate
	# section_infos				= sortBy (\(p1,n1)(p2,n2) -> n1<n2) (zip2 section_ptrs section_names)
	= ( Dialog "New Theorem" (
		    TextControl			"Enter name for new theorem:" []
		:+: EditControl			"" (PixelWidth 400) 1
									[ ControlId			name_id
									, ControlPos		(Left, zero)
									]
		:+: TextControl			"Create theorem in section:"
									[ ControlPos		(Left, zero)
									]
		:+: PopUpControl		[(name,id) \\ (ptr,name) <- section_infos] (find_main_index 1 section_infos)
									[ ControlId			section_id
									]
		:+: TextControl			"Enter initial proposition for new theorem: "
									[ ControlPos		(Left, zero)
									]
		:+: EditControl			"" (PixelWidth 400) 10
									[ ControlId			prop_id
									, ControlPos		(Left, zero)
									]
		:+: ButtonControl		"Create Theorem"
									[ ControlFunction	(noLS (create_theorem name_id section_id prop_id section_infos))
									, ControlPos		(Right, zero)
									]
		)
		[ WindowId				own_id
		, WindowClose			(noLS (close_Window DlgNewTheorem))
		]
	  , pstate)
	where
		find_main_index :: !Int ![(SectionPtr,CName)] -> Int
		find_main_index index [info:infos]
			| snd info == "main"			= index
			= find_main_index (index+1) infos
		find_main_index _ []
			= -1
	
		create_theorem :: !Id !Id !Id ![(SectionPtr,CName)] !*PState -> *PState
		create_theorem name_id section_id prop_id section_infos pstate
			# (mb_wstate, pstate)			= accPIO (getWindow own_id) pstate
			| isNothing mb_wstate			= pstate
			# wstate						= fromJust mb_wstate
			# (ok, mb_text)					= getControlText prop_id wstate
			| not ok || isNothing mb_text	= pstate
			# text							= fromJust mb_text
			# (error, prop, pstate)			= accErrorHeapsProject (buildProp text) pstate
			| isError error					= showError error pstate
			# (fresh_prop, pstate)			= accHeaps (FreshVars prop) pstate
			# (ok, mb_title)				= getControlText name_id wstate
			| not ok || isNothing mb_title	= pstate
			# title							= fromJust mb_title
			| title == ""					= setActiveControl name_id (showError (pushError (X_Internal "Invalid (empty) name.") OK) pstate)
			# check							= and [isValidNameChar c \\ c <-: title]
			| not check						= setActiveControl name_id (showError (pushError (X_Internal "Invalid (illegal characters) name.") OK) pstate)
			# (all_ptrs, pstate)			= allTheorems pstate
			# (all_names, pstate)			= accHeaps (getPointerNames all_ptrs) pstate
			| isMember title all_names		= setActiveControl name_id (showError (pushError (X_Internal "Invalid (duplicate) name.") OK) pstate)
			# (ok, mb_index)				= getPopUpControlSelection section_id wstate
			| not ok || isNothing mb_index	= pstate
			# index							= fromJust mb_index
			# (section_ptr, _)				= section_infos !! (index-1)
			# goal							= {DummyValue & glToProve = fresh_prop}
			# (used_symbols, pstate)		= accHeaps (GetUsedSymbols fresh_prop) pstate
			# (leaf, pstate)				= accHeaps (newPointer (ProofLeaf goal)) pstate
			# proof							=	{ pTree				= leaf
												, pLeafs			= [leaf]
												, pCurrentLeaf		= leaf
												, pCurrentGoal		= goal
												, pFoldedNodes		= []
												, pUsedTheorems		= []
												, pUsedSymbols		= used_symbols
												}
			# theorem						=	{ thName			= title
												, thInitial			= prop
												, thInitialText		= text
												, thProof			= proof
												, thSection			= section_ptr
												, thSubgoals		= False
												, thHintScore		= Nothing
												}
			# (theorem_ptr, pstate)			= accHeaps (newPointer theorem) pstate
			# (section, pstate)				= accHeaps (readPointer section_ptr) pstate
			# section						= {section & seTheorems = [theorem_ptr:section.seTheorems]}
			# pstate						= appHeaps (writePointer section_ptr section) pstate
			# pstate						= broadcast Nothing (CreatedTheorem theorem_ptr) pstate
			# pstate						= openTheorem theorem_ptr pstate
			= close_Window DlgNewTheorem pstate