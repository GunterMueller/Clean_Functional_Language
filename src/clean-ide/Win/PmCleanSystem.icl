implementation module PmCleanSystem

import StdArray, StdBool, StdChar, StdFunc, StdInt, StdList, StdEnum
import StdMaybe
from StdMisc import abort, undef
import _SystemStrictLists

from Platform import DirSeparator,DirSeparatorString

import Directory

import PmCompilerOptions, UtilStrictLists
import PmPath
import PmCallBack

import UtilNewlinesFile
import WriteOptionsFile

from PmParse import IsTypeSpec, IsImportError13, IsImportError20
from linkargs import ReadLinkErrors,WriteLinkOpts,:: LinkInfo`(..),:: LPathname
import thread_message
import lib

import UtilIO

from Platform import TempDir

:: OSToolbox:==Int

tooltempdir =: TempDir

//--

// kernel_library is required by the _system _startup combo and should be encoded there
standardStaticLibraries :: !Processor !LinkMethod -> List String
standardStaticLibraries _ method
	= case method of
		LM_Static	-> ("kernel_library" :! morelibs)
		LM_Dynamic	-> ("kernel_library" :! "StaticClientChannel_library" :! morelibs)
/*
		LM_Eager	-> ("kernel_library" :! "StaticClientChannel_library" :! Nil)
		LM_Dynamic	-> ("kernel_library" :! "ClientChannel_library" :! Nil)
*/
morelibs	// Note that these dependencies are introduced by StdEnv and should be encoded there.
	= "user_library" :! "gdi_library" :! "comdlg_library" :! Nil

standardObjectFiles :: !Bool !Bool !Bool !Processor !Bool -> List String
standardObjectFiles stack_traces callgraph_profiling profiling _ use_64_bit_processor
	#! startup1_files =
		if stack_traces
			[|"_startup1Trace.o"]
			(if profiling
				(if callgraph_profiling
					[|"_startup1ProfileGraph.o", "_startup1ProfileGraphB.o"]
					[|"_startup1Profile.o"])
				[|"_startup1.o"])
	| not use_64_bit_processor
		= Concat [|"_startup0.o" : startup1_files] [|"_startup2.o", "_system.o"]
		= Concat [|"_startup0.o" : startup1_files] [|"_startup2.o", "_startup3.o", "_startup4.o", "_system.o"]

//-- interface to static libraries...

getLibs :: ![String] !*Files -> (!(![String],![String]),!*Files)
getLibs [] files = (([],[]),files)
getLibs [lib:libs] files
	# (errs,slibs,files)		= getLib lib files
	# ((errs`,slibs`),files)	= getLibs libs files
	= ((errs++errs`,slibs++slibs`),files)
getLib lib files
	# (errs,slibs,files)	=  OpenArchive lib files
	# slibs					= map RemoveSuffix slibs
	= (errs,slibs,files)

:: CompilerProcessHandlesAndId = {
	compiler_thread_id :: !Int,
	compiler_thread_handle :: !Int,
	compiler_process_handle :: !Int
   }

:: CompilerProcessIds :== [CompilerProcessHandlesAndId]

NoCompilerProcessIds :: CompilerProcessIds
NoCompilerProcessIds = []

ClearCompilerCache :: !String !String !.a -> (!Int,!.a)
ClearCompilerCache _ _ ps = (0,ps)

ClearCompilerCaches :: !CompilerProcessIds !.a -> (!Int,!.a)
ClearCompilerCaches _ ps = (0,ps)

QuitCleanCompiler :: !Bool !CompilerProcessIds !*World -> *World
QuitCleanCompiler async compiler_process_ids io
	| async
		= quit_compilers compiler_process_ids io;
		with
			quit_compilers [{compiler_thread_id,compiler_process_handle}:compiler_process_ids] io
				# wm_number=get_message_number;
				# r=send_string_to_thread compiler_thread_id compiler_process_handle wm_number ("exit\0")
				| r==r
					= quit_compilers compiler_process_ids io;
			quit_compilers [] io
				= io;
	= io;

ExitCleanCompiler :: !*(!*CompilingInfo,*env) -> *(!*CompilingInfo,*env)
ExitCleanCompiler prog=:(CompilingInfo (CompilerProcess compiler_thread_id compiler_thread_handle compiler_process_handle), ps)
	# wm_number=get_message_number;
	# r=send_string_to_thread compiler_thread_id compiler_process_handle wm_number ("exit\0")
	| /*trace_tn ("ExitCleanCompiler "+++toString r+++"\n") &&*/ r==0
		= prog
		= (CompilingInfo NoCompiler,ps);
ExitCleanCompiler prog
	= prog

//--

::	CodeGenerateAsmOrCode	= AsmGeneration	| CodeGeneration

instance == CodeGenerateAsmOrCode
where
//	(==) :: !CodeGenerateAsmOrCode !CodeGenerateAsmOrCode -> Bool
	(==) AsmGeneration AsmGeneration
		=	True
	(==) CodeGeneration CodeGeneration
		=	True
	(==) _ _
		=	False

::	CompileOrCheckSyntax	= SyntaxCheck | Compilation

instance == CompileOrCheckSyntax
where
//	(==) :: !CompileOrCheckSyntax !CompileOrCheckSyntax -> Bool
	(==) SyntaxCheck SyntaxCheck
		=	True
	(==) Compilation Compilation
		=	True
	(==) _ _
		=	False
/*
::	CompileClearCache	= ClearCache | Don`tClearCache

instance == CompileClearCache
where
	(==) :: CompileClearCache CompileClearCache -> Bool
	(==) ClearCache ClearCache
		=	True
	(==) Don`tClearCache Don`tClearCache
		=	True
	(==) _ _
		=	False
*/
::	CompilerMsg
	= 	CompilerOK
	| 	SyntaxError
	| 	Patherror Pathname

instance == CompilerMsg
where
	(==) CompilerOK CompilerOK = True
	(==) SyntaxError SyntaxError = True
	(==) (Patherror _) (Patherror _) = True
	(==) _ _ = False
	
::	WindowFun env :== ([String]) -> env -> env

//-- Synchronous compilation stuff...

:: ProjectCompilerOptions = {
	pco_memory_profiling :: !Bool,
	pco_time_profiling :: !Bool,
	pco_callgraph_profiling :: !Bool,
	pco_desc_exl :: !Bool,
	pco_dynamics :: !Bool,
	pco_generic_fusion :: !Bool,
	pco_link_dynamic :: !Bool
   }

Compile ::
	!String !Bool !Bool !(WindowFun *env) !(WindowFun *env) !CompileOrCheckSyntax !ModuleDirAndName !Pathname
	!(List Pathname) !ProjectCompilerOptions !CompilerOptions !Pathname !CompilerProcessIds !*env
	-> (!Pathname,!CompilerMsg,!CompilerProcessIds,!*env)
	| FileEnv env
Compile
	cocl` use_compiler_process_ids write_module_times errwin typewin compileOrCheckSyntax mdn path paths project_compiler_options
	co=:{CompilerOptions | listTypes} startupdir compiler_process_ids ps
	# (cocl_ok,cocl,cocldir)	= mangleCompiler cocl` startupdir	// platform dependant mangling...
	| not cocl_ok
		# ps					= errwin [cocl] ps
		= ("",SyntaxError,compiler_process_ids,ps)
	#	out_file_name		= out_file_path tooltempdir dummy_slot
		errors_file_name	= errors_file_path tooltempdir dummy_slot
	#	command = cocl +++ write_module_times_string +++
					CompileBuildCommand out_file_name errors_file_name compileOrCheckSyntax path paths project_compiler_options co
		(didit, exitcode, os4) = call_process_with_directory command cocldir 99
	    diditall               = if (os4 == 99) didit didit
	| not diditall
		# ps	= errwin (["Error: Unable to run compiler: "+++cocl +++ " :"+++toString exitcode]) ps
		= ("",SyntaxError,compiler_process_ids,ps)
	# (path,mess,env) =	CompileHandleExitCode exitcode cocl tooltempdir dummy_slot errwin typewin mdn listTypes ps
	= (path,mess,compiler_process_ids,env)
where
	dummy_slot = 0
	write_module_times_string = if write_module_times " -wmt " " "

mangleCompiler ccstring` startupdir
	# (ccstring`,rem)			= splitOptions ccstring`
	# (opts,opts`)				= splitOptions rem
	# (shortOK,ccstring)		= GetShortPathName (startupdir +++ "\\" +++ ccstring` +++ "\0")
	| not shortOK
		# line				= "Error: Unable to get short path name '" +++ (startupdir +++ "\\" +++ ccstring`) +++ "'."
		= (False,line,"")
	# cocl = ccstring % (0, size ccstring - 2)
	# cocldir = RemoveFilename cocl
	# opts = if (size opts==0 || opts.[0]==' ') opts (" "+++opts)
	# opts` = if (size opts`==0 || opts`.[0]==' ') opts` (" "+++opts`)
	# cocl = cocl +++. opts +++. opts`
	= (True,cocl,cocldir)

mangleCompiler2 ccstring` startupdir
	# (ccstring`,rem)			= splitOptions ccstring`
	# (opts,opts`)				= splitOptions rem
	# (shortOK,ccstring)		= GetShortPathName (startupdir +++ "\\" +++ ccstring` +++ "\0")
	| not shortOK
		# line				= "Error: Unable to get short path name '" +++ (startupdir +++ "\\" +++ ccstring`) +++ "'."
		= (False,line,"","","")
	# cocl = ccstring % (0, size ccstring - 2)
	# cocldir = RemoveFilename cocl
	= (True,cocl,cocldir,opts,opts`)

//-- Asynchronous compilation stuff...

:: ThreadId
	:==	Int
:: ExitCode
	:== Int

CompileStartCommand :: !String !Bool !(WindowFun *env) !CompileOrCheckSyntax !Pathname !(List Pathname) !Int !ProjectCompilerOptions
						!CompilerOptions !Pathname !CompilerProcessIds !*env
										 -> (!Bool,!CompilerProcessIds,!*env) | FileEnv env
CompileStartCommand cocl` write_module_times errwin compileOrCheckSyntax path paths slot project_compiler_options
					co startupdir compiler_process_ids ps
	# (cocl_ok,cocl,cocl_dir,cocl_startup,options)	= mangleCompiler2 cocl` startupdir	// platform dependant mangling...
	| not cocl_ok
		# ps = errwin [cocl] ps
		= (False,compiler_process_ids,ps)
	# out_file_name		=  out_file_path tooltempdir slot
	# errors_file_name	=  errors_file_path tooltempdir slot
	# cocl_arguments
		= " -id " +++toString slot+++" "+++options +++ write_module_times_string +++. 
			CompileBuildCommand out_file_name errors_file_name compileOrCheckSyntax path paths project_compiler_options co
	# (compile_ok,compiler_process_ids,ps) = start_compile_with_cache cocl slot cocl_dir cocl_startup cocl_arguments compiler_process_ids ps;
	| not compile_ok
  		# ps = errwin ["Error: Unable to run compiler: "+++cocl] ps
  		= (False,compiler_process_ids,ps)
	= (True,compiler_process_ids,ps)
where
	write_module_times_string = if write_module_times " -wmt " " "

dispatch_null_message_hook :: Int;
dispatch_null_message_hook = code {
	pushLc dispatch_null_message_hook
}

start_compile_with_cache :: String Int String String String CompilerProcessIds *env -> (!Bool,!CompilerProcessIds,!*env)
start_compile_with_cache path slot directory startup_arguments arguments compiler_process_ids ps
	| slot<length compiler_process_ids
		# compiler_handles_and_id = compiler_process_ids !! slot
		= start_compile_with_cache2 path compiler_handles_and_id directory arguments compiler_process_ids ps
	# thread_id=get_current_thread_id;
	# begin_arguments=startup_arguments+++" -ide "+++int_to_hex thread_id;
	# (r,compiler_thread_id,compiler_thread_handle,compiler_process_handle)
		= start_compiler_process (IF_BATCHBUILD_OR_IDE 0 dispatch_null_message_hook) (path+++"\0") (directory+++"\0") ("\""+++path+++"\" "+++begin_arguments+++"\0");
	| r==0
		= (False,compiler_process_ids,ps)
	# compiler_handles_and_id = {compiler_thread_id=compiler_thread_id,compiler_thread_handle=compiler_thread_handle,compiler_process_handle=compiler_process_handle}
	# compiler_process_ids = compiler_process_ids++[compiler_handles_and_id]
	= start_compile_with_cache2 path compiler_handles_and_id directory arguments compiler_process_ids ps

start_compile_with_cache2 :: {#.Char} CompilerProcessHandlesAndId {#.Char} {#.Char} CompilerProcessIds *env -> (!Bool,!CompilerProcessIds,!*env)
start_compile_with_cache2 path {compiler_thread_id,compiler_thread_handle,compiler_process_handle} directory arguments compiler_process_ids ps
	# wm_number=get_message_number
	# r=send_string_to_thread compiler_thread_id compiler_process_handle wm_number ("cocl "+++arguments+++"\0")
	| r==0
		= (False,compiler_process_ids,ps)
	= (True,compiler_process_ids,ps)

:: CompilePollCompletedResult = NoFinishedCompiler | UnknownFinishedCompiler | FinishedCompiler !Int !Int

CompilePollCompleted :: !CompilerProcessIds !*env -> (!CompilePollCompletedResult, !*env) | FileEnv env
CompilePollCompleted compiler_process_ids ps
	= IF_BATCHBUILD_OR_IDE

		(let
			wm_number=get_message_number
			(r,compiler_id,exit_code) = get_integers_from_message wm_number
		 in
		   if (r==0)
			(NoFinishedCompiler,ps)
			(FinishedCompiler compiler_id exit_code,ps))

		(let
			(compiler_id,exit_code) = get_finished_compiler_id_and_exit_code
		 in
		   if (compiler_id<0)
			(NoFinishedCompiler,ps)
			(FinishedCompiler compiler_id exit_code,ps));

get_finished_compiler_id_and_exit_code :: (!Int/*compiler_id*/,!Int/*exit_code*/);
get_finished_compiler_id_and_exit_code = code {
	ccall get_finished_compiler_id_and_exit_code ":II"
 }

//-- Persistent compilation stuff...synchronous for now...

CompilePersistent ::
	!String !Bool !(WindowFun *env) !(WindowFun *env) !CompileOrCheckSyntax !ModuleDirAndName
	!(List Pathname) !ProjectCompilerOptions !CompilerOptions !Pathname !*CompilingInfo !*env
	-> (!*CompilingInfo,!(!*env, !Pathname, !CompilerMsg))
	| FileEnv env
CompilePersistent cocl` write_module_times errwin typewin compileOrCheckSyntax mdn paths project_compiler_options
	co=:{CompilerOptions | listTypes} startupdir cstate env

	# (cocl_ok,cocl,cocl_dir,cocl_startup,options)	= mangleCompiler2 cocl` startupdir	// platform dependant mangling...
	| not cocl_ok
		# env					= errwin [cocl] env
		= (cstate,(env,"",SyntaxError))

	#	out_file_name		=  out_file_path tooltempdir dummy_slot
		errors_file_name	=  errors_file_path tooltempdir dummy_slot
	# cocl_arguments
		= options +++ write_module_times_string +++.
		  CompileBuildCommand out_file_name errors_file_name compileOrCheckSyntax mdn.mdn_name paths project_compiler_options co
//	# cstate = NotCompiling
//	# cocl = startupdir+++toString dirseparator +++"cocl.exe";
	# (compile_ok,exitcode,(cstate,env)) = compile_with_cache cocl cocl_dir cocl_startup cocl_arguments (cstate,env);
	| not compile_ok
  		# env = errwin ["Error: Unable to run compiler: "+++cocl +++ " :"+++toString exitcode] env
  		= (cstate,(env,"",SyntaxError))
	# (path,mess,env) = CompileHandleExitCode exitcode cocl tooltempdir dummy_slot  errwin typewin mdn listTypes env
	=	(cstate,(env,path,mess))
where
	dummy_slot = 0
	write_module_times_string = if write_module_times " -wmt " " "

//-- Generic Compilation stuff...

CompileBuildCommand :: !String !String !CompileOrCheckSyntax !Pathname !(List Pathname) !ProjectCompilerOptions !CompilerOptions -> String
CompileBuildCommand out_file_name errors_file_name compileOrCheckSyntax path paths project_compiler_options co
	= MakeCompilerOptionsString
		compileOrCheckSyntax
		project_compiler_options
		co
		+++ (quoted_string path)
        +++ " -P " +++ quoted_string (ConcatenatePath paths)
		+++ " -RE "+++ quoted_string errors_file_name
		+++ " -RO "+++ quoted_string out_file_name;

CompileHandleExitCode :: !Int !String !String !Int !(WindowFun *env) !(WindowFun *env) !ModuleDirAndName
				!ListTypes !*env -> (!Pathname,!CompilerMsg,!*env) | FileEnv env
CompileHandleExitCode exitcode cocl startupdir slot errwin typewin mdn listTypes ps
	#	out_file_name		=  out_file_path tooltempdir slot
		errors_file_name	=  errors_file_path tooltempdir slot
	#	((type_text_not_empty,type_text),ps)
			= accFiles (ReadTypesInfo (listTypes<>NoTypes) out_file_name) ps
		((errors,errors_and_messages_not_empty,errors_and_messages),ps)
			= accFiles (ReadErrorsAndWarnings errors_file_name) ps
	| exitcode <> 0 && not errors_and_messages_not_empty =	// werkt dit ook voor persistent versie?
		( ""
		, SyntaxError
		, errwin (	[  "Error: Compiler crashed: "+++cocl
					: if (errors == CompilerOK) ["Unable to open Errors file"] []
					]) ps
		)
	#	abcpath			= ModuleDirAndNameToABCSystemPathname mdn
		ps				= (if type_text_not_empty (typewin (StrictListToList type_text)) id) ps
		ps				= (if errors_and_messages_not_empty (errwin (StrictListToList errors_and_messages)) id) ps
		errors			= case exitcode of
							0	-> CompilerOK
							_	-> errors
     = (abcpath,errors,ps)

out_file_path :: String Int -> String
out_file_path tooltempdir slot
	=	file_path tooltempdir "out" slot

errors_file_path :: String Int -> String
errors_file_path tooltempdir slot
	=	file_path tooltempdir "errors" slot

file_path :: String String Int -> String
file_path dir base_name slot
	=	dir +++ DirSeparatorString +++ base_name +++ (if (slot == 0) "" (toString slot))

ConcatenatePath :: (List Pathname) -> String
/* old version
ConcatenatePath Nil             = ""
ConcatenatePath (path :! rest ) = path +++ ";" +++ ConcatenatePath rest
*/
ConcatenatePath ss
	# s = createArray (sSize ss) ';'
	= sUpdate 0 s ss
where
	sSize Nil = 0
	sSize (string :! Nil) = size string
	sSize (string :! rest) = size string + 1 + sSize rest
	
	sUpdate i s Nil = s
	sUpdate i s (string :! Nil)
		# (_,s) = sU (size string) i 0 s string
		= s
	sUpdate i s (string :! rest)
		# (i,s) = sU (size string) i 0 s string
		# i = inc i
		= sUpdate i s rest
	
	sU l i j s h
		| j >= l = (i,s)
		# s = update s i h.[j]
		= sU l (inc i) (inc j) s h

ReadTypesInfo :: !Bool !Pathname !*Files -> ((!Bool,!(List String)),!*Files)
ReadTypesInfo readtypes	path env
	| not readtypes
		= ((False,Nil),env)
	#	(opened,file,env)			= fopen path FReadText env
	| not opened
		= ((False,Nil),env)
	#	(typelist,types_read,file`)	= ReadTypeMsg file
		(_,env)						= fclose file` env
	= ((types_read,typelist),env)
	

ReadTypeMsg :: !*File -> (!List String,!Bool,!*File)
ReadTypeMsg file
	#	(string,file)					= freadline file
		(eof,file)						= fend file
	| eof && IsTypeSpec string
		= (Strip string :! Nil,True,file)
	| eof
		= (Nil,False,file)
	#	(typeslist,types_read,file)	= ReadTypeMsg file
	= (Strip string :! typeslist,types_read,file)

Strip "" = ""
Strip s
	#! last = dec (size s)
	#! char = s.[last]
	| char == '\n' || char == '\r'
		= Strip (s % (0,dec last))
	= s

ReadErrorsAndWarnings :: !Pathname !*Files -> ((!CompilerMsg, !Bool, !(List String)), !*Files)
ReadErrorsAndWarnings path env
	#	(opened,file,env)	= fopen path FReadText env
	| not opened
		= ((CompilerOK,False,Nil),env)
	#	(errors,errors_and_warnings_read,errlist,file`) = ReadErrorAndWarningMessages file
		(_,env) = fclose file` env
	= ((errors,errors_and_warnings_read,errlist),env)
	
ReadErrorAndWarningMessages :: !*File -> (!CompilerMsg,!Bool,!List String,!*File)
ReadErrorAndWarningMessages file
	#!	(string, file1)					= freadline file
		(eof,file2)						= fend file1
		(is_import_error13,path13)		= IsImportError13 string
		(is_import_error20,path20)		= IsImportError20 string
	# (is_import_error,path) = case is_import_error13 of
			True	-> (is_import_error13,path13)
			_		-> (is_import_error20,path20)
	| eof
		#!	not_empty_or_newline 		= (size string)<>0 && string.[0]<>'\n'
		= (if is_import_error (Patherror path) SyntaxError,not_empty_or_newline,Strip string :! Nil,file2)
	#	(path_error,_,errlist,file3) = ReadErrorAndWarningMessages file2
	= (if is_import_error (Patherror path) path_error,True,Strip string:!errlist,file3)

MakeCompilerOptionsString :: !CompileOrCheckSyntax !ProjectCompilerOptions !CompilerOptions -> String
MakeCompilerOptionsString compileOrCheckSyntax
		{pco_memory_profiling,pco_time_profiling,pco_callgraph_profiling,pco_desc_exl,pco_generic_fusion,pco_dynamics,pco_link_dynamic}
		{neverMemoryProfile, neverTimeProfile,sa,gw,gc,listTypes,attr,reuseUniqueNodes,fusion}
	= (add_dynamics_options (add_fusion_option (add_exl_option
		(checksyntax +++ timeProfileSwitch +++ callgraphProfileSwitch +++ memoryProfileSwitch +++ strictness +++ warnings +++ comments +++listtypes+++show_attr+++reuse)
	   ))) +++" "
where
	memoryProfileSwitch
		| (not neverMemoryProfile && pco_memory_profiling) || pco_desc_exl || pco_link_dynamic
			= " -desc"
			= ""
	timeProfileSwitch
		| not neverTimeProfile && pco_time_profiling
			= " -pt"
			= ""
	callgraphProfileSwitch
		| not neverTimeProfile && pco_callgraph_profiling
			= " -pg"
			= ""
	strictness
		| sa
			= ""
			= " -sa"
	warnings
		| gw
			= ""
			= " -w"
	comments
		| gc
			= " -d"
			= ""
	listtypes
		| listTypes == InferredTypes
			= " -lt"
		| listTypes == AllTypes
			= " -lat"
		| listTypes == StrictExportTypes
			= " -lset"
			= ""
	show_attr
		| attr
			= ""
			= " -lattr"
	checksyntax
		| compileOrCheckSyntax == SyntaxCheck
			= " -c"
			= ""
	reuse
		| reuseUniqueNodes
			= " -ou"
			= ""
	add_exl_option s = if (pco_desc_exl || pco_link_dynamic) (s+++" -exl") s

	add_fusion_option s
		= case fusion of FusionOn -> s+++" -fusion"; FusionDefault | pco_generic_fusion -> s+++" -generic_fusion"; _ -> s

	add_dynamics_options s
		| pco_link_dynamic
			= s+++" -tcl -dynamics"
		| pco_dynamics
			= s+++" -dynamics"
			= s

/* Generates code for the given file:
*/	
/*
watcom_quoted_string string = "\"" +++ escape_specials 0 string +++ "\""
where
	escape_specials i string
		| i>=size string
			= string
		| string.[i]=='\\'
			= escape_specials (i+2) (string % (0,i-1)+++"\\"+++string % (i,dec (size string)))
		| string.[i]=='"'
			= escape_specials (i+2) (string % (0,i-1)+++"\\"+++string % (i,dec (size string)))
			= escape_specials (inc i) string
*/

CodeGen	::	!String !Bool !(WindowFun *GeneralSt) !CodeGenerateAsmOrCode !Pathname !Pathname !Bool
			!CodeGenOptions !Processor !ApplicationOptions !Pathname !CompilerProcessIds !*GeneralSt
			-> (!Pathname,!Bool,!CompilerProcessIds,!*GeneralSt)
CodeGen cgen` used_compiler_process_ids wf genAsmOrCode abc_path obj_path timeprofile cgo tp ao startupdir compiler_process_ids ps
	# (cgen_ok,cgen,cgendir)		= mangleGenerator cgen` startupdir
	| not cgen_ok
		# ps				= wf [cgen] ps
		= ("",False,compiler_process_ids,ps)

	#	path_without_suffix	= RemoveSuffix abc_path
		command				= cgen +++ MakeCodeGenOptionsString genAsmOrCode timeprofile cgo tp
//								+++ " " +++ (watcom_quoted_string path_without_suffix)
								+++ " " +++ (quoted_string path_without_suffix)

  		errorsfilename		= tooltempdir +++ DirSeparatorString +++ "errors"
		(didit,exit_code,_) = call_process_with_directory_and_redirected_std_error command cgendir errorsfilename 99
	| not didit
		= (obj_path,False,compiler_process_ids,wf [  "Error: Unable to run code generator: "+++cgen
													] ps)
	#	code_generator_failed_message = "Error: Code generator failed for '" +++ abc_path +++ "' with exit code: "+++toString exit_code
	#	((_, errors_not_empty, error_text),ps)	= accFiles (ReadErrorsAndWarnings errorsfilename) ps
		ps	= (if errors_not_empty 
				(if (exit_code <> 0)
					(wf (StrictListToList error_text++[code_generator_failed_message])) 
					(wf (StrictListToList error_text)))
				(if (exit_code <> 0)
					(wf [code_generator_failed_message,quoted_string path_without_suffix])
					id)
			  ) ps
	=  (obj_path,exit_code==0,compiler_process_ids,ps)

:: StartedCodeGenerator = !{
	scg_thread_handle :: !Int,
	scg_std_error_handle :: !Int,
	scg_abc_path :: !{#Char},
	scg_path_without_suffix :: !{#Char},
	scg_errors_file_name :: !{#Char}
  }

start_code_generator ::	!String !(WindowFun *GeneralSt) !Pathname !Int !Bool !CodeGenOptions !Processor !Pathname !*GeneralSt
						-> (!Bool,!Int/*HANDLE*/,!StartedCodeGenerator,!*GeneralSt)
start_code_generator cgen` wf abc_path slot timeprofile cgo tp startupdir ps
	# (cgen_ok,cgen,cgendir) = mangleGenerator cgen` startupdir
	| not cgen_ok
		# ps = wf [cgen] ps
		# scg = {scg_thread_handle=0,scg_std_error_handle=0,scg_abc_path="",scg_path_without_suffix="",scg_errors_file_name=""}
		= (False,0,scg,ps)
	# path_without_suffix = RemoveSuffix abc_path
	  command = cgen +++ MakeCodeGenOptionsString CodeGeneration timeprofile cgo tp +++ " " +++ (quoted_string path_without_suffix)
	  errors_file_name = errors_file_path tooltempdir slot
	  (didit,process_handle,thread_handle,std_error_handle,_) = start_process_with_redirected_std_error command cgendir errors_file_name 99
	| not didit
		# scg = {scg_thread_handle=0,scg_std_error_handle=0,scg_abc_path="",scg_path_without_suffix="",scg_errors_file_name=""}
		= (False,0,scg,wf ["Error: Unable to run code generator: "+++cgen] ps)
		# scg = {scg_thread_handle=thread_handle,scg_std_error_handle=std_error_handle,
				 scg_abc_path=abc_path,scg_path_without_suffix=path_without_suffix,scg_errors_file_name=errors_file_name}
		= (True,process_handle,scg,ps)

finish_code_generator :: !Int/*HANDLE*/ !StartedCodeGenerator !Int !(WindowFun *GeneralSt) !*GeneralSt -> (!Bool,!*GeneralSt)
finish_code_generator process_handle {scg_thread_handle,scg_std_error_handle,scg_abc_path,scg_path_without_suffix,scg_errors_file_name} exit_code wf ps
	# os = finish_process_with_redirected_std_error process_handle scg_thread_handle scg_std_error_handle 99
	| os<>99
		= undef
	# ((_, errors_not_empty, error_text),ps) = accFiles (ReadErrorsAndWarnings scg_errors_file_name) ps
	  code_generator_failed_message = "Error: Code generator failed for '" +++ scg_abc_path +++ "' with exit code: "+++toString exit_code
	  ps = (if errors_not_empty 
				(if (exit_code <> 0)
					(wf (StrictListToList error_text ++ [code_generator_failed_message]))
					(wf (StrictListToList error_text)))
				(if (exit_code <> 0)
					(wf [code_generator_failed_message,quoted_string scg_path_without_suffix])
					id
				)
			 ) ps
	=  (exit_code==0,ps)

wait_for_finished_code_generator :: !{#Int} !*GeneralSt -> (!Int,!Int,!*GeneralSt);
wait_for_finished_code_generator handles ps
	# n_handles = size handles
	# (i,os) = WaitForMultipleObjects n_handles handles False INFINITE 99
	| i>=WAIT_OBJECT_0 && i<WAIT_OBJECT_0+n_handles
		# process_n = i-WAIT_OBJECT_0
		# (_,exit_code,os) = GetExitCodeProcess handles.[process_n] os
		| os<>99
			= undef
		= (process_n,exit_code,ps)
	| i>=WAIT_ABANDONED_0 && i<WAIT_ABANDONED_0+n_handles
		# process_n = i-WAIT_ABANDONED_0
		# (_,exit_code,os) = GetExitCodeProcess handles.[process_n] os
		| os<>99
			= undef
		= (process_n,exit_code,ps)
		= (-1,-1,ps)

mangleGenerator cgen` startupdir
	# (cgen`,opts)			= splitOptions cgen`
	# (shortOK,cgen)		= GetShortPathName (startupdir +++ "\\" +++ cgen` +++ "\0")
	| not shortOK
		# line				= "Error: Unable to get short path name '" +++ (startupdir +++ "\\" +++ cgen`) +++ "'."
		= (False,line,"")
	# cgencom = cgen % (0, size cgen - 2) +++ opts
	# cgendir = RemoveFilename (cgen % (0, size cgen - 2))
	= (True,cgencom,cgendir)

MakeCodeGenOptionsString genAsmOrCode timeprofile {ci,cs} tp
	= checkindex+++checkstack+++genasm
where
	checkindex	| ci = " -ci"; = ""
	checkstack	| cs = " -os"; = ""
	genasm		| genAsmOrCode == AsmGeneration
										= " -a"
										= ""
	
/* Links the given file:
*/

Link ::	!String !(WindowFun *GeneralSt) !Pathname !ApplicationOptions
		!Pathname !(List Pathname) !(List Pathname) !(List Pathname) !Bool !Bool !Bool !Bool !Bool !String
		!Bool !String !Pathname !String !Processor !Bool !*GeneralSt
		 -> (!*GeneralSt,!Bool)
Link linker` winfun path
		applicationOptions=:{ss,hs,initial_heap_size,profiling,heap_size_multiple,o,memoryProfilingMinimumHeapSize=minheap}
		optionspathname library_file_names object_file_names static_libraries static gen_relocs gen_symbol_table gen_linkmap
		link_resources resource_path gen_dll dll_syms startupdir dynlstr _ use_64_bit_processor ps
	# (calling_convention,linker`) = get_optional_calling_convention linker`
	| size calling_convention<>0 && calling_convention<>"linker"
		= (winfun ["Linker error: Unknown calling convention : "+++calling_convention] ps,False)
	# (ok,linker,linkerdir)				= mangleLinker linker` startupdir
	| not ok
		# ps					= winfun [linker] ps
		= (ps,False)
	# flags						= ApplicationOptionsToFlags applicationOptions
	# optdirpath				= RemoveFilename optionspathname
	# ((ok,pd_optdirpath),ps)	= pd_StringToPath optdirpath ps
	| not ok
		= (winfun ["Linker error: Unable to understand path: "+++optdirpath] ps,False)
	# ((err,_),ps)				= getDirectoryContents pd_optdirpath ps
	# (err,ps)					= case err of
		DoesntExist		-> createDirectory pd_optdirpath ps
		err  			-> (err,ps)
	| err <> NoDirError
		= (winfun ["Linker error: Unable to access or create: "+++optdirpath] ps,False)
	# (options_file_ok,ps)		= accFiles (write_options_file optionspathname flags hs ss initial_heap_size heap_size_multiple minheap use_64_bit_processor) ps
	| not options_file_ok
		= (winfun ["Linker error: Could not write the options object file: "+++optionspathname] ps,False)
	# linkopts =
		{ exe_path					= path
		, res_path					= resource_path
		, open_console				= o <> NoConsole
		, static_link				= static
		, gen_relocs				= gen_relocs
		, gen_symbol_table			= gen_symbol_table
		, gen_linkmap				= gen_linkmap
		, link_resources			= link_resources
		, object_paths				= optionspathname :! (RemoveDup object_file_names)
	  	, dynamic_libs				= RemoveDup library_file_names
	  	, static_libs				= RemoveDup static_libraries
	  	, stack_size				= ss
		, gen_dll					= gen_dll
		, dll_names					= dll_syms
		, dynamics_path				= startupdir +++. DirSeparatorString +++. dynlstr
		, lib_name_obj_path = MakeFullPathname tooltempdir "lib_name.o"
	  	}
	# linkoptspath					= MakeFullPathname tooltempdir "linkopts"
	# linkerrspath					= MakeFullPathname tooltempdir "linkerrs"
	# (err,ps)						= accFiles (WriteLinkOpts linkoptspath linkopts) ps
	| isJust err
		= (winfun (fromJust err) ps,False)

	# linker = linker +++ " -I " +++ quoted_string linkoptspath +++ " -O " +++ quoted_string linkerrspath
	
	# (didit,exit_code,ost) = call_process_with_directory linker linkerdir 99
	# diditall = if (ost == 99) didit didit
	| not diditall
		=	(winfun ["Error: Unable to run linker: "+++linker] ps, False)
	# link_ok = (exit_code==0) && (ost == 99)
	# ((err,link_errors),ps) = accFiles (ReadLinkErrors linkerrspath) ps
	| isJust err
		= (winfun (fromJust err) ps,False)
	# (errtext,errlines) = (link_errors, length link_errors)
	| errlines<>0
		= (winfun errtext ps,link_ok)
	=  (ps,link_ok)

mangleLinker linkstr` startupdir
	# (linkstr`,opts)		= splitOptions linkstr`
	# (shortOK,linkstr)		= GetShortPathName (startupdir +++ DirSeparatorString +++ linkstr` +++ "\0")
	| not shortOK
		# line				= "Error: Unable to get short path name '" +++ (startupdir +++ DirSeparatorString +++ linkstr`) +++ "'."
		= (False,line,"")
	# linkcom = linkstr % (0, size linkstr - 2) +++ opts
	# linkdir = RemoveFilename (linkstr % (0, size linkstr - 2))
	= (True,linkcom,linkdir)

get_optional_calling_convention :: !{#Char} -> (!{#Char},!{#Char})
get_optional_calling_convention s
	# s_size = size s;
	| s_size>0 && s.[0]==':'
		# next_c = FindColonChar 1 s s_size
		| next_c<s_size
			= (s % (1,next_c-1),s % (next_c+1,s_size));
			= ("",s);
		= ("",s);

splitOptions :: !{#Char} -> (!{#Char},!{#Char})
splitOptions str
	# len_str = size str
	  first_c = FindColonChar 0 str len_str
	| first_c >= len_str
		= (str,"")
		# first_str = str % (0,dec first_c)
		  last_str = str % (first_c+1, len_str)
		= (first_str,last_str)

FindColonChar :: !Int !String !Int -> Int;
FindColonChar pos line linelen
	| pos<linelen && line.[pos]<>':'
		= FindColonChar (pos+1) line linelen;
		= pos;

//--- EXECUTE

Execute`	::	!String !*env -> (!Bool,!Int,!*env)
Execute` command ps
	#	(didit, ec, os4)	= call_process command 99
	    diditall			= if (os4 == 99) didit didit
	| diditall
		= (True,ec,ps)
		= (False,ec,ps)

//--- OTHER STUFF

call_process :: !{#Char} !*OSToolbox -> (!Bool, !Int, !*OSToolbox)
call_process command os
	| size command>0
		# (ok,process_information,os) = create_process_with_current_directory_pointer (command+++."\0") 0 True 0 os
		| not ok
			= (False, -1, os)
			# process_handle = process_information.[PROCESS_INFORMATION_hProcess_int_offset]
			  thread_handle = process_information.[PROCESS_INFORMATION_hThread_int_offset]
			  (_,os) = WaitForSingleObject process_handle INFINITE os
			  (_,exit_code,os) = GetExitCodeProcess process_handle os
			  (_,os) = CloseHandle thread_handle os
			  (_,os) = CloseHandle process_handle os
			= (True, exit_code, os)
		= (False, -1, os)

call_process_with_directory :: !{#Char} !{#Char} !*OSToolbox -> (!Bool, !Int, !*OSToolbox)
call_process_with_directory command directory os
	| size command>0
		# (ok,process_information,os) = create_process (command+++."\0") (directory+++"\0") False 0 os
		| not ok
			= (False, -1, os)
			# process_handle = process_information.[PROCESS_INFORMATION_hProcess_int_offset]
			  thread_handle = process_information.[PROCESS_INFORMATION_hThread_int_offset]
			  (_,os) = WaitForSingleObject process_handle INFINITE os
			  (_,exit_code,os) = GetExitCodeProcess process_handle os
			  (_,os) = CloseHandle thread_handle os
			  (_,os) = CloseHandle process_handle os
			= (True, exit_code, os)
		= (False, -1, os)

call_process_with_directory_and_redirected_std_error :: !{#Char} !{#Char} !{#Char} !*OSToolbox -> (!Bool, !Int, !*OSToolbox)
call_process_with_directory_and_redirected_std_error command directory errors_file_name os
	| size command>0
		# (std_error_handle,os) = create_inheritable_file (errors_file_name+++"\0") os
		  (ok,process_information,os) = create_process (command+++."\0") (directory+++"\0") True std_error_handle os
		| not ok
			# (_,os) = CloseHandle std_error_handle os
			= (False, -1, os)
			# process_handle = process_information.[PROCESS_INFORMATION_hProcess_int_offset]
			  thread_handle = process_information.[PROCESS_INFORMATION_hThread_int_offset]
			  (_,os) = WaitForSingleObject process_handle INFINITE os
			  (_,exit_code,os) = GetExitCodeProcess process_handle os
			  (_,os) = CloseHandle std_error_handle os
			  (_,os) = CloseHandle thread_handle os
			  (_,os) = CloseHandle process_handle os
			= (True, exit_code, os)
		= (False, -1, os)

start_process_with_redirected_std_error :: !{#Char} !{#Char} !{#Char} !*OSToolbox -> (!Bool, !HANDLE, !HANDLE, !HANDLE, !*OSToolbox)
start_process_with_redirected_std_error command directory errors_file_name os
	| size command>0
		# (std_error_handle,os) = create_inheritable_file (errors_file_name+++"\0") os
		  (ok,process_information,os) = create_process (command+++."\0") (directory+++"\0") True std_error_handle os
		| not ok
			# (_,os) = CloseHandle std_error_handle os
			= (False, 0, 0, 0, os)
			# process_handle = process_information.[PROCESS_INFORMATION_hProcess_int_offset]
			  thread_handle = process_information.[PROCESS_INFORMATION_hThread_int_offset]
			= (True,process_handle,thread_handle,std_error_handle,os)
		= (False, 0, 0, 0, os)

finish_process_with_redirected_std_error :: !HANDLE !HANDLE !HANDLE !*OSToolbox -> *OSToolbox
finish_process_with_redirected_std_error process_handle thread_handle std_error_handle os
	# (_,os) = CloseHandle std_error_handle os
	  (_,os) = CloseHandle thread_handle os
	  (_,os) = CloseHandle process_handle os
	= os

// PERSISTENT STUFF

int_to_hex v
	= {hex_char i \\ i<-[0..7]};
where
		hex_char i
			# h=(v>>((7-i)<<2)) bitand 15;
			= toChar (if (h<10) (toInt '0'+h) ((toInt 'A'-10)+h));



:: CompilingInfo = NotCompiling | CompilingInfo !CompilerProcess;

:: CompilerProcess = NoCompiler | CompilerProcess !Int !Int !Int; // thread_id thread_handle process_handle

InitCompilingInfo :: *CompilingInfo
//InitCompilingInfo = NotCompiling
InitCompilingInfo = CompilingInfo NoCompiler

compile_with_cache :: String String String String *(*CompilingInfo,*env) -> (!Bool,!Int,!*(*CompilingInfo,*env))
compile_with_cache path directory startup_arguments arguments prog=:(CompilingInfo NoCompiler, ps)
//	# startup_arguments = ""
	# thread_id=get_current_thread_id;
	# begin_arguments=startup_arguments+++" -ide "+++int_to_hex thread_id;
	# (r,compiler_thread_id,compiler_thread_handle,compiler_process_handle)
		= start_compiler_process (IF_BATCHBUILD_OR_IDE 0 dispatch_null_message_hook) (path+++"\0") (directory+++"\0") ("\""+++path+++"\" "+++begin_arguments+++"\0");
	| r==0
		= (False,0,prog)
	# (ok,s) = compile_with_cache2 path directory arguments compiler_thread_id compiler_thread_handle compiler_process_handle;
	| ok
		# ci = CompilingInfo (CompilerProcess compiler_thread_id compiler_thread_handle compiler_process_handle)
		= (ok,s,(ci,ps));
		= (ok,s,prog);
compile_with_cache path directory startup_arguments arguments prog=:(CompilingInfo (CompilerProcess compiler_thread_id compiler_thread_handle compiler_process_handle),ps)
	# (ok,s) = compile_with_cache2 path directory arguments compiler_thread_id compiler_thread_handle compiler_process_handle
	| ok
		= (ok,s,prog)
	= (ok,s,(CompilingInfo NoCompiler,ps))
compile_with_cache path directory startup_arguments arguments prog=:(NotCompiling,ps)
    # command = quoted_string path +++ " " +++ arguments
	# (ok,exitcode, os4) = call_process_with_directory command directory 99
	= (ok,exitcode,prog)

compile_with_cache2 :: {#.Char} {#.Char} {#.Char} Int Int Int -> (!Bool,!Int)
compile_with_cache2 path directory arguments compiler_thread_id compiler_thread_handle compiler_process_handle
	# wm_number=get_message_number
	# r=send_string_to_thread compiler_thread_id compiler_process_handle wm_number ("cocl "+++arguments+++"\0")
	| r==0
		= (False,0)
	# (r,a,s) =get_integers_from_thread_message wm_number compiler_thread_handle
	| r==0
		= (False,s)
	= (True,s)

RunExternalCommand :: !String ![String] !String !*GeneralSt -> *(!Int, ![String], !*GeneralSt)
RunExternalCommand cmd args startupdir ps
	# command = foldl (\cmd arg -> cmd +++ " " +++ arg) cmd [quoted_string arg \\ arg <- args]
	| size command >= 32768 = (-1,["Error: command line is too long (consider moving the project to a location closer to the filesystem root): " +++ command % (0,200) +++ "..."],ps)
	# dir = RemoveFilename cmd
	  errorsfilename = tooltempdir +++ DirSeparatorString +++ "errors"
	  (didit,exit_code,_) = call_process_with_directory_and_redirected_std_error command dir errorsfilename 99
	| not didit = abort ("Could not run external command '" +++ command +++ "'\n")
	# (out,ps) = accFiles (readFileLines errorsfilename) ps
	= (exit_code,out,ps)
where
	readFileLines :: !String !*Files -> *(![String], !*Files)
	readFileLines path env
	# (ok,f,env) = fopen path FReadText env
	| not ok = ([], env)
	# (out,f) = read [] f
	# (_,env) = fclose f env
	= (out,env)
	where
		read :: ![String] !*File -> *(![String], !*File)
		read acc f
		# (e,f) = fend f
		| e = (reverse acc,f)
		# (line,f) = freadline f
		#! line = strip_newlines line
		= read [line:acc] f

	strip_newlines :: !{#Char} -> {#Char}
	strip_newlines s
		| size s==0
			= s
			# last = dec (size s)
			  char = s.[last]
			| char == '\n' || char == '\r'
				= strip_newlines (s % (0,dec last))
			= s

StartCodeGenerator	::	!String !(WindowFun *GeneralSt) !CodeGenerateAsmOrCode !Pathname !Int !Bool !CodeGenOptions !Processor !ApplicationOptions !Pathname !CompilerProcessIds !*GeneralSt -> (!Bool,!Pathname,!CompilerProcessIds,!*GeneralSt)
StartCodeGenerator _ _ _ _ _ _ _ _ _ _ _ _ = undef

SendRepeatResult :: !Int !.a -> (!Int,!.a)
SendRepeatResult _ _ = undef

DelayEventLoop :: !.ps -> .ps
DelayEventLoop ps
	| IF_BATCHBUILD_OR_IDE
		True
		(wait_message 0==0)
		= ps

wait_message :: !Int -> Int;
wait_message r = code {
	ccall WaitMessage@0 "P:V:I"
}

GENERIC_WRITE:==0x40000000;
CREATE_ALWAYS:==2;
FILE_ATTRIBUTE_NORMAL:==0x00000080;  

SECURITY_ATTRIBUTES_nLength_int_offset:==0;
SECURITY_ATTRIBUTES_bInheritHandle_int_offset:==2;

SECURITY_ATTRIBUTES_size_int:==3;
SECURITY_ATTRIBUTES_size_bytes_32:==12;
SECURITY_ATTRIBUTES_size_bytes_64:==24;
SECURITY_ATTRIBUTES_size_bytes :== IF_INT_64_OR_32 SECURITY_ATTRIBUTES_size_bytes_64 SECURITY_ATTRIBUTES_size_bytes_32;

:: HANDLE:==Int;

create_inheritable_file :: !{#Char} !*OSToolbox -> (!HANDLE,!*OSToolbox);
create_inheritable_file file_name os
	# security_attributes = {createArray SECURITY_ATTRIBUTES_size_int 0 &
	  							[SECURITY_ATTRIBUTES_nLength_int_offset] = SECURITY_ATTRIBUTES_size_bytes,
	  							[SECURITY_ATTRIBUTES_bInheritHandle_int_offset] = 1};
	= IF_INT_64_OR_32
		(CreateFile file_name GENERIC_WRITE 0 security_attributes CREATE_ALWAYS FILE_ATTRIBUTE_NORMAL 0 os)
		(CreateFile_32 file_name GENERIC_WRITE 0 security_attributes CREATE_ALWAYS FILE_ATTRIBUTE_NORMAL 0 os);

create_process :: !*{#Char} !{#Char} !Bool !HANDLE !*OSToolbox -> (!Bool,!{#Int},!*OSToolbox)
create_process command_line current_directory startf_usestdhandles std_error_handle os
	# flags = if startf_usestdhandles (IF_INT_64_OR_32 (STARTF_USESTDHANDLES<<32) STARTF_USESTDHANDLES) 0;
	  startup_info = {createArray STARTUPINFO_size_int 0 &
	  					[STARTUPINFO_cb_int_offset] = STARTUPINFO_size_bytes,
						[IF_INT_64_OR_32 STARTUPINFO_dwFlags_int_h_offset_64 STARTUPINFO_dwFlags_int_offset_32] = flags,
						[STARTUPINFO_hStdError_int_offset] = std_error_handle};
	  process_information = createArray PROCESS_INFORMATION_size_int 0
	  (ok,os) = IF_INT_64_OR_32
	  				(CreateProcess 0 command_line 0 0 True DETACHED_PROCESS 0 current_directory startup_info process_information os)
	  				(CreateProcess_32 0 command_line 0 0 True DETACHED_PROCESS 0 current_directory startup_info process_information os)
	= (ok,process_information,os)

create_process_with_current_directory_pointer :: !*{#Char} !Int !Bool !HANDLE !*OSToolbox -> (!Bool,!{#Int},!*OSToolbox)
create_process_with_current_directory_pointer command_line current_directory_p startf_usestdhandles std_error_handle os
	# flags = if startf_usestdhandles (IF_INT_64_OR_32 (STARTF_USESTDHANDLES<<32) STARTF_USESTDHANDLES) 0;
	  startup_info = {createArray STARTUPINFO_size_int 0 &
	  					[STARTUPINFO_cb_int_offset] = STARTUPINFO_size_bytes,
						[IF_INT_64_OR_32 STARTUPINFO_dwFlags_int_h_offset_64 STARTUPINFO_dwFlags_int_offset_32] = flags,
						[STARTUPINFO_hStdError_int_offset] = std_error_handle};
	  process_information = createArray PROCESS_INFORMATION_size_int 0
	  (ok,os) = IF_INT_64_OR_32
	  				(CreateProcess_with_current_directory_pointer 0 command_line 0 0 True DETACHED_PROCESS 0 current_directory_p startup_info process_information os)
	  				(CreateProcess_with_current_directory_pointer_32 0 command_line 0 0 True DETACHED_PROCESS 0 current_directory_p startup_info process_information os)
	= (ok,process_information,os)

CreateFile_32 :: !{#Char} !Int !Int !{#Int} !Int !Int !HANDLE !*OSToolbox -> (!HANDLE,!*OSToolbox);
CreateFile_32 fileName desiredAccess shareMode lpSecurityAttributes creationDisposition flagsAndAttributes templateFile os
	= code {
		ccall CreateFileA@28 "PsIIAIII:I:I"
	}

CreateFile :: !{#Char} !Int !Int !{#Int} !Int !Int !HANDLE !*OSToolbox -> (!HANDLE,!*OSToolbox);
CreateFile fileName desiredAccess shareMode lpSecurityAttributes creationDisposition flagsAndAttributes templateFile os
	= code {
		ccall CreateFileA@28 "PsIIAIIp:I:I"
	}

:: LPCSTR:==Int;
:: LPSECURITY_ATTRIBUTES:==Int;
:: LPVOID:==Int;
:: LPSTARTUPINFO:==Int;
:: LPPROCESS_INFORMATION:==Int;

STARTF_USESTDHANDLES:==0x00000100;

STARTUPINFO_size_int_32:==17;
STARTUPINFO_size_bytes_32:==68;

STARTUPINFO_size_int_64:==13;
STARTUPINFO_size_bytes_64:==104;

STARTUPINFO_size_int :== IF_INT_64_OR_32 STARTUPINFO_size_int_64 STARTUPINFO_size_int_32;
STARTUPINFO_size_bytes :== IF_INT_64_OR_32 STARTUPINFO_size_bytes_64 STARTUPINFO_size_bytes_32;

STARTUPINFO_cb_int_offset:==0;

STARTUPINFO_dwFlags_int_offset_32:==11;
STARTUPINFO_hStdError_int_offset_32:==16;

STARTUPINFO_dwFlags_int_h_offset_64:==7;
STARTUPINFO_hStdError_int_offset_64:==12;

STARTUPINFO_hStdError_int_offset :== IF_INT_64_OR_32 STARTUPINFO_hStdError_int_offset_64 STARTUPINFO_hStdError_int_offset_32;

PROCESS_INFORMATION_size_int_32:==4;

PROCESS_INFORMATION_size_int_64:==3;

PROCESS_INFORMATION_size_int :== IF_INT_64_OR_32 PROCESS_INFORMATION_size_int_64 PROCESS_INFORMATION_size_int_32;

PROCESS_INFORMATION_hProcess_int_offset:==0;
PROCESS_INFORMATION_hThread_int_offset:==1;

DETACHED_PROCESS:==8;

CreateProcess :: !LPCSTR !*{#Char} !LPSECURITY_ATTRIBUTES !LPSECURITY_ATTRIBUTES !Bool !Int !LPVOID
					!{#Char} !{#Int} !{#Int} !*OSToolbox -> (!Bool,!*OSToolbox)
CreateProcess lpApplicationName commandLine lpProcessAttributes lpThreadAttributes inheritHandles creationFlags lpEnvironment
					currentDirectory lpStartupInfo lpProcessInformation os
	= code {
		ccall CreateProcessA@40 "PpsppIIpsAA:I:I"
	}

CreateProcess_32 :: !LPCSTR !*{#Char} !LPSECURITY_ATTRIBUTES !LPSECURITY_ATTRIBUTES !Bool !Int !LPVOID
					!{#Char} !{#Int} !{#Int} !*OSToolbox -> (!Bool,!*OSToolbox)
CreateProcess_32 lpApplicationName commandLine lpProcessAttributes lpThreadAttributes inheritHandles creationFlags lpEnvironment
					currentDirectory lpStartupInfo lpProcessInformation os
	= code {
		ccall CreateProcessA@40 "PIsIIIIIsAA:I:I"
	}

CreateProcess_with_current_directory_pointer :: !LPCSTR !*{#Char} !LPSECURITY_ATTRIBUTES !LPSECURITY_ATTRIBUTES !Bool !Int
												!LPVOID !LPCSTR !{#Int} !{#Int} !*OSToolbox -> (!Bool,!*OSToolbox)
CreateProcess_with_current_directory_pointer lpApplicationName commandLine lpProcessAttributes lpThreadAttributes inheritHandles creationFlags
												lpEnvironment lpCurrentDirectory lpStartupInfo lpProcessInformation os
	= code {
		ccall CreateProcessA@40 "PpsppIIppAA:I:I"
	}

CreateProcess_with_current_directory_pointer_32 :: !LPCSTR !*{#Char} !LPSECURITY_ATTRIBUTES !LPSECURITY_ATTRIBUTES !Bool !Int
													!LPVOID !LPCSTR !{#Int} !{#Int} !*OSToolbox -> (!Bool,!*OSToolbox)
CreateProcess_with_current_directory_pointer_32 lpApplicationName commandLine lpProcessAttributes lpThreadAttributes inheritHandles creationFlags lpEnvironment
												lpCurrentDirectory lpStartupInfo lpProcessInformation os
	= code {
		ccall CreateProcessA@40 "PIsIIIIIpAA:I:I"
	}


INFINITE:==0xFFFFFFFF

WaitForSingleObject :: !HANDLE !Int !*OSToolbox -> (!Int,!*OSToolbox);
WaitForSingleObject handle milliseconds os
	= code {
		ccall WaitForSingleObject@8 "PpI:I:I"
	}

WAIT_OBJECT_0:==0;
WAIT_ABANDONED_0:==0x80;
WAIT_TIMEOUT:==258;
WAIT_FAILED:==0xFFFFFFFF;

WaitForMultipleObjects :: !Int !{#Int} !Bool !Int !*OSToolbox -> (!Int,!*OSToolbox);
WaitForMultipleObjects n_handles handles waitAll milliseconds os
	= code {
		ccall WaitForMultipleObjects@16 "PIAII:I:I"
	}

GetExitCodeProcess :: !HANDLE !*OSToolbox -> (!Bool,!Int,!*OSToolbox);
GetExitCodeProcess process os
	= code {
		ccall GetExitCodeProcess@8 "PI:II:I"
	}

CloseHandle :: !HANDLE !*OSToolbox -> (!Bool,!*OSToolbox);
CloseHandle object os
	= code {
		ccall CloseHandle@4 "PI:I:I"
	}
