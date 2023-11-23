/*
** Program: Clean Prover System
** Module:  ShowDefinition (.icl)
** 
** Author:  Maarten de Mol
** Created: 28 September 1999
*/

implementation module 
	ShowDefinition

import 
	StdEnv,
	StdIO,
	States,
	MarkUpText,
	Tactics,
//	ListBox,
	RWSDebug

/*
// ------------------------------------------------------------------------------------------------------------------------   
pickDefinition :: !*PState -> !*PState
// ------------------------------------------------------------------------------------------------------------------------   
pickDefinition pstate
	# (opened, pstate)			= isWindowOpened DlgShowDefinitions True pstate
	| opened					= pstate
	# (winfo, pstate)			= new_Window DlgShowDefinitions pstate
	# dialog_id					= winfo.wiWindowId
	# (modules_textid, pstate)	= accPIO openId pstate
	# (modules_lbid, pstate)	= accPIO (openListBoxId dialog_id) pstate
	# (kind_textid, pstate)		= accPIO openId pstate
	# (kind_lbid, pstate)		= accPIO (openListBoxId dialog_id) pstate
	# (def_textid, pstate)		= accPIO openId pstate
	# (def_lbid, pstate)		= accPIO (openListBoxId dialog_id) pstate
	# (dialog, pstate)			= PickDefDLG dialog_id modules_textid modules_lbid kind_textid kind_lbid def_textid def_lbid pstate
	= snd (openDialog 0 dialog pstate)

// ------------------------------------------------------------------------------------------------------------------------   
:: ModuleInfo =
// ------------------------------------------------------------------------------------------------------------------------   
	{	miPtr		:: !ModulePtr
	,	miName		:: !ModuleName
	}
	
// ------------------------------------------------------------------------------------------------------------------------   
instance toString ModuleInfo
// ------------------------------------------------------------------------------------------------------------------------   
where
	toString modinfo
		= modinfo.miName

// ------------------------------------------------------------------------------------------------------------------------   
instance toString DefinitionInfo
// ------------------------------------------------------------------------------------------------------------------------   
where
	toString definfo
		= definfo.diName

// ------------------------------------------------------------------------------------------------------------------------   
buildModuleInfo :: !*CHeaps !*CProject -> ([!ModuleInfo], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------   
buildModuleInfo heaps prj
	# (mod_ptrs, prj)			= prj!prjModules
	# (mod_names, heaps)		= getPointerNames mod_ptrs heaps
	# mod_infos					= [{miPtr = ptr, miName = name} \\ ptr <- mod_ptrs & name <- mod_names]
	# predef_info				= {miPtr = nilPtr, miName = "###PREDEFINED###"}
	= ([predef_info:mod_infos], heaps, prj)

// BEZIG
// ------------------------------------------------------------------------------------------------------------------------   
// PickDefDLG :: Id -> Dialog _ _ _
// ------------------------------------------------------------------------------------------------------------------------   
PickDefDLG own_id modules_textid modules_lbid kind_textid kind_lbid def_textid def_lbid pstate
	# (modules, pstate)			= accHeapsProject buildModuleInfo pstate
	# modules					= sortBy (\m1 m2 -> m1.miName < m2.miName) modules
	= (	Dialog "Pick a definition"
		(	TextControl			"Pick modules:"
									[ ControlId				modules_textid
									]
		:+:	TextListBoxControl  modules [] MultiSelect 25
									[ ListBoxPos			(Below modules_textid, zero)
									, ListBoxId				modules_lbid
									, ListBoxFont			{fName = "Courier New", fSize=10, fStyles=[]}
									, ListBoxBackgroundColour	AlmostWhite
									, ListBoxHiliteColour		AlmostWhiteHilite
									, ListBoxEventHandler	(\event default_handler state -> set_definitions (default_handler state))
									]
		:+:	TextListBoxControl	(map snd kinds) [5] SingleSelect (length kinds)
									[ ListBoxId				kind_lbid
									, ListBoxPos			(RightToListBox modules_lbid, zero)
									, ListBoxFont			{fName = "Courier New", fSize=10, fStyles=[]}
									, ListBoxBackgroundColour	AlmostWhite
									, ListBoxHiliteColour		AlmostWhiteHilite
									, ListBoxEventHandler	(\event default_handler state -> set_definitions (default_handler state))
									]
		:+: TextControl			"Pick kind:"
									[ ControlId				kind_textid
									, ControlPos			(AboveListBox kind_lbid, zero)
									]
		:+: typed_listbox			[ ListBoxId				def_lbid
									, ListBoxPos			(RightToListBox kind_lbid, zero)
									, ListBoxFont			{fName = "Courier New", fSize=10, fStyles=[]}
									, ListBoxBackgroundColour	AlmostWhite
									, ListBoxHiliteColour		AlmostWhiteHilite
									, ListBoxWidth			350
									, ListBoxEventHandler  catch_double_click
									]
		:+: TextControl 		"Pick definition:"
									[ ControlId				def_textid
									, ControlPos			(AboveListBox def_lbid, zero)
									]
		)
		[ WindowId				own_id
		, WindowPos				(Fix, OffsetVector {vx=100,vy=100})
		, WindowClose			(noLS (close_Window DlgShowDefinitions))
		]
	  , pstate)
	where
		kinds					= [(CAlgType, "Algebraic Types"), (CClass, "Classes"), (CMember, "Class Members"), (CInstance, "Class Instances"),
								   (CDataCons, "Dataconstructors"), (CFun, "Functions"),
								   (CRecordField, "Record Fields"), (CRecordType, "Record Types")]
		
		typed_listbox :: [ListBoxAttribute DefinitionInfo *PState] -> (ListBoxState DefinitionInfo Int *PState)
		typed_listbox atts = TextListBoxControl [] [] SingleSelect 25 atts
		
		set_definitions :: *PState -> *PState
		set_definitions pstate 
			# (mbe_selected_modules_indexes, pstate)	= getListBoxSelection modules_lbid pstate
			# selected_modules_indexes					= fromJust mbe_selected_modules_indexes
			# (mbe_modules, pstate)						= getListBoxItems modules_lbid pstate
			# modules									= fromJust mbe_modules
			# selected_modules							= [modules !! index \\ index <- selected_modules_indexes]
			# selected_modules_ptrs						= map (\mi -> mi.miPtr) selected_modules
			# (mbe_selected_kind_index, pstate)			= getListBoxSelection kind_lbid pstate
			# selected_kind_index						= fromJust mbe_selected_kind_index
			# kind										= fst (kinds !! (hd selected_kind_index))
			# (error, ptrs, pstate)						= accErrorHeaps (getHeapPtrs selected_modules_ptrs [kind]) pstate
			| isError error								= showError error pstate
			# (error, definitions, pstate)				= accErrorHeapsProject (uumapError getDefinitionInfo ptrs) pstate
			| isError error								= showError error pstate
			# (show_records, pstate)					= pstate!ls.stDisplayOptions.optShowRecordFuns
			# definitions								= if show_records definitions (filter check_select_name definitions)
			# definitions								= if show_records definitions (filter check_update_name definitions)
			# (show_dictionaries, pstate)				= pstate!ls.stDisplayOptions.optShowDictionaries
			# definitions								= if show_dictionaries definitions (filter check_dict_name definitions)
			# (show_tupleselects, pstate)				= pstate!ls.stDisplayOptions.optShowTupleFuns
			# definitions								= if show_tupleselects definitions (filter check_tselect_name definitions)
			# definitions								= sortBy (\di1 di2 -> di1.diName < di2.diName) definitions
			# pstate									= setListBoxItems def_lbid definitions [] 0 pstate
			= pstate
			where
				check_select_name def	= not (substring "_select_" def.diName)
				check_update_name def	= not (substring "_update_" def.diName)
				check_dict_name def		= not (substring "dictionary_" def.diName)
				check_tselect_name def	= not (substring "_tupleselect_" def.diName)
		
		substring :: !String !String -> Bool
		substring sub whole
			# sub			= [c \\ c <-: sub]
			# whole			= [c \\ c <-: whole]
			= check_list sub whole
			where
				check_list [c:cs] [d:ds]
					# init				= isinit [c:cs] [d:ds]
					| init				= True
					= check_list [c:cs] ds
				check_list _ []
					= False
				
				isinit [] whole			= True
				isinit [c:cs] [d:ds]	= if (c == d) (isinit cs ds) False
				isinit _ _				= False
			
		catch_double_click :: ListBoxEvent (IdFun *PState) *PState -> *PState
		catch_double_click (ExecuteItem index) defaultaction state
			# pstate								= defaultaction state
			# (maybe_items, pstate)					= getListBoxItems def_lbid pstate
			# items									= fromJust maybe_items
			# selected_item							= items !! index
			= showDefinition selected_item.diPointer pstate
		catch_double_click other defaultaction pstate
			= defaultaction pstate
*/

// ------------------------------------------------------------------------------------------------------------------------   
showDefinition :: !HeapPtr !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
showDefinition defptr pstate
	# (opened, pstate)			= isWindowOpened (WinDefinition defptr) True pstate
	| opened					= pstate
	# (winfo, pstate)			= new_Window (WinDefinition defptr) pstate
	# id						= winfo.wiWindowId
	# rid						= fromJust winfo.wiSpecialRId
	# module_ptr				= ptrModule defptr
	# (error, name, pstate)		= accErrorHeapsProject (getDefinitionName defptr) pstate
	| isError error				= showError error pstate
	# (finfo, pstate)			= makeFormatInfo pstate
	# (error, ftext, pstate)	= show finfo defptr pstate
	| isError error				= showError error pstate
	# (modname, pstate)			= case isNilPtr module_ptr of
									True	-> ("###PREDEFINED###", pstate)
									False	-> accHeaps (getPointerName module_ptr) pstate
	# (vector, pstate)			= placeWindow {w=600,h=300} pstate
	# (extended_bg, pstate)		= pstate!ls.stDisplayOptions.optDefinitionWindowBG
	# bg						= toColour 0 extended_bg
	= MarkUpWindow (name +++ " in module " +++ modname) ftext 
		[ MarkUpBackgroundColour	bg
		, MarkUpMaxWidth			600
		, MarkUpMaxHeight			350
		, MarkUpFontFace			"Courier New"
		, MarkUpTextSize			10
		, MarkUpLinkStyle			False Black bg True Blue bg				// definition links
		, MarkUpLinkStyle			False Brown bg True Red bg				// definedness links
		, MarkUpEventHandler		(clickHandler (click_handler rid))
		, MarkUpReceiver			rid
		, MarkUpIgnoreMultipleSpaces
		]
		[ WindowId					id
		, WindowClose				(noLS (close_Window (WinDefinition defptr)))
		, WindowPos					(LeftTop, OffsetVector vector)
		] pstate
	where
		click_handler :: !(RId (MarkUpMessage WindowCommand)) !WindowCommand !*PState -> *PState
		click_handler rid CmdRefreshAlways pstate
			# (finfo, pstate)					= makeFormatInfo pstate
			# (error, ftext, pstate)			= show finfo defptr pstate
			| isError error						= showError error pstate
			# pstate							= changeMarkUpText rid ftext pstate
			= pstate
		click_handler rid (CmdRefresh ChangedDisplayOption) pstate
			# (finfo, pstate)					= makeFormatInfo pstate
			# (error, ftext, pstate)			= show finfo defptr pstate
			| isError error						= showError error pstate
			# pstate							= changeMarkUpText rid ftext pstate
			= pstate
		click_handler rid (CmdRefresh (RemovedCleanModules ptrs)) pstate
			# mod_ptr							= ptrModule defptr
			| isMember mod_ptr ptrs				= close_Window (WinDefinition defptr) pstate
			= pstate
		click_handler rid (CmdShowDefinition ptr) pstate
			= showDefinition ptr pstate
		click_handler rid (CmdShowDefinedness ptr) pstate
			= showDefinedness (Just ptr) pstate
		click_handler rid command pstate
			= pstate
		
		show :: !FormatInfo !HeapPtr !*PState -> (!Error, !MarkUpText WindowCommand, !*PState)
		show finfo ptr pstate
			# state								= pstate.ls
			# heaps								= state.stHeaps
			# prj								= state.stProject
			# (error, ftext, heaps, prj)		= formattedShow ptr finfo heaps prj
			# state								= {state & stHeaps = heaps, stProject = prj}
			# pstate							= {pstate & ls = state}
			| isError error						= (error, DummyValue, pstate)
			= (OK, ftext, pstate)

compAcc		:== \(t1,p1,f1,b1,u1) -> \(t2,p2,f2,b2,u2) -> f1.fdName < f2.fdName
:: Acc		:== [(Theorem, HeapPtr, CFunDefH, Bool, [String])]	// theorem, funptr, fundef, defined?, used_in
BG			:== RGB {r=195,g=195,b=165}
BG_Dark		:== RGB {r=185,g=185,b=155}
BG_Light	:== RGB {r=215,g=215,b=185}
// ------------------------------------------------------------------------------------------------------------------------   
showDefinedness :: !(Maybe HeapPtr) !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
showDefinedness mb_fun pstate
	# (sections, pstate)						= pstate!ls.stSections
	# (uses, pstate)							= accHeapsProject (analyze_sections sections []) pstate
	# uses										= sortBy compAcc uses
	# (display, pstate)							= pstate!ls.stDisplaySpecial
	# (fuses, pstate)							= accHeapsProject (show uses DummyValue display) pstate
	# fuses										= case isEmpty fuses of
													True	->	[ CmBackgroundColour		BG_Light
																, CmColour					Red
																, CmHorSpace				5
																, CmBText					"No definedness theorems found."
																, CmFillLine
																, CmEndColour
																, CmEndBackgroundColour
																]
													False	-> fuses
	# (dialog_title, pstate)					= accHeapsProject (make_title mb_fun) pstate
	# (dialog_id, pstate)						= accPIO openId pstate
	# (dummy_button_id, pstate)					= accPIO openId pstate
	= snd (openModalDialog 0 (dialog dialog_title fuses dialog_id dummy_button_id) pstate)
	where
		analyze_sections :: ![SectionPtr] !Acc !*CHeaps !*CProject -> (!Acc, !*CHeaps, !*CProject)
		analyze_sections [ptr:ptrs] acc heaps prj
			# (section, heaps)					= readPointer ptr heaps
			# (acc, heaps, prj)					= analyze_theorems section.seTheorems acc heaps prj
			= analyze_sections ptrs acc heaps prj
		analyze_sections [] acc heaps prj
			= (acc, heaps, prj)
		
		analyze_theorems :: ![TheoremPtr] !Acc !*CHeaps !*CProject -> (!Acc, !*CHeaps, !*CProject)
		analyze_theorems [ptr:ptrs] acc heaps prj
			# (theorem, heaps)					= readPointer ptr heaps
			# (ok, _, (of_fun, _), heaps, prj)	= isManualDefinedness ptr heaps prj
			# (_, of_fun_def, prj)				= getFunDef of_fun prj
			# acc								= case ok && (isNothing mb_fun || mb_fun == Just of_fun) of
													True	-> add_define theorem of_fun of_fun_def acc
													False	-> acc
			# (acc, heaps)						= analyze_proof_ptrs theorem.thName [theorem.thProof.pTree] acc heaps
			= analyze_theorems ptrs acc heaps prj
		analyze_theorems [] acc heaps prj
			= (acc, heaps, prj)
		
		analyze_proof_ptrs :: !String ![ProofTreePtr] !Acc !*CHeaps -> (!Acc, !*CHeaps)
		analyze_proof_ptrs uses_name [ptr:ptrs] acc heaps
			# (proof, heaps)					= readPointer ptr heaps
			# (acc, heaps)						= analyze_proof uses_name proof acc heaps
			= analyze_proof_ptrs uses_name ptrs acc heaps
		analyze_proof_ptrs uses_name [] acc heaps
			= (acc, heaps)
		
		analyze_proof :: !String !ProofTree !Acc !*CHeaps -> (!Acc, !*CHeaps)
		analyze_proof uses_name (ProofNode _ (TacticManualDefinedness theorem_ptrs) ptrs) acc heaps
			# (acc, heaps)						= add_uses theorem_ptrs uses_name acc heaps
			= analyze_proof_ptrs uses_name ptrs acc heaps
		analyze_proof uses_name (ProofNode _ _ ptrs) acc heaps
			= analyze_proof_ptrs uses_name ptrs acc heaps
		analyze_proof uses_name (ProofLeaf _) acc heaps
			= (acc, heaps)
		
		add_define :: !Theorem !HeapPtr !CFunDefH !Acc -> Acc
		add_define theorem1 ptr1 fun1 [(theorem2,ptr2,fun2,ok2,uses2):info]
			= case theorem1.thName == theorem2.thName of
				True							-> [(theorem1,ptr1,fun1,True, uses2): info]
				False							-> [(theorem2,ptr2,fun2,ok2,  uses2): add_define theorem1 ptr1 fun1 info]
		add_define theorem ptr fun []
			= [(theorem,ptr,fun,True,[])]
		
		add_use :: !Theorem !String !Acc -> Acc
		add_use theorem1 uses_name1 [(theorem2,ptr2,fun2,ok2,uses2):info]
			= case theorem1.thName == theorem2.thName of
				True							-> [(theorem2,ptr2,fun2,ok2,add_sorted uses_name1 uses2): info]
				False							-> [(theorem2,ptr2,fun2,ok2,uses2): add_use theorem1 uses_name1 info]
			where
				add_sorted x [y:ys]
					| x == y					= [y:ys]
					= case (x < y) of
						True					-> [x: [y:ys]]
						False					-> [y: add_sorted x ys]
				add_sorted x []
					= [x]
		add_use theorem uses_name []
			= [(theorem,DummyValue,DummyValue,False,[uses_name])]
		
		add_uses :: ![TheoremPtr] !String !Acc !*CHeaps -> (!Acc, !*CHeaps)
		add_uses [ptr:ptrs] uses_name acc heaps
			# (theorem, heaps)					= readPointer ptr heaps
			# acc								= add_use theorem uses_name acc
			= add_uses ptrs uses_name acc heaps
		add_uses [] uses_name acc heaps
			= (acc, heaps)
		
		show :: !Acc !HeapPtr !DisplaySpecial !*CHeaps !*CProject -> (!MarkUpText WindowCommand, !*CHeaps, !*CProject)
		show [(theorem,ptr,fundef,True,uses):info] last_ptr display heaps prj
			# (mod, heaps)						= readPointer (ptrModule ptr) heaps
			# (section, heaps)					= readPointer theorem.thSection heaps
			# header							= case ptr == last_ptr of
													True	->	[]
													False	->	[ CmBackgroundColour	BG_Light
																, CmHorSpace			5
																, CmBText				"Definedness theorems for function '"
																, CmColour				Blue
																, CmBText				fundef.fdName
																, CmEndColour
																, CmBText				"' from module '"
																, CmBText				mod.pmName
																, CmBText				"':"
																, CmFillLine
																, CmEndBackgroundColour
																, CmNewlineI			True 1 (Just BG_Dark)
																]
			# (fprop, heaps)					= show_prop theorem.thInitial fundef display heaps
			# fuses								= case isEmpty uses of
													True	->	[ CmText				"-"]
													False	->	show_uses uses
			# footer							= case isEmpty info of
													True	->	[]
													False	->	[ CmColour				BG
																, CmText				"-"
																, CmEndColour
																, CmNewlineI			True 1 (Just BG_Dark)
																]
			# (fmore, heaps, prj)				= show info ptr display heaps prj
			= (	header ++
				[ CmBackgroundColour			BG_Dark
				, CmHorSpace 5
				, CmBGRight						BG_Dark
				, CmText						"Theorem: "
				, CmEndBackgroundColour
				, CmAlign						"@1"
				, CmHorSpace					5
				, CmText						theorem.thName
				, CmIText						" (from section "
				, CmIText						section.seName
				, CmIText						")"
				, CmNewlineI					True 1 (Just BG_Dark)
				, CmBackgroundColour			BG_Dark
				, CmHorSpace					5
				, CmBGRight						BG_Dark
				, CmText						"Property: "
				, CmEndBackgroundColour
				, CmAlign						"@1"
				, CmHorSpace					5
				: overrideColour				LogicColour BG fprop
				] ++
				[ CmNewlineI					True 1 (Just BG_Dark)
				, CmBackgroundColour			BG_Dark
				, CmHorSpace					5
				, CmBGRight						BG_Dark
				, CmText						"Used in: "
				, CmEndBackgroundColour
				, CmAlign						"@1"
				, CmHorSpace					5
				, CmColour						Brown
				: fuses
				] ++
				[ CmEndColour
				, CmNewlineI					True 1 (Just BG_Dark)
				: footer ++ fmore
				], heaps, prj)
		show [_:info] last_ptr display heaps prj
			= show info last_ptr display heaps prj
		show [] last_ptr display heaps prj
			= ([], heaps, prj)
		
		show_prop :: !CPropH !CFunDefH !DisplaySpecial !*CHeaps -> (!MarkUpText WindowCommand, !*CHeaps)
		show_prop (CExprForall _ p) fundef display heaps
			= show_prop p fundef display heaps
		show_prop (CImplies (CNot (CEqual (CExprVar var) CBottom)) p) fundef display heaps
			# (var, heaps)						= readPointer var heaps
			# fcondition						=	[ CmText		"("
													, CmText		var.evarName
													] ++ display.disUnequals ++ display.disBottom ++
													[ CmText		")"]
			# (fnext, heaps)					= show_prop p fundef display heaps
			= (display.disImplies True fcondition fnext, heaps)
		show_prop (CNot (CEqual (_ @@# args) CBottom)) fundef display heaps
			# (names, heaps)					= get_argument_names args heaps
			= ([CmBold, CmText (show_app fundef names), CmText " "] ++ 
			   display.disUnequals ++ [CmText " "] ++ display.disBottom ++ [CmEndBold], heaps)
			where
				get_argument_names :: ![CExprH] !*CHeaps -> (![String], !*CHeaps)
				get_argument_names [CExprVar ptr: args] heaps
					# (var, heaps)				= readPointer ptr heaps
					# (names, heaps)			= get_argument_names args heaps
					= ([var.evarName: names], heaps)
				get_argument_names [] heaps
					= ([], heaps)
				
				show_app :: !CFunDefH ![String] -> String
				show_app fundef names
					= case isInfix (fundef.fdInfix) && length names == 2 of
						True					-> (names!!0) +++ " " +++ fundef.fdName +++ " " +++ (names!!1)
						False					-> fundef.fdName +++ foldl (\x -> \y-> x+++" "+++y) "" names
		
		show_uses :: ![String] -> MarkUpText WindowCommand
		show_uses [name:names]
			| isEmpty names						= [CmText name]
			= [CmText name, CmText ", ": show_uses names]
		show_uses []
			= []
		
		make_title :: !(Maybe HeapPtr) !*CHeaps !*CProject -> (!String, !*CHeaps, !*CProject)
		make_title (Just ptr) heaps prj
			# (_, fundef, prj)					= getFunDef ptr prj
			# module_ptr						= ptrModule ptr
			# (mod, heaps)						= readPointer module_ptr heaps
			= ("Definedness theorems for function '" +++ fundef.fdName +++ "'from module '" +++ mod.pmName +++ "'" , heaps, prj)
		make_title Nothing heaps prj
			= ("Definedness theorems", heaps, prj)
		
		dialog title fuses dialog_id dummy_button_id =
			Dialog title
				(	boxedMarkUp				Black DoNotResize fuses
												[ MarkUpFontFace			"Times New Roman"
												, MarkUpTextSize			11
												, MarkUpFixMetrics			{fName = "Times New Roman", fStyles = [], fSize = 11}
												, MarkUpWidth				600
												, MarkUpNrLinesI			19 19
												, MarkUpBackgroundColour	BG
												, MarkUpTextColour			Black
												, MarkUpHScroll
												, MarkUpVScroll
												]
												[]
				:+:	ButtonControl			""
												[ ControlPos				(LeftTop, zero)
												, ControlHide
												, ControlId					dummy_button_id
												, ControlFunction			(noLS (closeWindow dialog_id))
												]
				)
				[	WindowId				dialog_id
				,	WindowClose				(noLS (closeWindow dialog_id))
				,	WindowCancel			dummy_button_id
				]