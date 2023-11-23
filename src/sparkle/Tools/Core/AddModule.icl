/*
** Program: Clean Prover System
** Module:  AddModule (.icl)
** 
** Author:  Maarten de Mol
** Created: 13 March 2001
*/

implementation module
	AddModule

import
	StdIO,
	StatusDialog,
	WarningStdEnv,
	Bind,
	Conversion,
	MdM_IOlib,
	OpenProject,
	States
from StdFunc import seq

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: *DclCache =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ cachedDcls			:: !{#DclModule}
	, cachedFunctions		:: !*{#*{#FunDef}}
	, cachedPredefs			:: !*PredefinedSymbols
	, cachedHashTable		:: !*HashTable
	, cachedHeaps			:: !*Heaps
	}
instance DummyValue Heaps
	where DummyValue =	{ hp_var_heap			= newHeap
						, hp_expression_heap	= newHeap
						, hp_type_heaps			= {th_vars = newHeap, th_attrs = newHeap}
						, hp_generic_heap		= newHeap
						}

// -------------------------------------------------------------------------------------------------------------------------------------------------
newDclCache :: !*PState -> (!*DclCache, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
newDclCache pstate
	# ls										= pstate.ls
	# symbol_table								= ls.stCachedSymbolTable
	# (predefs, hash_table)						= buildPredefinedSymbols (newHashTable symbol_table)
	# ls										= {ls & stCachedSymbolTable = newHeap}
	# pstate									= {pstate & ls = ls}
	# cache										=	{ cachedDcls		= {}
													, cachedFunctions	= {}
													, cachedPredefs		= predefs
													, cachedHashTable	= hash_table
													, cachedHeaps		= DummyValue
													}
	= (cache, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
keepDclCache :: !*DclCache !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
keepDclCache cache pstate
	= {pstate & ls.stCachedSymbolTable = cache.cachedHashTable.hte_symbol_heap}


















// ------------------------------------------------------------------------------------------------------------------------   
LightBlue	:== RGB {r=224, g=227, b=253}
// ------------------------------------------------------------------------------------------------------------------------   

// ------------------------------------------------------------------------------------------------------------------------
// boxControl :: (MarkUpText a) _ _ -> _
// ------------------------------------------------------------------------------------------------------------------------
boxControl text markup_attrs attrs
	# resize							= find_resize attrs
	= CompoundControl
			( MarkUpControl text markup_attrs resize )
			[ ControlHMargin			1 1
			, ControlVMargin			1 1
			, ControlItemSpace			1 1
			, ControlLook				True (\_ {newFrame} -> seq [setPenColour Black, draw newFrame])
			: attrs
			]
	where
		find_resize [ControlResize fun:_]
			= [ControlResize fun]
		find_resize [other:rest]
			= find_resize rest
		find_resize []
			= []














// ------------------------------------------------------------------------------------------------------------------------
addModule :: !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------
addModule pstate
	# (mb_name, pstate)						= selectInputFile pstate
	| isNothing mb_name						= pstate
	# (path, name, extension)				= analyze (fromJust mb_name)
	| extension <> "icl"					= showError [X_Internal "Expected an .icl file"] pstate
	= selectPaths [path] name pstate
	where
		analyze :: !String -> (!String, !String, !String)
		analyze name
			| size name <= 4				= ("", "", "")
			# extension						= name % (size name - 3, size name - 1)
			# path_name						= name % (0, size name - 5)
			# last_separator				= find_last_separator (size path_name-1) path_name
			# path							= path_name % (0, last_separator - 1)
			# name							= path_name % (last_separator + 1, size path_name - 1)
			= (path, name, extension)
		
		find_last_separator :: !Int !String -> Int
		find_last_separator n text
			| n < 0							= n
			| text.[n] == '\\'				= n
			| text.[n] == '/'				= n
			= find_last_separator (n-1) text

// ------------------------------------------------------------------------------------------------------------------------
selectPaths :: ![CName] !CName !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------
selectPaths paths name pstate
	# (dialog_id, pstate)					= accPIO openId pstate
	# (dialog_rid, pstate)					= accPIO openRId pstate
	# (name_id, pstate)						= accPIO openId pstate
	# (paths_id, pstate)					= accPIO openId pstate
	# (paths_rid, pstate)					= accPIO openRId pstate
	# (add_id, pstate)						= accPIO openId pstate
	# (remove_id, pstate)					= accPIO openId pstate
	# (accept_id, pstate)					= accPIO openId pstate
	# (cancel_id, pstate)					= accPIO openId pstate
	= snd (openModalDialog ("",paths,name) (selectDialog paths name dialog_id dialog_rid name_id paths_id paths_rid add_id remove_id accept_id cancel_id) pstate)

// ------------------------------------------------------------------------------------------------------------------------
showPaths :: !CName ![CName] -> MarkUpText String
// ------------------------------------------------------------------------------------------------------------------------
showPaths selected paths
	# paths									= sort paths
	# fpaths								= map show paths
	= flatten fpaths
	where
		show :: !CName -> MarkUpText String
		show path
			= case path == selected of
				True	->	[ CmBackgroundColour		LightBlue
							, CmLink2					1 path path
							, CmFillLine
							, CmEndBackgroundColour
							, CmNewline
							]
				False	->	[ CmLink					path path
							, CmNewline
							]

// ------------------------------------------------------------------------------------------------------------------------
//selectDialog :: ![String] !String !Id _ !Id !Id _ !Id !Id !Id !Id -> _
// ------------------------------------------------------------------------------------------------------------------------
selectDialog paths name dialog_id dialog_rid name_id paths_id paths_rid add_id remove_id accept_id cancel_id
	= Dialog "Add Module"
		(		Receiver					dialog_rid change_selection
												[]
			:+:	MarkUpControl				[CmBText "Adding module:"]
												[ MarkUpFontFace			"Times New Roman"
												, MarkUpTextSize			10
												, MarkUpBackgroundColour	getDialogBackgroundColour
												]
												[]
			:+:	MarkUpControl				[CmText name]
												[ MarkUpFontFace			"Courier New"
												, MarkUpTextSize			10
												, MarkUpBackgroundColour	getDialogBackgroundColour
												, MarkUpFixMetrics			{fName = "Times New Roman", fStyles = [], fSize = 10}
												]
												[ ControlId					name_id
												]
			:+:	MarkUpControl				[CmBText "Using paths:"]
												[ MarkUpFontFace			"Times New Roman"
												, MarkUpTextSize			10
												, MarkUpBackgroundColour	getDialogBackgroundColour
												]
												[ ControlPos				(LeftOf paths_id, zero)
												]
			:+:	boxControl					(showPaths "" paths)
												[ MarkUpFontFace			"Courier New"
												, MarkUpTextSize			10
												, MarkUpBackgroundColour	White
												, MarkUpLinkStyle			False Black White False Blue White
												, MarkUpLinkStyle			False Black LightBlue False Blue LightBlue
												, MarkUpWidth				400
												, MarkUpNrLines				10
												, MarkUpHScroll
												, MarkUpVScroll
												, MarkUpReceiver			paths_rid
												, MarkUpEventHandler		(sendHandler dialog_rid)
												]
												[ ControlPos				(Below name_id, zero)
												, ControlId					paths_id
												]
			:+:	ButtonControl				"Accept"
												[ ControlPos				(Right, zero)
												, ControlId					accept_id
												, ControlFunction			accept
												]
			:+:	ButtonControl				"Remove Path"
												[ ControlPos				(LeftOf accept_id, zero)
												, ControlId					remove_id
												, ControlSelectState		Unable
												, ControlFunction			remove
												]
			:+:	ButtonControl				"Add Path"
												[ ControlPos				(LeftOf remove_id, zero)
												, ControlId					add_id
												, ControlFunction			add
												]
			:+:	ButtonControl				"Cancel"
												[ ControlPos				(LeftTop, zero)
												, ControlId					cancel_id
												, ControlFunction			(noLS (closeWindow dialog_id))
												, ControlHide
												]
		)
		[ WindowId							dialog_id
		, WindowClose						(noLS (closeWindow dialog_id))
		, WindowOk							accept_id
		, WindowCancel						cancel_id
		]
	where
		refresh :: !CName ![CName] !*PState -> *PState
		refresh selected paths pstate
			# fpaths						= showPaths selected paths
			# pstate						= changeMarkUpText paths_rid fpaths pstate
			# pstate						= case selected of
												""	-> appPIO (disableControls [remove_id]) pstate
												_	-> appPIO (enableControls [remove_id]) pstate
			= pstate
		
		accept :: !((!CName, ![CName], !CName), !*PState) -> ((!CName, ![CName], !CName), !*PState)
		accept ((_, paths, name), pstate)
			# pstate						= closeWindow dialog_id pstate
			# pstate						= openStatusDialog ("Adding module " +++ name) (addToProject paths name) pstate
			= (("", paths, name), pstate)
		
		add :: !((!CName, ![CName], !CName), !*PState) -> ((!CName, ![CName], !CName), !*PState)
		add ((selected, paths, name), pstate)
			# (mb_path, pstate)				= selectDirectory pstate
			| isNothing mb_path				= ((selected, paths, name), pstate)
			# paths							= removeDup [fromJust mb_path: paths]
			# pstate						= refresh selected paths pstate
			= ((selected, paths, name), pstate)
		
		change_selection :: !CName !((!CName, ![CName], !CName), !*PState) -> ((!CName, ![CName], !CName), !*PState)
		change_selection new_selected ((old_selected, paths, name), pstate)
			# selected						= if (new_selected == old_selected) "" new_selected
			# pstate						= refresh selected paths pstate
			= ((selected, paths, name), pstate)
		
		remove :: !((!CName, ![CName], !CName), !*PState) -> ((!CName, ![CName], !CName), !*PState)
		remove ((selected, paths, name), pstate)
			# paths							= removeMember selected paths
			# pstate						= refresh "" paths pstate
			= (("", paths, name), pstate)

















// ------------------------------------------------------------------------------------------------------------------------
addToProject :: ![String] !String !(StatusDialogEvent -> *PState -> *PState) !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------
addToProject paths name event_handler pstate	
	# (old_module_ptrs, pstate)				= pstate!ls.stProject.prjModules
	# (old_module_names, locations, pstate)	= examine old_module_ptrs pstate
	# search_paths							= {sp_locations = locations, sp_paths = [p +++ "\\" \\ p <- paths]}
	# (cache, pstate)						= newDclCache pstate
	# (error, (new_module_ptrs, cache), pstate)
											= openModules event_handler [name] old_module_names [] search_paths cache pstate
	# pstate								= keepDclCache cache pstate
	| isError error
		# pstate							= event_handler CloseStatusDialog pstate
		= showError error pstate
	# pstate								= event_handler (NewMessage "Binding modules to project") pstate
	# (error, pstate)						= accHeapsProject (bindToProject new_module_ptrs) pstate
	| isError error
		# pstate							= event_handler CloseStatusDialog pstate
		= showError error pstate
	# pstate								= broadcast Nothing (AddedCleanModules new_module_ptrs) pstate
	# pstate								= appHeapsProject findABCFunctions pstate
	= warningStdEnv new_module_ptrs (event_handler CloseStatusDialog pstate)
	where
		examine :: ![ModulePtr] !*PState -> (![CName], ![(String,String)], !*PState)
		examine [ptr:ptrs] pstate
			# (mod, pstate)					= accHeaps (readPointer ptr) pstate
			# name							= mod.pmName
			# location						= (mod.pmName +++ ".dcl", mod.pmPath +++ "\\")
			# (names, locations, pstate)	= examine ptrs pstate
			= ([name:names], [location:locations], pstate)
		examine [] pstate
			= ([], [], pstate)

// ------------------------------------------------------------------------------------------------------------------------
openModules :: !(StatusDialogEvent -> *PState -> *PState) ![CName] ![CName] ![ModulePtr] !SearchPaths !*DclCache !*PState -> (!Error, (![ModulePtr], !*DclCache), !*PState)
// ------------------------------------------------------------------------------------------------------------------------
openModules event_handler [name:names] all_names new_ptrs search_paths cache pstate
	| isMember name all_names				= openModules event_handler names all_names new_ptrs search_paths cache pstate
	# pstate								= event_handler (NewMessage ("Compiling module " +++ name)) pstate
	# (ok, error_file, pstate)				= fopen (applicationpath "Errors.___") FWriteText pstate
	| not ok								= (pushError (X_OpenFile "Errors.___") OK, (DummyValue, cache), pstate)
	# ((ast, error_file, cache), pstate)	= accFiles (interface cache error_file) pstate
	# (_, pstate)							= fclose error_file pstate
	| isNo ast
		# (error, pstate)					= get_compile_errors pstate
		= (error, ([], cache), pstate)
	# ast									= fromYes ast
	# (path, pstate)						= find_path name search_paths.sp_paths pstate
	# pstate								= event_handler (NewMessage ("Converting module " +++ name)) pstate
	# heaps									= cache.cachedHeaps
	# (error, (new_ptr, heaps), pstate)		= accErrorHeapsProject (convert ast heaps (length new_ptrs) path) pstate
	# cache									= {cache & cachedHeaps = heaps}
	| isError error							= (error, (DummyValue, cache), pstate)
	# (new_mod, pstate)						= accHeaps (readPointer new_ptr) pstate
	# imported_dcls							= (fromJust new_mod.pmCompilerStore).csImports
	# imported_dcls							= removeMember name imported_dcls
	# imported_dcls							= removeMember "_predefined" imported_dcls
	= openModules event_handler (names ++ imported_dcls) [name:all_names] [new_ptr:new_ptrs] search_paths cache pstate
	where
		interface cache error_file files
			# predefs						= cache.cachedPredefs
			# hash_table					= cache.cachedHashTable
			# heaps							= cache.cachedHeaps
			# functions						= cache.cachedFunctions
			# dcls							= cache.cachedDcls
			# (mod_ident, hash_table)		= putIdentInHashTable name (IC_Module NoQualifiedIdents) hash_table
			# frontend_options				= {defaultFrontEndOptions & feo_up_to_phase = FrontEndPhaseConvertModules}
			// suspicious revisions:
			// 2 april -> 2 october:       added '\c f -> (c, f)' for 'ModTimeFunction *Files' argument
			// 2 april -> 2 october:       added '_' to ignore new Int output argument (before maindcl)
			# (opt_file_path_time,files) = fopenInSearchPaths mod_ident.boxed_ident.id_name ".icl" search_paths FReadData (\c f->(c,f)) files
			# (ast, functions, _, maindcl, predefs, hash_table, files, error_file, _, _, _, heaps)
											= frontEndInterface opt_file_path_time frontend_options mod_ident.boxed_ident search_paths dcls functions No False (\c f->(c,f))
												predefs hash_table files error_file stderr stderr No heaps
			# cache							= { cache	& cachedPredefs		= predefs
														, cachedHashTable	= hash_table
														, cachedHeaps		= heaps
														, cachedFunctions	= functions}
			| isNo ast						= ((No, error_file, cache), files)
			# (dcls, ast)					= (fromYes ast)!fe_dcls
			# cache							= { cache	& cachedDcls		= {{dcl \\ dcl <-: dcls} & [maindcl].dcl_has_macro_conversions=False}}
			= ((Yes ast, error_file, cache), files)
		
		convert ast heaps index path cheaps prj
			# (error, new_ptr, heaps, cheaps, prj)
											= convertFrontEndSyntaxTree ast heaps index path cheaps prj
			= (error, (new_ptr, heaps), cheaps, prj)
		
		isNo (Yes _)						= False
		isNo No								= True
		fromYes (Yes x)						= x
		
		get_compile_errors :: !*PState -> (Error, !*PState) 
		get_compile_errors pstate
			# (open_ok, error_file, pstate)		= fopen (applicationpath "Errors.___") FReadText pstate
			| not open_ok						= (pushError (X_OpenFile "Errors.___") OK, pstate)
			# (msgs, error_file)				= freadlines error_file
			# (close_ok, pstate)				= accFiles (fclose error_file) pstate
			| not close_ok						= (pushError (X_CloseFile "Errors.___") OK, pstate)
			= (foldr (\msg -> (\error -> pushError (X_External msg) error)) OK msgs, pstate)
	         
		freadlines :: !*File -> (![String], !*File)
		freadlines file
			# (ended, file)						= fend file
			|  ended							= ([], file)
			# (line, file)						= freadline file
			# (lines, file)						= freadlines file
			= (map remove_new_lines [line:lines], file)  
			where
				remove_new_lines :: String -> String
				remove_new_lines string
					= {c \\ c <- [goodchars \\ goodchars <-: string | goodchars <> '\n']}
		
		find_path :: !CName ![String] !*PState -> (!CName, !*PState)
		find_path file_name [path:paths] pstate
			# (ok, file, pstate)				= fopen (path +++ file_name +++ ".icl") FReadText pstate
			# (_, pstate)						= fclose file pstate
			| ok								= (path % (0, size path - 2), pstate)
			= find_path file_name paths pstate
		find_path file_name [] pstate
			= ("?", pstate)
openModules event_handler [] all_names new_ptrs paths cache pstate
	= (OK, (new_ptrs, cache), pstate)