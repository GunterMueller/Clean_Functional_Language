/*
** Program: Clean Prover System
** Module:  MenuBar (.icl)
** 
** Author:  Maarten de Mol
** Created: 26 May 1999
*/

implementation module 
   MenuBar

import 
   StdEnv,
   StdIO,
   StatusDialog,
   States,
   AddModule,
   RemoveModules,
   OpenProject,
   OptionsMonad,
   SelectColour,
   ShowDefinition,
   ShowDefinitions,
   ShowTheorems,
   ShowProof,
   Hints,
   Interpret,
   NewTheorem,
   SectionCenter,
   TacticList,
   ProjectCenter,
   StoreSection
from StdFunc import seq

// ------------------------------------------------------------------------------------------------------------------------   
:: Option =
// ------------------------------------------------------------------------------------------------------------------------   
	// display options  
	  OptShowRecordFuns
	| OptShowRecordCreation
	| OptShowArrayFuns
	| OptShowTupleFuns
	| OptShowDictionaries
	| OptShowInstanceTypes
	| OptShowVariableIndexes
	| OptShowPatterns
	| OptShowLetsAndCases
	| OptShowSharing
	| OptShowIndents
	| OptAlwaysBrackets
	| OptShowIsTrue
	| OptExtendedForalls
	// other options
	| OptDisplaySpecial
	| OptAutomaticDiscard

// ------------------------------------------------------------------------------------------------------------------------   
changeOption :: !Option !Bool !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
changeOption OptShowRecordFuns		state pstate	= refresh {pstate & ls.stDisplayOptions.optShowRecordFuns		= state}
changeOption OptShowRecordCreation	state pstate	= refresh {pstate & ls.stDisplayOptions.optShowRecordCreation	= state}
changeOption OptShowArrayFuns		state pstate	= refresh {pstate & ls.stDisplayOptions.optShowArrayFuns		= state}
changeOption OptShowTupleFuns		state pstate	= refresh {pstate & ls.stDisplayOptions.optShowTupleFuns		= state}
changeOption OptShowDictionaries	state pstate	= refresh {pstate & ls.stDisplayOptions.optShowDictionaries		= state}
changeOption OptShowInstanceTypes	state pstate	= refresh {pstate & ls.stDisplayOptions.optShowInstanceTypes	= state}
changeOption OptShowVariableIndexes	state pstate	= refresh {pstate & ls.stDisplayOptions.optShowVariableIndexes	= state}
changeOption OptShowPatterns		state pstate	= refresh {pstate & ls.stDisplayOptions.optShowPatterns			= state}
changeOption OptShowLetsAndCases	state pstate	= refresh {pstate & ls.stDisplayOptions.optShowLetsAndCases		= state}
changeOption OptShowSharing			state pstate	= refresh {pstate & ls.stDisplayOptions.optShowSharing			= state}
changeOption OptShowIndents			state pstate	= refresh {pstate & ls.stDisplayOptions.optShowIndents			= state}
changeOption OptAlwaysBrackets		state pstate	= refresh {pstate & ls.stDisplayOptions.optAlwaysBrackets		= state}
changeOption OptShowIsTrue			state pstate	= refresh {pstate & ls.stDisplayOptions.optShowIsTrue			= state}
changeOption OptExtendedForalls		state pstate	= refresh {pstate & ls.stDisplayOptions.optExtendedForalls		= state}

changeOption OptDisplaySpecial	 	True  pstate	= refresh (setDisplaySpecial pstate)
changeOption OptDisplaySpecial	 	False pstate	= refresh (unsetDisplaySpecial pstate)
changeOption OptAutomaticDiscard	state pstate	= {pstate & ls.stOptions.optAutomaticDiscard = state}

// ------------------------------------------------------------------------------------------------------------------------   
getOption :: !Option !DisplayOptions !Options -> Bool
// ------------------------------------------------------------------------------------------------------------------------   
getOption OptShowRecordFuns		d_options	options	= d_options.optShowRecordFuns
getOption OptShowRecordCreation	d_options	options	= d_options.optShowRecordCreation
getOption OptShowArrayFuns		d_options	options	= d_options.optShowArrayFuns
getOption OptShowTupleFuns		d_options	options	= d_options.optShowTupleFuns
getOption OptShowDictionaries	d_options	options	= d_options.optShowDictionaries
getOption OptShowInstanceTypes	d_options	options	= d_options.optShowInstanceTypes
getOption OptShowVariableIndexes d_options	options	= d_options.optShowVariableIndexes
getOption OptShowPatterns		d_options	options	= d_options.optShowPatterns
getOption OptShowLetsAndCases	d_options	options	= d_options.optShowLetsAndCases
getOption OptShowSharing		d_options	options	= d_options.optShowSharing
getOption OptShowIndents		d_options	options	= d_options.optShowIndents
getOption OptAlwaysBrackets		d_options	options	= d_options.optAlwaysBrackets
getOption OptShowIsTrue			d_options	options	= d_options.optShowIsTrue
getOption OptExtendedForalls	d_options	options	= d_options.optExtendedForalls

getOption OptDisplaySpecial		d_options	options	= options.optDisplaySpecial
getOption OptAutomaticDiscard	d_options	options	= options.optAutomaticDiscard

// ------------------------------------------------------------------------------------------------------------------------   
showOption :: !Option !Bool -> String
// ------------------------------------------------------------------------------------------------------------------------   
showOption OptShowRecordFuns		True			= "use explicit record select and update functions"
showOption OptShowRecordFuns		False			= "use '.' and '{..}' to display record selection and update"
showOption OptShowRecordCreation	True			= "use explicit record create functions"
showOption OptShowRecordCreation	False			= "use '{..}' to display record creation"
showOption OptShowArrayFuns			True			= "use explicit array select and update functions"
showOption OptShowArrayFuns			False			= "use '.' and '{..}' to display array selection and update"
showOption OptShowTupleFuns			True			= "use explicit functions to select elements from tuples in lets"
showOption OptShowTupleFuns			False			= "use (_, .., _) = tuple to select elements from tuples in lets"
showOption OptShowDictionaries		True			= "show dictionaries"
showOption OptShowDictionaries		False			= "hide dictionaries"
showOption OptShowInstanceTypes		True			= "show a suffix showing the instantiated types of an instance function"
showOption OptShowInstanceTypes		False			= "instance functions have the same name as the class members"
showOption OptShowVariableIndexes	True			= "show variable indexes"
showOption OptShowVariableIndexes	False			= "hide variable indexes"
showOption OptShowPatterns			True			= "show functions using pattern matching"
showOption OptShowPatterns			False			= "show functions using case expressions"
showOption OptShowLetsAndCases		True			= "show functions using let and case"
showOption OptShowLetsAndCases		False			= "show functions using '#' and '|'"
showOption OptShowSharing			True			= "show sharing"
showOption OptShowSharing			False			= "hide sharing"
showOption OptShowIndents			True			= "show |-bars in theorem window"
showOption OptShowIndents			False			= "hide |-bars in theorem window"
showOption OptAlwaysBrackets		True			= "always print brackets"
showOption OptAlwaysBrackets		False			= "minimize brackets using priorities of operators"
showOption OptShowIsTrue			True			= "always show 'expr = True'"
showOption OptShowIsTrue			False			= "pretty print 'expr = True' to 'expr'"
showOption OptExtendedForalls		True			= "pretty print logical operators"
showOption OptExtendedForalls		False			= "disable pretty printing of logical operators"

showOption OptDisplaySpecial		True			= "use symbols to denote quantors, operators etc."
showOption OptDisplaySpecial		False			= "use ASCII to denote quantors, operators, etc."
showOption OptAutomaticDiscard		True			= "automatically discard unused variables"
showOption OptAutomaticDiscard		False			= "never automatically discard variables"

// ------------------------------------------------------------------------------------------------------------------------   
//optionMenu :: !Option !DisplayOptions !Options -> _
// ------------------------------------------------------------------------------------------------------------------------   
optionMenu option d_options options
	= RadioMenu
		[ (showOption option True,  Nothing, Nothing, noLS (changeOption option True))
		, (showOption option False, Nothing, Nothing, noLS (changeOption option False))
		] (if (getOption option d_options options) 1 2) []

// ------------------------------------------------------------------------------------------------------------------------   
refresh :: !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
refresh pstate
	= broadcast Nothing ChangedDisplayOption pstate









// ------------------------------------------------------------------------------------------------------------------------   
close_process :: !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
close_process pstate
	# pstate							= writeOptions pstate
	= closeProcess pstate









// ------------------------------------------------------------------------------------------------------------------------   
createMenuBar :: !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
createMenuBar pstate
	// Project Menu
	# (project_center_id, pstate)		= accPIO openId pstate
	# (open_project_id, pstate)			= accPIO openId pstate
	# (add_stdenv_id, pstate)			= accPIO openId pstate
	# (remove_modules_id, pstate)		= accPIO openId pstate
	# (remove_all_modules_id, pstate)	= accPIO openId pstate
	# (interpreter_id, pstate)			= accPIO openId pstate
	# (project_center_opened, pstate)	= isWindowOpened WinProjectCenter False pstate
	# (_, pstate)						= openMenu 0 (ProjectMenu project_center_id project_center_opened add_stdenv_id open_project_id remove_modules_id remove_all_modules_id interpreter_id) pstate
	# pstate							=	{pstate	& ls.stMenus.open_project_id		= open_project_id
													, ls.stMenus.add_stdenv_id			= add_stdenv_id
													, ls.stMenus.project_center_id		= project_center_id
													, ls.stMenus.remove_modules_id		= remove_modules_id
													, ls.stMenus.remove_all_modules_id	= remove_all_modules_id
													, ls.stMenus.interpreter_id			= interpreter_id
											}
	// Theorem Menu
	# (section_center_id, pstate)		= accPIO openId pstate
	# (save_sections_id, pstate)		= accPIO openId pstate
	# (suggestions_id, pstate)			= accPIO openId pstate
	# (section_center_opened, pstate)	= isWindowOpened WinSectionCenter False pstate
	# (_, pstate)						= openMenu 0 (TheoremMenu section_center_id section_center_opened save_sections_id suggestions_id) pstate
	# pstate							=	{pstate	& ls.stMenus.section_center_id		= section_center_id
													, ls.stMenus.save_sections_id		= save_sections_id
													, ls.stMenus.suggestions_id			= suggestions_id
											}
	// Tactics Menu
	# (list1_id, pstate)				= accPIO openId pstate
	# (list2_id, pstate)				= accPIO openId pstate
	# (list3_id, pstate)				= accPIO openId pstate
	# (list4_id, pstate)				= accPIO openId pstate
	# (list5_id, pstate)				= accPIO openId pstate
	# (filters, pstate)					= pstate!ls.stTacticFilters
	# (list1_opened, pstate)			= isWindowOpened (WinTacticList 1) False pstate
	# (list2_opened, pstate)			= isWindowOpened (WinTacticList 2) False pstate
	# (list3_opened, pstate)			= isWindowOpened (WinTacticList 3) False pstate
	# (list4_opened, pstate)			= isWindowOpened (WinTacticList 4) False pstate
	# (list5_opened, pstate)			= isWindowOpened (WinTacticList 5) False pstate
	# titles							= [filter.tfTitle \\ filter <- filters]
	# (_, pstate)						= openMenu 0 (TacticsMenu titles list1_id list1_opened list2_id list2_opened list3_id list3_opened list4_id list4_opened list5_id list5_opened) pstate
	# pstate							=	{pstate	& ls.stMenus.tactic_list_ids		= [list1_id, list2_id, list3_id, list4_id, list5_id]
											}
	// Options Menu
	# (id, pstate)						= accPIO openId pstate
	# (phase, pstate)					= pstate!ls.stFrontEndPhase
	# (displayoptions, pstate)			= pstate!ls.stDisplayOptions
	# (displayspecial, pstate)			= pstate!ls.stDisplaySpecial
	# (options, pstate)					= pstate!ls.stOptions
	# (_, pstate)						= openMenu 0 (OptionsMENU phase displayoptions options displayspecial id) pstate
	// Info Menu
	# (id, pstate)						= accPIO openId pstate
	# (_, pstate)						= openMenu 0 (InfoMENU id) pstate
	// Bookkeeping. Necessary to allow initial project windows (etc...) to be opened before the menubar.
	# pstate							= {pstate & ls.stMenuBarCreated = True}
	= pstate
















// ------------------------------------------------------------------------------------------------------------------------   
// ProjectMenu :: Id -> Menu _ TNoLocalState TState   
// ------------------------------------------------------------------------------------------------------------------------   
ProjectMenu project_center_id project_center_opened open_project_id add_stdenv_id remove_modules_id remove_all_modules_id interpreter_id
	= Menu "&Project" 
		(		MenuItem		"Project Center"
									[ MenuFunction		(noLS toggleProjectCenter)
									, MenuMarkState		(if project_center_opened Mark NoMark)
									, MenuId			project_center_id
									]
			:+:	MenuSeparator	[]
			:+:	MenuItem		"Open Project"
									[ MenuFunction		(noLS (catchError openProject))
									, MenuId			open_project_id
									, MenuShortKey		'o'
									]
			:+:	MenuItem		"Add StdEnv"
									[ MenuId			add_stdenv_id
									, MenuFunction		(noLS add_stdenv)
									, MenuShortKey		'e'
									]
			:+:	MenuItem		"Add Module"
									[ MenuFunction		(noLS addModule)
									, MenuShortKey		'+'
									]
			:+:	MenuItem		"Remove Modules"
									[ MenuFunction		(noLS (removeModules False []))
									, MenuId			remove_modules_id
									, MenuSelectState	Unable
									]
			:+:	MenuItem		"Remove All Modules"
									[ MenuFunction		(noLS remove_all)
									, MenuId			remove_all_modules_id
									, MenuSelectState	Unable
									]
			:+:	MenuSeparator	[]
			:+:	MenuItem		"Interpreter"
									[ MenuFunction		(noLS toggleInterpreter)
									, MenuMarkState		NoMark
									, MenuId			interpreter_id
									, MenuShortKey		'i'
									]
			:+:	MenuItem		"Filtered Definition List"
									[ MenuFunction		(noLS list)
									]
			:+:	MenuSeparator	[]
			:+:	MenuItem		"Quit"
									[ MenuFunction		(noLS close_process)
									, MenuShortKey		'Q'
									]
		)
		[]
	where
		toggleInterpreter :: !*PState -> *PState
		toggleInterpreter pstate
			# (opened, pstate)				= isWindowOpened DlgInterpreter False pstate
			= case opened of
				True	-> close_Window DlgInterpreter pstate
				False	-> startInterpreter pstate
		
		toggleProjectCenter :: !*PState -> *PState
		toggleProjectCenter pstate
			# (opened, pstate)				= isWindowOpened WinProjectCenter False pstate
			= case opened of
				True	-> close_Window WinProjectCenter pstate
				False	-> openProjectCenter pstate
		
		list :: !*PState -> *PState
		list pstate
			= showDefinitions Nothing Nothing pstate
		
		remove_all :: !*PState -> *PState
		remove_all pstate
			# (ptrs, pstate)				= pstate!ls.stProject.prjModules
			= removeModules True ptrs pstate
		
		add_stdenv :: !*PState -> *PState
		add_stdenv pstate
			# path							= applicationpath ""
			# paths							= replace (split path 0 0 (size path-1))
			# path							= foldr (+++) "" paths
			# (exists, pstate)				= accPIO (accFiles (exists (path +++ "StdEnv.icl"))) pstate
			| not exists					= showError [X_OpenModule "StdEnv.icl", X_Internal ("Not found in path '" +++ path +++ "'.")] pstate
			= openStatusDialog "Adding standard environment" (addToProject [path] "StdEnv") pstate
			where
				split :: !String !Int !Int !Int -> [String]
				split path start_index index end_index
					| index == end_index	= [current]
					| path.[index] == '\\'	= [current: split path (index+1) (index+1) end_index]
					= split path start_index (index+1) end_index
					where
						current				= path%(start_index, index)
				
				// replace 'Tools/*' by 'Libraries/StdEnv Sparkle'
				// NOTE: as of version 0.0.4b, the version number no longer appears in the path
				replace :: ![String] -> [String]
				replace [path:paths]
					| path == "TOOLS\\"		= ["Libraries\\", "StdEnv Sparkle\\"]
					| path == "Tools\\"		= ["Libraries\\", "StdEnv Sparkle\\"]
					= [path: replace paths]
				replace []
					= []
				
				exists :: !String !*Files -> (!Bool, !*Files)
				exists name files
					# (ok, file, files)		= fopen name FReadText files
					| not ok				= (False, files)
					# (_, files)			= fclose file files
					= (True, files)

// ------------------------------------------------------------------------------------------------------------------------   
// TheoremMenu :: Ids -> Menu _ TNoLocalState TState   
// ------------------------------------------------------------------------------------------------------------------------   
TheoremMenu section_center_id section_center_opened save_sections_id suggestions_id
	= Menu "&Theorems" 
		(		MenuItem		"Section Center"
									[ MenuFunction		(noLS toggleSectionCenter)
									, MenuMarkState		(if section_center_opened Mark NoMark)
									, MenuId			section_center_id
									]
			:+:	MenuSeparator	[]
			:+:	MenuItem		"Load Section"
									[ MenuFunction		(noLS (restoreSection Nothing))
									, MenuShortKey		'L'
									]
//			:+:	MenuItem		"Save Changed Sections"
//									[ MenuSelectState	Unable
//									, MenuId			save_sections_id
//									]
			:+:	MenuItem		"New Section"
									[ MenuFunction		(noLS newSection)
									]
			:+:	MenuSeparator	[]
			:+:	MenuItem		"New Theorem"
									[ MenuShortKey		'N'
									, MenuFunction		(noLS newTheorem)
									]
			:+:	MenuItem		"Filtered Theorem List"
									[ MenuFunction		(noLS list)
									]
			:+:	MenuItem		"Definedness Theorem List"
									[ MenuFunction		(noLS (showDefinedness Nothing))
									, MenuShortKey		'D'
									]
			:+: MenuSeparator	[]
			:+: MenuItem		"Prove topmost theorem"
									[ MenuShortKey		'P'
									, MenuFunction		(noLS prove)
									]
			:+:	MenuItem		"Tactic suggestions window"
									[ MenuShortKey		'H'
									, MenuFunction		(noLS toggleSuggestionsWindow)
									, MenuId			suggestions_id
									, MenuMarkState		NoMark
									]
			:+:	MenuItem		"Undo last applied tactic"
									[ MenuShortKey		'Z'
									, MenuFunction		(noLS undo)
									]
			// To be implemented!
			:+:	MenuItem		"Focus on command line (to be implemented)"
									[ MenuShortKey		'C'
									, MenuFunction		(noLS focusOnCommandLine)
									]
		)
		[]
	where
		toggleSectionCenter :: !*PState -> *PState
		toggleSectionCenter pstate
			# (opened, pstate)				= isWindowOpened WinSectionCenter False pstate
			= case opened of
				True	-> close_Window WinSectionCenter pstate
				False	-> openSectionCenter pstate
		
		toggleSuggestionsWindow :: !*PState -> *PState
		toggleSuggestionsWindow pstate
			# (opened, pstate)				= isWindowOpened WinHints False pstate
			= case opened of
				True	-> close_Window WinHints pstate
				False	-> openHints pstate
		
		list :: !*PState -> *PState
		list pstate
			= showTheorems True Nothing pstate
		
		prove :: !*PState -> *PState
		prove pstate
			# (ids, pstate)					= accPIO getWindowsStack pstate
			# (winfos, pstate)				= pstate!ls.stWindows
			# mb_ptr						= finds ids winfos
			= case mb_ptr of
				(Just ptr)		-> let (theorem, pstate1) = accHeaps (readPointer ptr) pstate
									in openProof ptr theorem pstate1
				Nothing			-> let (opened, pstate1) = isWindowOpened (WinProof nilPtr) True pstate
									in case opened of
										True	-> let pstate2 = snd (isWindowOpened WinHints True pstate1)
													in snd (isWindowOpened (WinProof nilPtr) True pstate2)
										False	-> pstate1
			where
				finds :: ![Id] ![WindowInfo] -> Maybe TheoremPtr
				finds [id:ids] winfos
					# mb_ptr				= find id winfos
					= case mb_ptr of
						(Just ptr)			-> Just ptr
						Nothing				-> finds ids winfos
				finds [] _
					= Nothing
				
				find :: !Id ![WindowInfo] -> Maybe TheoremPtr
				find id []
					= Nothing
				find id [winfo:winfos]
					| winfo.wiWindowId == id	= is_theorem_window winfo.wiId
					= find id winfos
				
				is_theorem_window :: !WindowId -> Maybe TheoremPtr
				is_theorem_window (WinTheorem ptr)
					= Just ptr
				is_theorem_window _
					= Nothing
		
		undo :: !*PState -> *PState
		undo pstate
			# (opened, pstate)				= isWindowOpened (WinProof nilPtr) False pstate
			| not opened					= pstate
			# (winfo, pstate)				= get_Window (WinProof nilPtr) pstate
			# (_, pstate)					= asyncSend (fromJust winfo.wiNormalRId) (CmdUndoTactics 1) pstate
			= pstate
		
		focusOnCommandLine :: !*PState -> *PState
		focusOnCommandLine pstate
			# (opened, pstate)				= isWindowOpened (WinProof nilPtr) False pstate
			| not opened					= pstate
			# (winfo, pstate)				= get_Window (WinProof nilPtr) pstate
			# pstate						= setActiveWindow winfo.wiWindowId pstate
			# (_, pstate)					= asyncSend (fromJust winfo.wiNormalRId) CmdFocusCommandline pstate
			= pstate

// ------------------------------------------------------------------------------------------------------------------------   
// TacticsMenu :: Ids -> Menu _ TNoLocalState TState   
// ------------------------------------------------------------------------------------------------------------------------   
TacticsMenu titles list1_id list1_opened list2_id list2_opened list3_id list3_opened list4_id list4_opened list5_id list5_opened
	= Menu "&Tactics" 
		(		MenuItem		("1. " +++ titles !! 0)
									[ MenuFunction		(noLS (toggleTacticList 0))
									, MenuMarkState		(if list1_opened Mark NoMark)
									, MenuId			list1_id
									]
			:+: MenuItem		("2. " +++ titles !! 1)
									[ MenuFunction		(noLS (toggleTacticList 1))
									, MenuMarkState		(if list2_opened Mark NoMark)
									, MenuId			list2_id
									]
			:+: MenuItem		("3. " +++ titles !! 2)
									[ MenuFunction		(noLS (toggleTacticList 2))
									, MenuMarkState		(if list3_opened Mark NoMark)
									, MenuId			list3_id
									]
			:+: MenuItem		("4. " +++ titles !! 3)
									[ MenuFunction		(noLS (toggleTacticList 3))
									, MenuMarkState		(if list4_opened Mark NoMark)
									, MenuId			list4_id
									]
			:+: MenuItem		("5. " +++ titles !! 4)
									[ MenuFunction		(noLS (toggleTacticList 4))
									, MenuMarkState		(if list5_opened Mark NoMark)
									, MenuId			list5_id
									]
		)
		[]
	where
		toggleTacticList :: !Int !*PState -> *PState
		toggleTacticList num pstate
			# (opened, pstate)				= isWindowOpened (WinTacticList num) False pstate
			= case opened of
				True	-> close_Window (WinTacticList num) pstate
				False	-> openTacticList num pstate

// ------------------------------------------------------------------------------------------------------------------------   
// OptionsMENU :: Id -> Menu _ TNoLocalState TState   
// ------------------------------------------------------------------------------------------------------------------------   
OptionsMENU phase d_options options d_special menu_id
	= Menu "&Options" 
		(		SubMenu			"Frontend Phase" phaseMenu
									[]
			:+:	SubMenu			"Display Options"
									(		SubMenu		"Dictionaries"				(optionMenu OptShowDictionaries d_options options) []
										:+:	SubMenu		"Instance Types"			(optionMenu OptShowInstanceTypes d_options options) []
										:+:	SubMenu		"Variable Indexes"			(optionMenu OptShowVariableIndexes d_options options) []
										:+:	SubMenu		"Additional Brackets"		(optionMenu OptAlwaysBrackets d_options options) []
										:+:	MenuSeparator []
										:+:	SubMenu		"Record Functions"			(optionMenu OptShowRecordFuns d_options options) []
										:+:	SubMenu		"Record Creation"			(optionMenu OptShowRecordCreation d_options options) []
										:+:	SubMenu		"Array Functions"			(optionMenu OptShowArrayFuns d_options options) []
										:+:	SubMenu		"Tuple Functions"			(optionMenu OptShowTupleFuns d_options options) []
										:+:	MenuSeparator []
										:+:	SubMenu		"Pattern Matching"			(optionMenu OptShowPatterns d_options options) []
										:+:	SubMenu		"Case/Let vs #/|"			(optionMenu OptShowLetsAndCases d_options options) []
										:+:	SubMenu		"Sharing"					(optionMenu OptShowSharing d_options options) []
										:+:	MenuSeparator []
										:+:	SubMenu		"Theorem Window Scoping"	(optionMenu OptShowIndents d_options options) []
										:+:	SubMenu		"Special Fonts"				(optionMenu OptDisplaySpecial d_options options) []
										:+:	SubMenu		"Boolean Predicates"		(optionMenu OptShowIsTrue d_options options) []
										:+:	SubMenu		"Unused Variables"			(optionMenu OptAutomaticDiscard d_options options) []
									)
									[]
			:+:	MenuItem		"Colours (partial)"
									[ MenuFunction			(noLS selectColour)
									]
									
		)
		[ MenuShortKey		'O'
		, MenuId			menu_id
		]
		where
			phaseMenu	= RadioMenu [ ("Check",				Nothing, Nothing, noLS (setFrontEndPhase FrontEndPhaseCheck))
		  							, ("TypeCheck",			Nothing, Nothing, noLS (setFrontEndPhase FrontEndPhaseTypeCheck))
		  							, ("ConvertDynamics",	Nothing, Nothing, noLS (setFrontEndPhase FrontEndPhaseConvertDynamics))
		  							, ("TransformGroups",	Nothing, Nothing, noLS (setFrontEndPhase FrontEndPhaseTransformGroups))
		  							, ("ConvertModules",	Nothing, Nothing, noLS (setFrontEndPhase FrontEndPhaseConvertModules))
		  							, ("All",				Nothing, Nothing, noLS (setFrontEndPhase FrontEndPhaseAll))
		  							]
		  							(initialFrontEndPhase phase) []
		  	
		  	setFrontEndPhase :: !FrontEndPhase !*PState -> *PState
		  	setFrontEndPhase phase pstate
		  		= {pstate & ls.stFrontEndPhase = phase}
		  	
		  	initialFrontEndPhase :: !FrontEndPhase -> Int
		  	initialFrontEndPhase FrontEndPhaseCheck				= 1
		  	initialFrontEndPhase FrontEndPhaseTypeCheck			= 2
		  	initialFrontEndPhase FrontEndPhaseConvertDynamics	= 3
		  	initialFrontEndPhase FrontEndPhaseTransformGroups	= 4
		  	initialFrontEndPhase FrontEndPhaseConvertModules	= 5
		  	initialFrontEndPhase FrontEndPhaseAll				= 6

// ------------------------------------------------------------------------------------------------------------------------   
// InfoMENU :: Id -> Menu _ TNoLocalState TState   
// ------------------------------------------------------------------------------------------------------------------------   
InfoMENU menu_id
	= Menu "&Info" 
		(		MenuItem		"About Sparkle"
									[ MenuFunction			(noLS (aboutDialog True))
									]
		)
		[]

























// -------------------------------------------------------------------------------------------------------------------------------------------------
:: FlashState =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ flash_colours					:: ![Colour]
	, flash_rids					:: ![RId (MarkUpMessage Int)]
	, flash_red						:: !Int
	, flash_green					:: !Int
	, flash_blue					:: !Int
	, flash_increments				:: ![(Int,Int,Int)]
	, flash_count					:: !Int
	}
initialFlashState ids
	=	{ flash_colours				= [Black, Black, Black, Black, Black, Black, Black]
		, flash_rids				= ids // [s_rid, p_rid, a_rid, r_rid, k_rid, l_rid, e_rid]
		, flash_red					= 200
		, flash_green				= 100
		, flash_blue				= 200
		, flash_increments			= [(0,0,~1), (0,1,0), (~1,0,0), (0,0,1), (0,~1,0), (1,0,0)]
		, flash_count				= 0
		}

// -------------------------------------------------------------------------------------------------------------------------------------------------
AboutBG				:== RGB {r=180, g=180, b=200}
AboutRedFG			:== RGB {r=150, g= 50, b= 50}
AboutDarkRedFG		:== RGB {r=100, g=  0, b=  0}
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
aboutDialog :: !Bool !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
aboutDialog always_show pstate
	# (start, pstate)				= pstate!ls.stDisplayOptions.optStartWithAboutDialog
	| not always_show && not start	= pstate
	# (dialog_id, pstate)			= accPIO openId pstate
	# (ok_id, pstate)				= accPIO openId pstate
	# (timer_rid, pstate)			= accPIO openRId pstate
	# (timer_id, pstate)			= accPIO openId pstate
	# (letter_rids, pstate)			= accPIO (openRIds 7) pstate
	# start_state					= if start Mark NoMark
	# (_, pstate)					= openModalDialog 0 (about_dialog dialog_id ok_id timer_rid timer_id letter_rids start_state) pstate
	= pstate
	where
		about_dialog id ok_id timer_rid timer_id letter_rids start_state
			= Dialog "About Sparkle"
				(	(CompoundControl (
					MarkUpControl		[]
											[ MarkUpWidth				90
											, MarkUpBackgroundColour	AboutBG
											]
											[ ControlPos				(Left, OffsetVector {vx=0, vy=15})
											]
				:+:	MarkUpControl		[CmBText "Welcome to "]
											[ MarkUpTextSize			15
											, MarkUpBackgroundColour	AboutBG
											, MarkUpTextColour			Yellow
											]
											[]
				:+:	letter_control		'S' (letter_rids !! 0)
				:+:	letter_control		'p' (letter_rids !! 1)
				:+:	letter_control		'a' (letter_rids !! 2)
				:+:	letter_control		'r' (letter_rids !! 3)
				:+:	letter_control		'k' (letter_rids !! 4)
				:+:	letter_control		'l' (letter_rids !! 5)
				:+:	letter_control		'e' (letter_rids !! 6)
				:+:	MarkUpControl		[CmBText "!"]
											[ MarkUpWidth				90
											, MarkUpTextSize			13
											, MarkUpBackgroundColour	AboutBG
											, MarkUpTextColour			Blue
											]
											[]
				:+:	MarkUpControl		[CmIText "version: ", CmBText SparkleVersion]
											[ MarkUpTextSize			11
											, MarkUpBackgroundColour	AboutBG
											, MarkUpTextColour			Black
											, MarkUpFontFace			"Times New Roman"
											]
											[ ControlPos				(Center, OffsetVector {vx=0, vy=30})
											]
				:+:	MarkUpControl		[CmIText "creation date: ", CmBText SparkleCreationDate]
											[ MarkUpTextSize			11
											, MarkUpBackgroundColour	AboutBG
											, MarkUpTextColour			Black
											, MarkUpFontFace			"Times New Roman"
											]
											[ ControlPos				(Center, OffsetVector {vx=0, vy=0})
											]
				:+:	MarkUpControl		[CmCenter, CmBText "For more info, see ", CmColour AboutDarkRedFG, CmBText "http://www.cs.kun.nl/Sparkle", CmEndColour, CmBText ".", CmAlign "@End", CmNewline,
										 CmCenter, CmBText "All feedback can be directed to ", CmColour AboutDarkRedFG, CmBText "maartenm@cs.kun.nl", CmEndColour, CmBText ".", CmAlign "@End"]
											[ MarkUpTextSize			10
											, MarkUpBackgroundColour	AboutBG
											, MarkUpTextColour			AboutRedFG
											, MarkUpFontFace			"Times New Roman"
											]
											[ ControlPos				(Center, OffsetVector {vx=0, vy=20})
											]
				:+:	ButtonControl		"Continue"
											[ ControlPos				(Center, OffsetVector {vx=0, vy=30})
											, ControlFunction			(noLS (closeWindow id o appPIO (closeTimer timer_id)))
											, ControlId					ok_id
											]
				:+:	MarkUpControl		[CmText "Hallo"]
											[ MarkUpTextColour			AboutBG
											, MarkUpBackgroundColour	AboutBG
											, MarkUpTextSize			6
											]
											[ ControlPos				(Left, zero)
											]
				)
				[	ControlItemSpace	0 0
				,	ControlLook			True (\_ {newFrame} -> seq [setPenColour AboutBG, fill newFrame])
				])
				:+: CheckControl		[("show this dialog at start-up", Nothing, start_state, flip_start)] (Rows 1)
											[ ControlPos				(Left, zero)
											]
				)
				[	WindowId			id
				,	WindowInit			(noLS (snd o (openTimer (initialFlashState letter_rids) timer)))
				,	WindowClose			(noLS (closeWindow id o appPIO (closeTimer timer_id)))
				,	WindowOk			ok_id
				,	WindowCancel		ok_id
				,	WindowItemSpace		0 0
				,	WindowHMargin		0 0
				,	WindowVMargin		0 0
				]
			where
				letter_control letter rid
					=	MarkUpControl	[CmBText {letter}]
											[ MarkUpTextSize			15
											, MarkUpTextColour			Yellow
											, MarkUpBackgroundColour	Black
											, MarkUpReceiver rid] 
											[]
				
				timer
					= Timer 20 (Receiver timer_rid receive []) [TimerId timer_id, TimerFunction tick]
				
				receive msg (lstate, pstate)
					= (lstate, pstate)
				
				tick nrIntervals (fstate, pstate)
					# current_rid					= hd fstate.flash_rids
					# old_colour					= hd fstate.flash_colours
					# current_increment				= hd fstate.flash_increments
					# step_size						= 50
					# new_red						= fstate.flash_red + step_size * fst3 current_increment
					# new_green						= fstate.flash_green + step_size * snd3 current_increment
					# new_blue						= fstate.flash_blue + step_size * thd3 current_increment
					# new_count						= fstate.flash_count + step_size
					# new_colour					= RGB {r = new_red, g = new_green, b = new_blue}
					# pstate						= changeMarkUpColour current_rid True old_colour new_colour pstate
					# fstate						=	{ flash_colours			= (tl fstate.flash_colours) ++ [new_colour]
														, flash_rids			= (tl fstate.flash_rids) ++ [current_rid]
														, flash_red				= new_red
														, flash_green			= new_green
														, flash_blue			= new_blue
														, flash_increments		= if (new_count==100) (tl fstate.flash_increments ++ [current_increment]) fstate.flash_increments
														, flash_count			= if (new_count==100) 0 new_count
														}
					= (fstate, pstate)
				
				flip_start (lstate, pstate)
					# (old, pstate)					= pstate!ls.stDisplayOptions.optStartWithAboutDialog
					# pstate						= {pstate & ls.stDisplayOptions.optStartWithAboutDialog = not old}
					= (lstate, pstate)