/*
** Program: Clean Prover System
** Module:  OpenProject (.icl)
** 
** Author:  Maarten de Mol
** Created: 15 September 1999
*/

implementation module 
   OpenProject

import
   StdEnv,
   StdDebug,
   StdIO,
   Directory,
   StatusDialog,
   WarningStdEnv,
   Errors,
   FileMonad,
   States,
   CoreTypes,
   CoreAccess,
   Predefined,
   Conversion,
   Bind,
   frontend,
   RWSDebug

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
















// =================================================================================================================================================
// Modified version of compileModule from compile.icl
// -------------------------------------------------------------------------------------------------------------------------------------------------
ufrontEndInterface :: !FrontEndPhase !PFileName !SearchPaths !*DclCache !*File !*File !*File !*Files -> ((!*File, !*File, !*File, !Maybe *FrontEndSyntaxTree, !*DclCache), !*Files)
// -------------------------------------------------------------------------------------------------------------------------------------------------
ufrontEndInterface phase modname searchpaths cache error io out files
	# (mod_ident, hash_table)		= putIdentInHashTable modname (IC_Module NoQualifiedIdents) cache.cachedHashTable
	# frontend_options				= {defaultFrontEndOptions & feo_up_to_phase = phase}
	// suspicious revisions:
	// 2 april -> 2 october:       added '\c f -> (c, f)' for 'ModTimeFunction *Files' argument
	// 2 april -> 2 october:       added '_' to ignore new Int output argument (before maindcl)
	# (opt_file_path_time,files) = fopenInSearchPaths mod_ident.boxed_ident.id_name ".icl" searchpaths FReadData (\c f->(c,f)) files
	# (ast, functions, _, maindcl, predefs, hash_table, files, error, io, out, _, heaps)
									= frontEndInterface opt_file_path_time frontend_options mod_ident.boxed_ident searchpaths cache.cachedDcls cache.cachedFunctions No False (\c f -> (c,f))
										cache.cachedPredefs hash_table files error io out No cache.cachedHeaps
	# cache							= { cache	& cachedPredefs		= predefs
												, cachedHashTable	= hash_table
												, cachedHeaps		= heaps
												, cachedFunctions	= functions}
	| isNo ast						= ((error, io, out, Nothing, cache), files)
	# ast							= fromYes ast
	# (dcls, ast)					= ast!fe_dcls
	# cache							= { cache	& cachedDcls		= {{dcl \\ dcl <-: dcls} & [maindcl].dcl_has_macro_conversions=False}
									  }
	= ((error, io, out, Just ast, cache), files)
	where
		isNo (Yes x)			= False
		isNo No					= True
		
		fromYes (Yes x)			= x









// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PFileName :== String
:: PFilePath :== String
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
openFile :: !PFileName !Int !*PState -> (!Bool, !*File, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
openFile filename filemode pstate
   # ((open_ok, file), pstate)		= accFiles (own_fopen filename filemode) pstate
   = (open_ok, file, pstate)
   where
      own_fopen filename filemode fileenv
         # (open_ok, file, fileenv)    = fopen filename filemode fileenv
         = ((open_ok, file), fileenv)

// -------------------------------------------------------------------------------------------------------------------------------------------------
openProject :: !*PState -> (!Error, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
openProject pstate
	# (maybe_project_name, pstate)		= selectInputFile pstate
	| isNothing maybe_project_name		= (OK, pstate) // (pushError X_I_Did_Nothing OK, pstate)
	# project_name						= fromJust maybe_project_name
	= openNamedProject (fromJust maybe_project_name) pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
openNamedProject :: !String !*PState -> (!Error, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
openNamedProject project_name pstate
//	# ((error_code, maybe_prover_options), pstate)	= accFiles (ReadProverOptions project_name) pstate
	# (prj_directory, prj_file, prj_extension)		= splitPath project_name
	| prj_extension <> "prj"						= ([X_Internal "The extension of the project-file must be 'prj'."], pstate)
	# (error, prover_options, pstate)				= readProjectFile prj_directory prj_file pstate
	| isError error									= (error, pstate)
	# pstate										= openStatusDialog ("Opening project '" +++ prj_file +++ "'") (openStructuredProject prover_options) pstate
	# (error, pstate)								= pstate!ls.stRememberedError
	| isError error									= (error, pstate)
	= (OK, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
openStructuredProject :: !ProjectStructure !(StatusDialogEvent -> *PState -> *PState) !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
openStructuredProject project_structure status pstate
	# pstate								= {pstate & ls = {pstate.ls & stRememberedError = OK}}
	# project_name							= project_structure.main_module_name
	#! pstate								= status (NewMessage ("Opening project '" +++ project_name +++ "'.")) pstate
	# module_names							= [(project_name, project_structure.main_module_path): project_structure.icl_modules]
	# (error, modules, pstate)				= openModules status 0 project_structure module_names pstate
	| isError error
		# error		= pushError (X_OpenProject project_name) error
		# pstate	= {pstate & ls = {pstate.ls & stRememberedError = error}}
		= status CloseStatusDialog pstate
	#! pstate								= status (NewMessage ("Binding project '" +++ project_name +++ "'.")) pstate
	# (options, pstate)						= pstate!ls.stOptions
	# state									= pstate.ls
	# heaps									= state.stHeaps
	# prj									= state.stProject
	# (error, heaps, prj)					= bindToProject modules heaps prj
	| isError error
		# error		= pushError (X_OpenProject project_name) error
		# state		= {state & stHeaps = heaps, stProject = prj}
		# pstate	= {pstate & ls = state}
		# pstate	= {pstate & ls.stRememberedError = error}
		= status CloseStatusDialog pstate
	# state									= {state & stHeaps = heaps, stProject = prj}
	# pstate								= {pstate & ls = state}
	# pstate								= status Finished pstate
	# pstate								= status CloseStatusDialog pstate
	# pstate								= broadcast Nothing (AddedCleanModules modules) pstate
	# pstate								= appHeapsProject findABCFunctions pstate
	# pstate								= warningStdEnv modules pstate
	= pstate
   
// =================================================================================================================================================
// Need to add: check if .pcl exists, check if it is up-to-date
// -------------------------------------------------------------------------------------------------------------------------------------------------
openModules :: !(StatusDialogEvent -> *PState -> *PState) !Int !ProjectStructure ![(PFileName, PFilePath)] !*PState -> (!Error, ![ModulePtr], !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
openModules status module_index project_structure files pstate
	# (cache, pstate)						= newDclCache pstate
	# (error, ptrs, cache, pstate)			= open_modules status module_index project_structure files cache pstate
	# pstate								= keepDclCache cache pstate
	= (error, ptrs, pstate)
	where
		open_modules :: !(StatusDialogEvent -> *PState -> *PState) !Int !ProjectStructure ![(PFileName, PFilePath)] !*DclCache !*PState -> (!Error, ![ModulePtr], !*DclCache, !*PState)
		open_modules status module_index project_structure [] cache pstate
			= (OK, [], cache, pstate)
		// NO CACHING //
		/*
		open_modules status module_index project_structure [(module_name, module_path):rest_modules] cache pstate
			#! pstate											= status (NewMessage ("Compiling module '" +++ module_name +++ "'.")) pstate
			# (error, maybe_syntaxtree, dummy_cache, pstate)	= compileIclModule module_name module_path project_structure DummyValue pstate
			| isError error										= (pushError (X_OpenModule module_name) error, [], cache, pstate)
			# syntaxtree										= fromJust maybe_syntaxtree
			#! pstate											= status (NewMessage ("Converting module '" +++ module_name +++ "'.")) pstate
			# heaps												= dummy_cache.cachedHeaps
			# state												= pstate.ls
			# (error, compiled_module, heaps, cheaps, prj)		= convertFrontEndSyntaxTree syntaxtree heaps module_index state.stHeaps state.stProject
			# state												= {state & stHeaps = cheaps, stProject = prj}
			# pstate											= {pstate & ls = state}
			| isError error										= (pushError (X_OpenModule module_name) error, [], cache, pstate)
			# (error, compiled_modules, cache, pstate)			= open_modules status (module_index + 1) project_structure rest_modules cache pstate
			| isError error										= (pushError (X_OpenModule module_name) error, [], cache, pstate)
			= (OK, [compiled_module:compiled_modules], cache, pstate)
		*/
		// CACHING //
		open_modules status module_index project_structure [(module_name, module_path):rest_modules] cache pstate
			#! pstate											= status (NewMessage ("Compiling module '" +++ module_name +++ "'.")) pstate
			# (error, maybe_syntaxtree, cache, pstate)			= compileIclModule module_name module_path project_structure cache pstate
			| isError error										= (pushError (X_OpenModule module_name) error, [], cache, pstate)
			# syntaxtree										= fromJust maybe_syntaxtree
			#! pstate											= status (NewMessage ("Converting module '" +++ module_name +++ "'.")) pstate
			# heaps												= cache.cachedHeaps
			# state												= pstate.ls
			# (error, module_ptr, heaps, cheaps, prj)			= convertFrontEndSyntaxTree syntaxtree heaps module_index module_path state.stHeaps state.stProject
			# cache												= {cache & cachedHeaps = heaps}
			# state												= {state & stHeaps = cheaps, stProject = prj}
			# pstate											= {pstate & ls = state}
			| isError error										= (pushError (X_OpenModule module_name) error, [], cache, pstate)
			# (error, module_ptrs, cache, pstate)				= open_modules status (module_index + 1) project_structure rest_modules cache pstate
			| isError error										= (pushError (X_OpenModule module_name) error, [], cache, pstate)
//			# compiled_module									= {compiled_module & pmPath = module_path}
			= (OK, [module_ptr:module_ptrs], cache, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
compileIclModule :: !PFileName !PFilePath !ProjectStructure !*DclCache !*PState -> (!Error, !Maybe *FrontEndSyntaxTree, !*DclCache, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
compileIclModule module_name module_path project_structure cache pstate
	# (open_error_ok, error_file, pstate)		= openFile (applicationpath "Errors.___") FWriteText pstate
	| not open_error_ok							= (pushError (X_OpenFile "Errors.___") OK, Nothing, cache, pstate)
	# locations									= [(project_structure.main_module_name +++ ".icl", project_structure.main_module_path +++ "\\")] ++
												   (map (\(name, path) -> (name +++ ".dcl", path +++ "\\")) project_structure.dcl_modules) ++
												   (map (\(name, path) -> (name +++ ".icl", path +++ "\\")) project_structure.icl_modules)
	# searchpaths								= {sp_paths = [], sp_locations = locations}
	# (phase, pstate)							= pstate!ls.stFrontEndPhase
	# ((error_file, _, _, ast, cache), pstate)	= accFiles (ufrontEndInterface phase module_name searchpaths cache error_file /*dummy_file1*/stderr /*dummy_file2*/stderr) pstate
	# (close_error_ok, pstate)					= accFiles (fclose error_file) pstate
	| not close_error_ok 						= (pushError (X_CloseFile "Errors.___") OK, Nothing, cache, pstate)
	| isNothing ast								= let (errors, pstate1) = get_compile_errors pstate
												   in (pushError (X_CompileModule module_name) errors, Nothing, cache, pstate1)
	= (OK, ast, cache, pstate)
	where
		dummy_file1		= abort ("Internal error while compiling module '" +++ module_name +++ "'. The compiler tried to write to stdin.")
		dummy_file2		= abort ("Internal error while compiling module '" +++ module_name +++ "'. The compiler tried to write to stdout.")
	      
		// -------------------------------------------------------------------------------
		get_compile_errors :: !*PState -> (Error, !*PState) 
		// -------------------------------------------------------------------------------
		get_compile_errors pstate
			# (open_ok, error_file, pstate)		= openFile (applicationpath "Errors.___") FReadText pstate
			| not open_ok						= (pushError (X_OpenFile "Errors.___") OK, pstate)
			# (msgs, error_file)				= freadlines error_file
			# (close_ok, pstate)				= accFiles (fclose error_file) pstate
			| not close_ok						= (pushError (X_CloseFile "Errors.___") OK, pstate)
			= (foldr (\msg -> (\error -> pushError (X_External msg) error)) OK msgs, pstate)
	         
		// --------------------------------------------------------------------------------
		freadlines :: !*File -> (![String], !*File)
		// --------------------------------------------------------------------------------
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






















// -------------------------------------------------------------------------------------------------------------------------------------------------
:: TempStructure =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ tempAppP			:: !String
	, tempMainPath		:: !String							// may start with {Project} or {Application}
	, tempModules		:: ![(String,String)]				// may start with {Project} or {Application}; [(directory,name)]; no extensions stored
	, tempPrjP			:: !String
	}
instance DummyValue TempStructure
	where DummyValue	= {tempAppP = "", tempMainPath = "", tempModules = [], tempPrjP = ""}

// -------------------------------------------------------------------------------------------------------------------------------------------------
convertTempStructure :: !String !TempStructure -> ProjectStructure
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertTempStructure project_name temp
	# modules											= map expand_path temp.tempModules
	# main_path											= expandPath temp.tempPrjP temp.tempAppP temp.tempMainPath
	=	{ project_name			= project_name
		, project_paths			= []
		, main_module_name		= project_name
		, main_module_path		= main_path
		, icl_modules			= modules
		, dcl_modules			= [(project_name, main_path): modules]
		}
	where
		expand_path (directory, file)
			= (file, expandPath temp.tempPrjP temp.tempAppP directory)

// -------------------------------------------------------------------------------------------------------------------------------------------------
readProjectFile :: !String !String !*PState -> (!Error, !ProjectStructure, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
readProjectFile project_path project_name pstate
	# (error, temp, pstate)								= applyFileM project_path project_name "prj" FReadText DummyValue read pstate
	| isError error										= (error, DummyProjectStructure, pstate)
	# struct											= convertTempStructure project_name temp
	= (OK, struct, pstate)
	where
		read :: FileM TempStructure TempStructure
		read
			=	lookAhead
					[ ("AppP:",	False,	read_app_path)
					, ("Path:",	False,	read_icl_location)
					, ("PrjP:", False,	read_proj_path)
					] skipLine							>>= \_ ->
				ifEOF returnState read
		
		read_app_path :: FileM TempStructure Dummy
		read_app_path
			=	readToken "AppP:"						>>>
				readWhile (\c -> c <> '\n')				>>= \path ->
				accStates (store_app path)				>>>
				ifEOF (returnM Dummy) advanceLine
		
		read_icl_location :: FileM TempStructure Dummy
		read_icl_location
			=	readToken "Path:"						>>>
				readWhile (\c -> c <> '\n')				>>= \path ->
				accStates (store_icl path)				>>>
				ifEOF (returnM Dummy) advanceLine
		
		read_proj_path :: FileM TempStructure Dummy
		read_proj_path
			=	readToken "PrjP:"						>>>
				readWhile (\c -> c <> '\n')				>>= \path ->
				accStates (store_prj path)				>>>
				ifEOF (returnM Dummy) advanceLine
		
		store_app :: !String !String !Int !Int !TempStructure !*PState -> (!Error, !Dummy, !TempStructure, !*PState)
		store_app path _ _ _ temp pstate
			= (OK, Dummy, {temp & tempAppP = path}, pstate)
		
		store_icl :: !String !String !Int !Int !TempStructure !*PState -> (!Error, !Dummy, !TempStructure, !*PState)
		store_icl path _ _ _ temp pstate
			# (directory, name, extension)				= splitPath path
			| extension <> "icl"						= (OK, Dummy, temp, pstate)
			= case (name == project_name) of
				True									-> (OK, Dummy, {temp & tempMainPath = directory}, pstate)
				False						 			-> (OK, Dummy, {temp & tempModules = [(directory, name): temp.tempModules]}, pstate)
		
		store_prj :: !String !String !Int !Int !TempStructure !*PState -> (!Error, !Dummy, !TempStructure, !*PState)
		store_prj path _ _ _ temp pstate
			= (OK, Dummy, {temp & tempPrjP = path}, pstate)
		

// =================================================================================================================================================
// Replace {Project} and {Application} in relative paths.
// -------------------------------------------------------------------------------------------------------------------------------------------------
expandPath :: !String !String !String -> String
// -------------------------------------------------------------------------------------------------------------------------------------------------
expandPath prjP appP path
	| path%(0,8) == "{Project}"							= prjP +++ path%(9,size path-1)
	| path%(0,12) == "{Application}"					= appP +++ path%(13,size path-1)
	= path

// =================================================================================================================================================
// Convert to: (path, file_name, file_extension).
// Preconditions: must be a '.' in the path (no '\' required though)
// -------------------------------------------------------------------------------------------------------------------------------------------------
splitPath :: !String -> (String, String, String)
// -------------------------------------------------------------------------------------------------------------------------------------------------
splitPath path
	# last_sep											= find_last_char '\\' (-1) 0 (size path-1) path
	# (directory, file)									= if (last_sep < 0) ("", path) (path%(0,last_sep-1), path%(last_sep+1, size path-1))
	# last_dot											= find_last_char '.' (-1) 0 (size file-1) file
	# (name, extension)									= (file%(0,last_dot-1), file%(last_dot+1, size file-1))
	= (directory, name, extension)
	where
		find_last_char :: !Char !Int !Int !Int !String -> Int
		find_last_char char previous index last_index path
			| index > last_index						= previous
			= case path.[index] == char of
				True									-> find_last_char char index (index+1) last_index path
				False									-> find_last_char char previous (index+1) last_index path