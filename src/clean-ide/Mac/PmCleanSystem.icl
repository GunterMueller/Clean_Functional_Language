implementation module PmCleanSystem

/* OS dependent module for powermac */
/* Interface module for calling the CLEAN compiler, code generator and linker */

//import StdEnv
import StdArray, StdBool, StdChar, StdFunc, StdInt, StdList
import StdSystem, StdPStClass, StdMisc
import Directory

import PmCompilerOptions, PmPath, PmProject
from UtilStrictLists import :: List(..), RemoveDup, StrictListToList
import UtilNewlinesFile
import WriteOptionsFile

from PmParse import IsTypeSpec, IsImportError13, IsImportError20
from linkargs import ReadLinkErrors,WriteLinkOpts,:: LinkInfo`(..),:: LPathname

import xcoff_linker
import mach_o_linker

import ostoolbox
from files import LaunchApplicationFSSpec, FSMakeFSSpec
import memory,appleevents
import Platform

from IdeState import getCurrentMeth,::General,::CompileMethod

KAEQueueReply :== 2

//import StdDebug,dodebug
//import nodebug
//import dodebug
trace_n _ f :== f
trace_n` _ f :== f

// For testing update speed...
send_command_to_clean_compiler_cc a b c
	:== send_command_to_clean_compiler a b c
//	= (0,1,"")
send_command_to_clean_compiler_cg a b c
	:== send_command_to_clean_compiler a b c
//	= (0,1,"")
send_command_to_clean_compiler_ca a b c
	:== send_command_to_clean_compiler a b c
//	= (0,0,"")

standardStaticLibraries :: !Processor !LinkMethod -> List String
standardStaticLibraries processor method
	| ProcessorSuffix processor == ".cxo"	// PowerPC Classic
		= case method of
			LM_Static	-> ("Interface_library" :! "StdC_library" :! "Math_library" :! Nil)
			LM_Dynamic	-> ("Interface_library" :! "StdC_library" :! "Math_library" :! Nil)
	| ProcessorSuffix processor == ".xo"	// PowerPC CFM/PEF
		= case method of
			LM_Static	-> ("Carbon_library" :! "StdC_library" :! Nil)
			LM_Dynamic	-> ("Carbon_library" :! "StdC_library" :! Nil)
	= case method of						// PowerPC dyld/MachO
		LM_Static		-> (Nil)
		LM_Dynamic		-> (Nil)

standardObjectFiles :: !Bool !Bool !Bool !Processor !Bool -> List String
standardObjectFiles stack_traces callgraph_profiling profiling processor use_64_bit_processor
	| stack_traces
		= (  MakeObjPathname processor "_startupTrace" :! rest)
	| callgraph_profiling
		= (  MakeObjPathname processor "_startupProfileGraph" :! rest)
	| profiling
		= (  MakeObjPathname processor "_startupProfile" :! rest)
	// otherwise
		= (  MakeObjPathname processor "_startup" :! rest)
where
	rest
		| ProcessorSuffix processor == ".o"	// PowerPC Mach-O
			=  MakeObjPathname processor "_startup2"
			:! MakeObjPathname processor "_startup3" 
			:! MakeObjPathname processor "_system" 
			:! MakeObjPathname processor "_library" 
			:! Nil
		// otherwise
			=  MakeObjPathname processor "_system" 
			:! MakeObjPathname processor "_library" 
			:! Nil

//-- interface to static libraries...

getLibs :: ![String] !*Files -> (!(![String],![String]),!*Files)
getLibs [] files = (([],[]),files)
getLibs [lib:libs] files
	# (errs,slibs,files)		= getLib lib files
	# ((errs`,slibs`),files)	= getLibs libs files
	= ((errs++errs`,slibs++slibs`),files)
getLib lib files
	= ([],[],files)
/* nog niet op mac
	# (errs,slibs,files)	=  OpenArchive lib files
	# slibs					= map RemoveSuffix slibs
	= (errs,slibs,files)
*/

//--

::	CodeGenerateAsmOrCode	= AsmGeneration	| CodeGeneration

instance == CodeGenerateAsmOrCode
where
	(==) :: CodeGenerateAsmOrCode CodeGenerateAsmOrCode -> Bool
	(==) AsmGeneration AsmGeneration
		=	True
	(==) CodeGeneration CodeGeneration
		=	True
	(==) _ _
		=	False

::	CompileOrCheckSyntax	= SyntaxCheck | Compilation

instance == CompileOrCheckSyntax
where
	(==) :: CompileOrCheckSyntax CompileOrCheckSyntax -> Bool
	(==) SyntaxCheck SyntaxCheck
		=	True
	(==) Compilation Compilation
		=	True
	(==) _ _
		=	False

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

out_file_path :: String Int -> String
out_file_path startupdir slot
//	=	file_path startupdir "out" slot
	=	file_path TempDir "out" slot

errors_file_path :: String Int -> String
errors_file_path startupdir slot
//	=	file_path startupdir "errors" slot
	=	file_path TempDir "errors" slot

file_path :: String String Int -> String
file_path startupdir base_name slot
	| slot==0
		=	startupdir +++ toString dirseparator +++ base_name
		=	startupdir +++ toString dirseparator +++ base_name+++toString slot

/* Compiles the given file: */	

Compile :: !String !Bool !Bool !(WindowFun *env) !(WindowFun *env) !CompileOrCheckSyntax !Pathname !(List Pathname) !ProjectCompilerOptions
					!CompilerOptions !Pathname !CompilerProcessIds !*env
					-> (!Pathname,!CompilerMsg,!CompilerProcessIds,!*env) | FileEnv env
Compile cocl` use_compiler_process_psn write_module_times errwin typewin compileOrCheckSyntax path paths project_compiler_options
					co=:{CompilerOptions | listTypes} startupdir compiler_psns ps
	# (cocl,name,signature)	= mangleCompiler cocl` startupdir	// platform dependant mangling...
	# command
		= cocl +++ clear_cache_option +++ write_module_times_string
			+++ MakeCompilerOptionsString
					compileOrCheckSyntax
					project_compiler_options.pco_memory_profiling
					project_compiler_options.pco_time_profiling
					project_compiler_options.pco_callgraph_profiling
					project_compiler_options.pco_link_dynamic
					co
        	+++ " -sl"
        	+++ " -P " +++ quoted_string (ConcatenatePath paths)
			+++ " " +++ quoted_string path
			+++ " > "+++ quoted_string out_file_name
			+++ " \xb3 "+++ quoted_string errors_file_name	// \xb3 == >= ligature

	# (error_code,error_n,ss,compiler_psns,ps) =
		if use_compiler_process_psn
			(send_command_to_clean_compiler_using_slot name command 0 compiler_psns ps)
			(let (error_code,error_n,ss) = send_command_to_clean_compiler_cc signature name command Wait
			 in (error_code,error_n,ss,compiler_psns,ps)
			)
	| error_code <> 0 =
		("",SyntaxError,compiler_psns
		,errwin (	[ "Error: Unable to run compiler: "+++cocl
					+++ "; "+++ toString error_code
					+++ "; "+++ toString error_n
					+++ "; "+++ ss
					]) ps
		)
	#	((type_text_not_empty,type_text),ps)
						= accFiles (ReadTypesInfo (listTypes<>NoTypes) out_file_name) ps
		((errors,errors_and_messages_not_empty,errors_and_messages),ps)
						= accFiles (ReadErrorsAndWarnings errors_file_name) ps
//		(abcpath,ps)	= accFiles (MakeABCSystemPathname path) ps
		abcpath			= MakeABCSystemPathname path
		ps				= case errors_and_messages_not_empty of
							True	-> trace_n "errwin" errwin (StrictListToList errors_and_messages) ps
							False	-> trace_n "ok" ps
		ps				= case type_text_not_empty of
							True	-> typewin (StrictListToList type_text) ps
							False	-> ps
     = (abcpath,if (error_n==1) CompilerOK errors,compiler_psns,ps)
where

	clearCache = Don`tClearCache	// needs to be arg to compile command???
	write_module_times_string = if write_module_times " -wmt " " "
	out_file_name
		= out_file_path startupdir 0
	errors_file_name
		= errors_file_path startupdir 0
	clear_cache_option
		| clearCache == Don`tClearCache
			= ""
		= " -clear_cache"

CompileStartCommand :: !String !Bool !(WindowFun *env) !CompileOrCheckSyntax !Pathname !(List Pathname) !Int !Bool !Bool !Bool !Bool
				!CompilerOptions !Pathname !CompilerProcessIds !*env
								-> (!Bool, !CompilerProcessIds,!*env) | FileEnv env
CompileStartCommand cocl write_module_times errwin compileOrCheckSyntax path paths slot projectMemoryProfiling projectTimeProfiling projectCallgraphProfiling projectEagerOrDynamic
					co=:{CompilerOptions | listTypes} startupdir compiler_psns ps
					
	# (cocl,compiler_full_path,signature) = mangleCompiler cocl startupdir
	# (error_code,error_n,compiler_psns,ps) = send_command_to_clean_compiler_without_waiting_for_reply_using_psn compiler_full_path command slot compiler_psns ps
	| error_code <> 0
		= ( False, compiler_psns,
			errwin ([ "Error: Unable to run compiler: "+++cocl
					+++ "; "+++ toString error_code
					+++ "; "+++ toString error_n
					]) ps
		)
     = (True,compiler_psns,ps)
where
	write_module_times_string = if write_module_times " -wmt " " "
	clearCache = Don`tClearCache	// needs to be arg to compile command???
	command
		= "cocl"
			+++" -id "+++toString slot
			+++clear_cache_option +++ write_module_times_string
			+++ MakeCompilerOptionsString
					compileOrCheckSyntax
					projectMemoryProfiling
					projectTimeProfiling
					projectCallgraphProfiling
					projectEagerOrDynamic
					co
        	+++ " -sl"
        	+++ " -P " +++ quoted_string (ConcatenatePath paths)
			+++ " " +++ quoted_string path
			+++ " > "+++ quoted_string out_file_name
			+++ " \xb3 "+++ quoted_string errors_file_name	// \xb3 == >= ligature
	out_file_name
		= out_file_path startupdir slot
	errors_file_name
		= errors_file_path startupdir slot
	clear_cache_option
		| clearCache == Don`tClearCache
			= ""
		= " -clear_cache"

ConcatenatePath :: (List Pathname) -> String
/* old version
ConcatenatePath Nil             = ""
ConcatenatePath (path :! rest ) = path +++ ";" +++ ConcatenatePath rest
*/
ConcatenatePath ss
	# s = createArray (sSize ss) ','
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
		= (Strip string :! Nil,True,file) // DvA (LastStrings string,True,file)
	| eof
		= (Nil,False,file)
	#	(typeslist,types_read,file)	= ReadTypeMsg file
	= (Strip string :! typeslist,types_read,file) // DvA (ReplaceLastChar string :! typeslist,types_read,file)

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
		= ((SyntaxError,False,Nil),env)
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
	#	(path_error,_/*errors_and_warnings_read*/,errlist,file3) = ReadErrorAndWarningMessages file2
	= (if is_import_error (Patherror path) path_error,True,Strip string:!errlist,file3)


MakeCompilerOptionsString :: !CompileOrCheckSyntax !Bool !Bool !Bool !Bool !CompilerOptions -> String
MakeCompilerOptionsString compileOrCheckSyntax projectMemoryProfiling projectTimeProfiling projectCallgraphProfiling projectEagerOrDynamic
			{neverMemoryProfile, neverTimeProfile,sa,gw,gc,listTypes,attr,reuseUniqueNodes}
	= options
where 
	memoryProfileSwitch
		| (not neverMemoryProfile && projectMemoryProfiling)
		|| projectEagerOrDynamic
			= " -desc"		// of " -pm" vroeger???
			= ""
	timeProfileSwitch
		| not neverTimeProfile && projectTimeProfiling
			= " -pt"
			= ""
	callgraphProfileSwitch
		| not neverTimeProfile && projectCallgraphProfiling
			= " -pg"
			= ""
	dynamicLinkSwitch
		| projectEagerOrDynamic
			= " -exl"
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

	options		= checksyntax +++ timeProfileSwitch +++ callgraphProfileSwitch +++ memoryProfileSwitch +++ dynamicLinkSwitch +++ strictness +++
						warnings +++ comments +++listtypes+++show_attr+++reuse+++" "
	

/* Generates code for the given file:
*/	
SwitchDebugMachO tp symbolic_machO normal :== case toString tp of
//	"PowerPC_MachO"	-> symbolic_machO
	_				-> normal

CodeGen	::	!String !Bool !(WindowFun *(PSt .l)) !CodeGenerateAsmOrCode !Pathname !Bool !CodeGenOptions !Processor !ApplicationOptions !Pathname
								!CompilerProcessIds !*(PSt .l)
			-> (!Pathname,!Bool,!CompilerProcessIds,!*(PSt .l))
CodeGen cgen` use_compiler_process_psn wf genAsmOrCode path timeprofile cgo tp ao startupdir compiler_psns ps
	# genAsmOrCode` = SwitchDebugMachO tp AsmGeneration genAsmOrCode
	# (cgen,name,signature)	= mangleGenerator cgen` startupdir
	#	objpath				= MakeObjSystemPathname tp path
		path_without_suffix	= RemoveSuffix path
		out_file_name
			= out_file_path startupdir 0
		errors_file_name
			= errors_file_path startupdir 0
		command				= cgen +++ MakeCodeGenOptionsString genAsmOrCode` timeprofile cgo 
								+++ " " +++ (quoted_string path_without_suffix)
								+++ " > " +++ quoted_string out_file_name 
								+++ " \xb3 " +++ quoted_string errors_file_name
  	# (error_code,error_n,output_string,compiler_psns,ps) =
  		if use_compiler_process_psn
			(send_command_to_clean_compiler_using_slot name command 0 compiler_psns ps)
			(let (error_code,error_n,ss) = send_command_to_clean_compiler_cg signature name command Wait
			 in (error_code,error_n,ss,compiler_psns,ps)
			)
  			
  	| error_code <> 0
		= (objpath, False,compiler_psns,wf ["Error: Unable to run code generator: "+++toString error_code] ps)

	| size output_string <> 0
		= (objpath, error_n == 0,compiler_psns,wf [ output_string, "Code generator called as: '" +++ command +++ "'"] ps)
		
	| error_n <> 0
		= (objpath, False,compiler_psns,wf [ "Error: Code generator: "+++toString error_n] ps)
	
	= SwitchDebugMachO tp
		(case genAsmOrCode of
			AsmGeneration	-> (ps,objpath,True)
			_
				# assembly_file_name = to_unix_path (RemoveSuffix objpath+++".a");
				# object_file_name = to_unix_path objpath;
				# (r1,r2,ps) = send_command_to_application False "EXEC"
					(	"/usr/bin/as '"
					+++	assembly_file_name
					+++	"' -o '"
					+++	object_file_name
					+++	"'"
					+++ " -g"	// for symbolic debugging info...
					) out_file_name ps
				-> (objpath,r1==r1,ps)
		)
		(objpath,True,compiler_psns,ps)

StartCodeGenerator	::	!String !(WindowFun *(PSt .l)) !CodeGenerateAsmOrCode !Pathname !Int !Bool !CodeGenOptions !Processor !ApplicationOptions !Pathname
						!CompilerProcessIds !*(PSt .l)
	-> (!Bool,!Pathname,!CompilerProcessIds,!*(PSt .l))
StartCodeGenerator cgen` wf genAsmOrCode path slot timeprofile cgo tp ao startupdir compiler_psns ps
	# (cgen,code_generator_full_path,signature) = mangleGenerator cgen` startupdir
	# objpath			= MakeObjSystemPathname tp path
	  path_without_suffix	= RemoveSuffix path
	  out_file_name = out_file_path startupdir slot
	  errors_file_name = errors_file_path startupdir slot
	  command		= cgen
						+++" -id "+++toString slot
						+++ MakeCodeGenOptionsString genAsmOrCode /*False*/timeprofile cgo
						+++ " " +++ (quoted_string path_without_suffix)
						+++ " > " +++ quoted_string out_file_name
						+++ " \xb3 " +++ quoted_string errors_file_name
	# (error_code,error_n,compiler_psns,ps) = send_command_to_clean_compiler_without_waiting_for_reply_using_psn code_generator_full_path command slot compiler_psns ps
  	| error_code<>0
		# ps = wf ["Error: Unable to run code generator: "+++toString error_code] ps
		= (False,objpath,compiler_psns,ps)
//	| size output_string <> 0
//		# ps = wf [output_string] ps
//		= (error_n == 0,objpath,compiler_psns,ps)
	= (error_n==0,objpath,compiler_psns,ps)

MakeCodeGenOptionsString genAsmOrCode timeprofile {ci,cs}
	= checkindex+++checkstack+++genasm	//+++timeProfileSwitch
where
	checkindex	| ci = " -ci"; = ""
	checkstack	| cs = " -os"; = ""
	timeProfileSwitch | timeprofile= " -pt"; = ""
	genasm		= case genAsmOrCode of
						AsmGeneration -> " -a"
						_ -> ""

/* Links the given file:
*/

Link ::	!String !(WindowFun *(PSt .l)) !Pathname !ApplicationOptions
		!Pathname !(List Pathname) !(List Pathname) !(List Pathname) !Bool 
		!Bool !Bool !Bool !String !Bool !String !Pathname !String !Processor !Bool !*(PSt .l)
		 -> (!*(PSt .l),!Bool)
Link linker` winfun path
		applicationOptions=:{fs,fn,em,ss,hs,initial_heap_size,profiling,heap_size_multiple,o,memoryProfilingMinimumHeapSize=minheap}
		optionspathname library_file_names object_file_names
		static_libraries static gen_relocs gen_linkmap
		link_resources resource_path gen_dll dll_names startupdir dynlinker processor use_64_bit_processor /*add_carb_resource*/ ps
	# (ok,linker)				= mangleLinker linker` startupdir
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
									DoesntExist -> createDirectory pd_optdirpath ps
									err  -> (err,ps)
	| err <> NoDirError
		= (winfun ["Linker error: Unable to access or create: "+++optdirpath] ps,False)
	# (options_file_ok,ps)		= accFiles (write_options_file optionspathname flags hs ss initial_heap_size heap_size_multiple minheap use_64_bit_processor) ps
	| not options_file_ok
		= (winfun ["Linker error: Could not write the options object file: "+++optionspathname] ps,False)
	# linkopts =
		{ exe_path				= path
		, res_path				= ""
		, open_console			= o <> NoConsole
		, static_link			= static
		, gen_relocs			= gen_relocs
		, gen_linkmap			= gen_linkmap
		, link_resources		= False
		, object_paths			= /*optionspathname :!*/ (RemoveDup object_file_names)
	  	, dynamic_libs			= RemoveDup library_file_names
	  	, static_libs			= RemoveDup static_libraries
	  	, stack_size			= ss
	  	, gen_dll				= gen_dll
	  	, dll_names				= dll_names
	  	, dynamics_path			= ""
	  	}
	# linkerpath				= RemoveFilename linker
	# linkoptspath				= MakeFullPathname TempDir "linkopts"
	# linkerrspath				= MakeFullPathname TempDir "linkerrs"
	# linker_out_o_path			= MakeFullPathname TempDir "linker_out.o"
	# (err,ps)					= accFiles (WriteLinkOpts linkoptspath linkopts) ps
	| isJust err
		= (winfun (fromJust err) ps,False)

	# objectFileNames			= StrictListToList (RemoveDup object_file_names)
	# libraryFileNames			= StrictListToList (RemoveDup library_file_names)
	# staticFileNames			= StrictListToList (RemoveDup static_libraries)
	
	| isEmpty objectFileNames
		= (winfun ["Linker error: No objects to link."] ps,False)
//	| isMachOObject (hd objectFileNames)
	| ProcessorSuffix processor == ".o"
		# ((ok,errs),ps)	= accFiles (link_mach_o_files` (objectFileNames ++ staticFileNames) linker_out_o_path) ps
		# command	=
			(	"/usr/bin/cc "
/*
			+++	concat_object_file_names objectFileNames
			+++	concat_object_file_names staticFileNames
*/
			+++	"'" +++ to_unix_path linker_out_o_path +++ "'"
			+++	" -framework Carbon"
			+++	" -o '"+++ to_unix_path path +++ "'"
//			+++ " -g"	// for debugging syms
			+++ " -Xlinker -stack_addr -Xlinker 0xc0000000 -Xlinker -stack_size -Xlinker 0x"+++stack_size_aligned_4k_hex_string
//			+++ if (ss > standard_mosx_stack) (" -stack-size " +++ stack_size_aligned_4k_hex_string) ""		
			+++ if (size linker`<>0) (" "+++linker`) ""
		//	+++ " -L/sw/lib -lgtk-x11-2.0 -lgdk-x11-2.0 -latk-1.0 -lgdk_pixbuf-2.0"	// 
		//	+++ " -lm -lpangoxft-1.0 -lpangox-1.0 -lpango-1.0 -lgobject-2.0 -lgmodule-2.0 -lglib-2.0 -lintl -liconv "
		//	+++ " -lpangoft2-1.0 "
			)
		# (r1,r2,ps) = send_command_to_application False "EXEC"
			command (to_unix_path linkerrspath/*startupdir +++ "/linker_out"*/) ps;
	
		| r1==(-1)
			= (winfun ["Linker error: Could not start the linker (/usr/bin/cc)."] ps,False)
		| r2<>0
			# ((errtext_not_empty,errtext),ps) = accFiles (ReadLinkInfo linkerrspath) ps;
			= (winfun
				[ "Linker error: Linker returned with error code: " +++toString r2
				, command
				: StrictListToList errtext
				] ps, False)
		// otherwise
		# application_existed = False;
		# (resources_ok,ps) = accFiles (create_application_resource path MachO application_existed (fs,fn) hs heap_size_multiple ss flags
										0 initial_heap_size minheap) ps
		# ((errtext_not_empty,errtext),ps) = accFiles (ReadLinkInfo linkerrspath) ps;
		= (winfun (StrictListToList errtext) ps, True)
	# ((link_ok,link_errors),ps)
		=	accFiles (link_xcoff_files objectFileNames libraryFileNames path
				(fs,fn) hs heap_size_multiple ss flags em initial_heap_size minheap False (if (ProcessorSuffix processor == ".xo") True False)/*add_carb_resource*/) ps
	# (errtext,errlines)	= (link_errors, length link_errors);

	| errlines<>0
		= (winfun errtext ps,link_ok)
	=  (ps,link_ok)
where
	stack_size_aligned_4k_hex_string = hex_int (roundup_to_multiple ss 4096)
	standard_mosx_stack = 0x080000	// 512K

link_mach_o_files` o_files app_path files
	# (ok,errs,files)	= link_mach_o_files o_files app_path files
	= ((ok,errs),files)
	
// from ExtInt module in pc linker
roundup_to_multiple s m :== (s + (dec m)) bitand (~m);

hexdigit :: !Int -> Char;
hexdigit i
	| i<10
		= toChar (toInt '0'+i);
		= toChar (toInt 'A'+i-10);

hex :: !Int -> String;
hex i
	#! i1 
		=(i bitand 0xf0) >> 4;
	#! i2
		=i bitand 0xf;
	= toString (hexdigit i1)+++toString (hexdigit i2);
	
hex_int :: !Int -> String;
hex_int i
	#! b0 
		= hex (i bitand 0x000000ff);
	#! b1
		= hex ((i bitand 0x0000ff00) >> 8);
	#! b2 
		= hex ((i bitand 0x00ff0000) >> 16);
	#! b3
		= hex ((i bitand 0xff000000) >> 24);
	= /*"0x" +++ */ b3 +++ b2 +++ b1 +++ b0;

ReadLinkInfo :: !Pathname !*Files -> ((!Bool, !List String), !*Files)
ReadLinkInfo path env
	#	(opened,file,env)			= fopen path FReadData env
	| not opened
		= ((False,Nil),env)
	#	(errlist,errors,file`)		= ReadLinkMsg file
		(_,env)						= fclose file` env
	= ((errors,errlist),env)
	
ReadLinkMsg :: !*File -> (!List String,!Bool,!*File)
ReadLinkMsg file
	#	(string,file)					= freadline file
		(eof,file)						= fend file
	| eof && IsLinkerErrorMsg string
		= (Strip string :! Nil,True,file)
	| eof
		= (Nil,False,file)
	#	(errmsg,_,file)	= ReadLinkMsg file
	= (Strip string :! errmsg,True,file)

// IsLinkerErrorMsg :: !String -> Bool;
IsLinkerErrorMsg str :== not (LayOut 0 (size str) str);
where
	LayOut :: !Int !Int !String -> Bool
	LayOut pos len str
		| pos >= len	= True
		| layout		= LayOut (inc pos) len str
						= False
	where
		layout	= curchar == ' ' || curchar == '\t'
		curchar	= str.[pos]

//

isMachOObject object = equal_suffix ".o" object

concat_object_file_names [file_name:file_names]
	= " '"+++to_unix_path file_name+++"'"+++concat_object_file_names file_names;
concat_object_file_names []
	= "";

import linker_resources;
import code from
//	"call_system_framework.o";
//	"call_system_framework.","pointer_glue."
	"cUtilSystem."

to_unix_path p
	# inpath	= p +++ "\0"
	# bsize		= 256
	# buffer	= createArray bsize '\0'
	# (res,_)	= hfs2posix inpath buffer bsize OSNewToolbox
	| res <> 0
		# posix	= toString (takeWhile ((<>) '\0') [c \\ c <-: buffer])
		= trace_n ("Path",posix) posix

fork_execv_waitpid :: !String !String -> (!Int,!Int);
fork_execv_waitpid s stdout_file_name
	= code {
		ccall fork_execv_waitpid "ss:II"
	};

fork_execv_pid :: !String -> (!Int,!Int);
fork_execv_pid s
	= code {
		ccall fork_execv_pid "s:II"
	};

GetProcessForPID :: !Int -> (!Int,!PSN);
GetProcessForPID pid
	# psn_string = createArray 8 '\0';
	# result = GetProcessForPID_ pid psn_string;
	| result==0
		= (result,string_to_psn psn_string);
		= (result,{highLongOfPSN=0,lowLongOfPSN=0});
	where
		GetProcessForPID_ :: !Int !{#Char} -> Int;
		GetProcessForPID_ pid psn_string
			= code {
				ccall GetProcessForPID "Is:I"
			}

send_command_to_application :: !Bool !String !String !String !*env -> (!Int,!Int,!*env);
send_command_to_application _ _ s stdout_file_name env
	# (r,status)=fork_execv_waitpid (s+++"\0") (stdout_file_name+++"\0");
	| r==(-1)
		= (-1,-1,env);
	| status bitand 0177<>0
		= (-1,status,env);
		= (0,status>>8,env);

/*
Link_ppc winfun path u_system_file_name paths defs
	applicationOptions=:{ss,fs,fn,hs,em,heap_size_multiple,initial_heap_size,profiling,profiling601,memoryProfilingMinimumHeapSize}
							linkOptions abcLinkObjFilePaths abcLinkLibraryPaths 
							prog=:{editor={startupinfo={startupdir},project}} ps
	# (u_startup_file_name,ps)
		= accFiles (MakeObjSystemPathname CurrentProcessor (MakeFullPathname system_directory_name startupModuleName)) ps
	# (u_library_object_file_name,ps)
		=	accFiles (MakeObjSystemPathname CurrentProcessor (MakeFullPathname system_directory_name "_library")) ps

	# ((link_ok,link_errors),ps)
		=	accFiles link ps
	# (errtext,errlines)	= StringToText (ListToStrictList link_errors);
	| errlines<>0
		= (winfun errtext prog ps,link_ok);
		= ((prog,ps),link_ok);
where
	link f = ((result, message), file)
	where
		(result, message, file)
			= link_xcoff_files objectFileNames libraryFileNames (MakeExecPathname path)
				(fs,fn) hs heap_size_multiple ss flags em initial_heap_size memoryProfilingMinimumHeapSize False f;


	objectFileNames
		=	removeDup	(	defaultObjects
						 ++ StrictListToList paths
						 ++ (StrictListToList linkOptions.extraObjectModules)
						 ++ (StrictListToList abcLinkObjFilePaths));	// MW P++

	startupModuleName
		| not profiling
			=	"_startup";
		| profiling601
			=	"_startupProfile601";
		| otherwise
			=	"_startupProfile";

	defaultObjects
		| linkOptions.useDefaultSystemObjects
			=	[u_startup_file_name, u_system_file_name, u_library_object_file_name];
		// otherwise
			=	[];

	libraryFileNames
		=	removeDup (defaultLibraries ++ (StrictListToList linkOptions.libraries)
										++ (StrictListToList abcLinkLibraryPaths));
	defaultLibraries
		| linkOptions.useDefaultLibraries
			= [	system_directory_name +++ ":library0",
							system_directory_name +++ ":library1",
							system_directory_name +++ ":library2"];		
		// otherwise
			=	[];
	flags					= ApplicationOptionsToFlags applicationOptions;

	system_directory_name = RemoveFilename u_system_file_name;
*/

DynLink :: !String !String !String !*(PSt .l) -> (Bool,*PSt .l)
DynLink linker prj_path startupdir ps
	= (False,ps)

//--- EXECUTE

Execute	::	!(WindowFun *env) !Pathname !ApplicationOptions !*env -> (!*env, !Bool)
Execute winfun path _ ps
	# (error_n,ps)	= Launch path ps
	| error_n >= 0
		= (ps,True)
		= (winfun ["Could not launch the application, MacOS error: "+++toString error_n] ps,False)

Launch :: !{#Char} !.a -> (!Int, !.a)
Launch execpath env
	# (error_n,fsspec,tb)	= FSMakeFSSpec execpath OSNewToolbox
	| error_n <> 0 = (error_n,env)
	# (error_n,tb)			= LaunchApplicationFSSpec fsspec 0xC800 tb
//	# (error_n,_) = LaunchApplication execpath 0xC8000000 OSNewToolbox
	= (error_n, env)

Execute` ::	!String !*env -> (!Bool,!Int,!*env)
Execute` execpath env
	# (ec,env)	= Launch execpath env
	= (ec==0,ec,env)

//--- OTHER STUFF

QuitCleanCompiler :: !Bool !CompilerProcessIds !*World -> *World
// want to quit all launched Compilers in any env...???
// means we need to keep track of these somehow.
QuitCleanCompiler False _ io
	# signature = "C2Co"//CleanCompilerSignature	// XOXOXOX
	| send_quit_event_to_clean_compiler signature == 0
		= io;
		= io;
QuitCleanCompiler True compile_psns io
	= quit_clean_compilers compile_psns io
	where
		quit_clean_compilers [compiler_psn:compiler_psns] io
			# os_error_code = send_quit_event_to_clean_compiler_using_psn compiler_psn
			| os_error_code==0
				= quit_clean_compilers compiler_psns io
				= quit_clean_compilers compiler_psns io
		quit_clean_compilers [] io
			= io

// necessary for Mac version?!
ClearCompilerCache :: !String !String !.a -> (!Int,!.a)
ClearCompilerCache cocl startupdir ps
	# (cocl,name,signature)	= mangleCompiler cocl startupdir	// platform dependant mangling...
//	# (os_error_code,_,_)	= send_command_to_clean_compiler_ca signature name "cocl -clear_cache" Wait
	# (os_error_code,_,_)	= send_command_to_clean_compiler_ca signature name "clear_cache" Wait
	= (os_error_code,ps)

:: PSN = {highLongOfPSN::!Int,lowLongOfPSN::!Int};

:: CompilerProcessIds :== [PSN];

NoCompilerProcessIds :: CompilerProcessIds
NoCompilerProcessIds = [];

ClearCompilerCaches :: !CompilerProcessIds !.a -> (!Int,!.a)
ClearCompilerCaches compiler_psns ps
	# os_error_code = clear_compiler_caches compiler_psns 0
		with
			clear_compiler_caches [compiler_psn:compiler_psns] previous_os_error_code
				# (os_error_code,_,_)	= send_command_to_clean_compiler_using_psn "clear_cache" compiler_psn
				| os_error_code==0 || previous_os_error_code<>0
					= clear_compiler_caches compiler_psns previous_os_error_code
					= clear_compiler_caches compiler_psns os_error_code
			clear_compiler_caches [] previous_os_error_code
				= previous_os_error_code
	= (os_error_code,ps)

SendRepeatResult :: !Int !.a -> (!Int,!.a)
SendRepeatResult compiler_n ps
  	#  name					= CleanCompilerName
  	#  signature				= clean_compiler_signature compiler_n
	# (os_error_code,_,_) = send_command_to_clean_compiler signature name "repeat_result" NoWait
	= (os_error_code,ps)

Wait :== True
NoWait :== False

send_command_to_clean_compiler :: !String !String !String !Bool -> (!Int,!Int,!String);
send_command_to_clean_compiler signature name command wait_for_reply
	# (os_error_code,error_n,output_string,tb)
		= send_command_to_clean_compiler0 signature command wait_for_reply OSNewToolbox
	| error_n<>(-2)
		= (os_error_code,error_n,output_string);

	# (error_n,fsspec,tb)	= FSMakeFSSpec name tb
	| error_n <> 0
		= (error_n,-2,output_string)
	# (launch_error_n,tb)	= LaunchApplicationFSSpec fsspec 0xCA00 tb
//	# (launch_error_n,_)
//		= LaunchApplication name 0xCA000000 OSNewToolbox;	// Hangs under OS X?
	| launch_error_n>=0	
		# (os_error_code,error_n,output_string,tb)
			= send_command_to_clean_compiler0 signature command wait_for_reply tb
		= (os_error_code,error_n,output_string)
	= (os_error_code,-2,output_string);

//--

import UtilPatch
	
PatchableCleanCompilerSignature
	:== "#$@CLCOSIGNAT%*&ClCo\0";
CleanCompilerSignature
	=: PatchableValue "CLCOSIGNAT" PatchableCleanCompilerSignature;

PatchableCleanCompilerName
	:== "#$@CLCONAME  %*&Clean Compiler\0............................some extra space for long names (total 128 chars).......................";
CleanCompilerName
	=: PatchableValue "CLCONAME  " PatchableCleanCompilerName;

clean_compiler_signature slot
	| slot==0
		= CleanCompilerSignature
		# s=CleanCompilerSignature
		= {s.[0],s.[1],s.[2],toChar (slot+48)}

//--
import events
KAEApplicationDied	:== 0x6F626974; // 'obit'

send_command_to_clean_compiler0 :: !String !String !Bool !*OSToolbox -> (!Int,!Int,!String,!*OSToolbox);
send_command_to_clean_compiler0 signature command wait tb
	| error_code1<>0
		= (error_code1,-1,"NewPtr failed",tb);
//	# error_code2 = AECreateDesc TypeApplSignature "MPSX" descriptor; // Tool Server
	# error_code2
		= trace_n "AECreateDesc" AECreateDesc TypeApplSignature signature descriptor;
	| error_code2<>0
		= (free_memory error_code2,-1,"AECreateDesc failed",tb);
	# error_code3
		= trace_n "AECreateAppleEvent" AECreateAppleEvent KAEMiscStandards KAEDoScript descriptor KAutoGenerateReturnID KAnyTransactionID apple_event;
	| error_code3<>0
		= (free_descriptor_and_memory error_code3,-1,"AECreateAppleEvent failed",tb);
	# error_code4
		= trace_n "AEPutParamPtr" AEPutParamPtr apple_event KeyDirectObject TypeChar command;
	| error_code4<>0
		= (free_apple_event_and_desciptor_and_memory error_code4,-1,"AEPutParamPtr failed",tb);
	# error_code5
		= case wait of
			True -> trace_n "AESend wait" AESend apple_event result_apple_event KAEWaitReply KAENormalPriority KNoTimeOut 0 0;
//			True -> loop OSNewToolbox;
			_	 -> trace_n "AESend nowait" AESend apple_event 0 KAEQueueReply KAENormalPriority KNoTimeOut 0 0;
	| error_code5==(-600)
		= (free_apple_event_and_desciptor_and_memory error_code5,-2,"AESend failed",tb);
	| error_code5==(-609)
		= (free_apple_event_and_desciptor_and_memory error_code5,-2,"AESend failed",tb);
	| error_code5==(-903)
		= (free_apple_event_and_desciptor_and_memory error_code5,-2,"need to add HighLevel event aware to SIZE resource of IDE...",tb);
	| error_code5==(-1712)
		= (free_apple_event_and_desciptor_and_memory error_code5,-1,"AESend failed; Application died",tb);
	| error_code5<>0
		= (free_apple_event_and_desciptor_and_memory error_code5,-1,"AESend failed",tb);
	| not wait
		= (free_apple_event_and_desciptor_and_memory error_code5,0,"",tb);
	# (error_code6,_,v1,_)
		= trace_n "AEGetIntParamPtr" AEGetIntParamPtr result_apple_event KeyErrorNumber TypeLongInteger;
	# (error_code7,_,s2)
		= trace_n "AEGetStringParamPtr" AEGetStringParamPtr result_apple_event KeyErrorString TypeChar result_string;
	# os_error_code
		= trace_n "fraeaaeadam" free_result_apple_event_and_apple_event_and_desciptor_and_memory error_code6 error_code7
	# error_n
//		= if (error_code6<0) 0 v1
		= if (error_code6<>0) 0 v1
	# output_string
		= if (error_code7<>0) "" (result_string % (0,s2-1))
	# tb = trace_n ("CALL",error_code6,v1,error_code7,s2) tb
	= (os_error_code,error_n,output_string,tb)
where
	loop tb
		# err	= AESend apple_event result_apple_event KAEWaitReply KAENormalPriority (60) 0 0;
		| err==(-1712)
			# (avail,what,message,when,wherex,wherey,modifiers,tb) = EventAvail NetworkMask tb
			| avail && what == HighLevelEvent && message == KCoreEventClass && wherex == KAEApplicationDied
				= -1712
			= loop tb
		= err
	result_string = createArray 5120 '0';

	(memory,error_code1,_)
		= NewPtr (SizeOfAEDesc+SizeOfAppleEvent+SizeOfAppleEvent) 0;
	descriptor
		= memory;
	apple_event
		= memory+SizeOfAEDesc;
	result_apple_event
		= memory+SizeOfAEDesc+SizeOfAppleEvent;

	free_result_apple_event_and_apple_event_and_desciptor_and_memory error_code6 error_code7
		| error_code6==error_code6 && error_code7==error_code7
			= free_apple_event_and_desciptor_and_memory free_error_code;
	where
		free_error_code = AEDisposeDesc result_apple_event;

	free_apple_event_and_desciptor_and_memory error_code
		| error_code==0
			= free_descriptor_and_memory free_error_code;
		| free_error_code==0
			= free_descriptor_and_memory error_code;
			= free_descriptor_and_memory error_code;
	where
		free_error_code = AEDisposeDesc apple_event;

	free_descriptor_and_memory error_code
		| error_code==0
			= free_memory free_error_code;
		| free_error_code==0
			= free_memory error_code;
			= free_memory error_code;
	where
		free_error_code = AEDisposeDesc descriptor;

	free_memory error_code
		| error_code==0
			= if (free_error_code==255) 0 free_error_code;
		| free_error_code==0
			= error_code;
			= error_code;
	where
		(free_error_code,_)	= DisposPtr memory 0;

send_command_to_clean_compiler_using_psn :: !String !PSN -> (!Int,!Int,!String);
send_command_to_clean_compiler_using_psn command psn
	# (memory,error_code1,_) = NewPtr (SizeOfAEDesc+SizeOfAppleEvent+SizeOfAppleEvent) 0;
	| error_code1<>0
		= (error_code1,-1,"");
	# descriptor=memory;
	# error_code2 = AECreateDesc TypeProcessSerialNumber (psn_to_string psn) descriptor;
	| error_code2<>0
		= (free_memory memory error_code2 0,-1,"");
	# apple_event=memory+SizeOfAEDesc;
	# error_code3 = AECreateAppleEvent KAEMiscStandards KAEDoScript descriptor KAutoGenerateReturnID KAnyTransactionID apple_event;
	| error_code3<>0
		= (free_descriptor_and_memory descriptor memory error_code3 0,-1,"");
	# error_code4 = AEPutParamPtr apple_event KeyDirectObject TypeChar command;
	| error_code4<>0
		= (free_apple_event_and_desciptor_and_memory apple_event descriptor memory error_code4 0,-1,"");
	# result_apple_event=memory+SizeOfAEDesc+SizeOfAppleEvent;
	# error_code5 = AESend apple_event result_apple_event KAEWaitReply KAENormalPriority KNoTimeOut 0 0;
	| error_code5==(-609)
		= (free_apple_event_and_desciptor_and_memory apple_event descriptor memory error_code5 0,-2,"");
	| error_code5==(-903)
		= (free_apple_event_and_desciptor_and_memory apple_event descriptor memory error_code5 0,-2,"need to add HighLevel event aware to SIZ resorce of IDE...");
	| error_code5<>0
		= (free_apple_event_and_desciptor_and_memory apple_event descriptor memory error_code5 0,-1,"");
		# (error_code6,_,v1,_) = AEGetIntParamPtr result_apple_event KeyErrorNumber TypeLongInteger;
		# result_string = createArray 5120 '0';
		# (error_code7,_,s2) = AEGetStringParamPtr result_apple_event KeyErrorString TypeChar result_string;
		= (free_result_apple_event_and_apple_event_and_desciptor_and_memory result_apple_event apple_event descriptor memory error_code6 error_code7,
			if (error_code6<0) 0 v1,
			if (error_code7<>0) "" (result_string % (0,s2-1)));

send_command_to_clean_compiler_using_slot :: !String !String !Int ![PSN] !*e -> (!Int,!Int,!String,![PSN],!*e) | FileEnv e;
send_command_to_clean_compiler_using_slot compiler_full_path command slot compiler_psns ps
	# (os_error_code,psn,compiler_psns,ps) = get_compiler_psn compiler_full_path slot compiler_psns ps
	| os_error_code<>0
		= (os_error_code,-1,"",compiler_psns,ps);
	# (os_error_code,error_n,result_string)=send_command_to_clean_compiler_using_psn command psn;
	| error_n<>(-2)
		= (os_error_code,error_n,result_string,compiler_psns,ps);
		= (os_error_code,-1,result_string,compiler_psns,ps);

from UtilIO import GetFullApplicationPath;

send_command_to_clean_compiler_without_waiting_for_reply_using_psn :: !String !String !Int ![PSN] !*e -> (!Int,!Int,![PSN],!*e) | FileEnv e;
send_command_to_clean_compiler_without_waiting_for_reply_using_psn compiler_full_path command slot compiler_psns ps
	# (os_error_code,psn,compiler_psns,ps) = get_compiler_psn compiler_full_path slot compiler_psns ps
	| os_error_code<>0
		= (os_error_code,-1,compiler_psns,ps);
	# (os_error_code,error_n)=send_command_to_clean_compiler_without_waiting_for_reply_using_psn0 command psn;
	| error_n<>(-2)
		= (os_error_code,error_n,compiler_psns,ps);
		= (os_error_code,-1,compiler_psns,ps);

get_compiler_psn :: !String !Int [.PSN] !*e -> (!Int,!PSN,![PSN],!*e) | FileEnv e;
get_compiler_psn compiler_full_path slot compiler_psns ps
	| slot<length compiler_psns
		= (0,compiler_psns !! slot,compiler_psns,ps);
	# (result,psn,ps) = start_compiler compiler_full_path ps;
	| result<>0
		= (result,{highLongOfPSN=0,lowLongOfPSN=0},compiler_psns,ps);
		= (0,psn,compiler_psns++[psn],ps);

start_compiler :: !String !*e -> (!Int,!PSN,!*e) | FileEnv e;
start_compiler compiler_full_path ps
	# clean_compiler_file_name = "'"+++to_unix_path compiler_full_path+++"'"
	# (result,pid) = fork_execv_pid (clean_compiler_file_name+++" -stdwin"+++"\0")
	| result<>0
		= (result,{highLongOfPSN=0,lowLongOfPSN=0},ps);
	= GetProcessForPID_ pid ps;
		with
			GetProcessForPID_ pid ps
				# (result,psn) = GetProcessForPID pid;
				| result== -600
					= GetProcessForPID_ pid ps
					= (result,psn,ps)

send_command_to_clean_compiler_without_waiting_for_reply_using_psn0 :: !String !PSN -> (!Int,!Int);
send_command_to_clean_compiler_without_waiting_for_reply_using_psn0 command psn
	# (memory,error_code1,_) = NewPtr (SizeOfAEDesc+SizeOfAppleEvent+SizeOfAppleEvent) 0;
	| error_code1<>0
		= (error_code1,-1);
	# descriptor=memory;
	# error_code2 = AECreateDesc TypeProcessSerialNumber (psn_to_string psn) descriptor;
	| error_code2<>0
		= (free_memory memory error_code2 0,-1);
	# apple_event=memory+SizeOfAEDesc;
	# error_code3 = AECreateAppleEvent KAEMiscStandards KAEDoScript descriptor KAutoGenerateReturnID KAnyTransactionID apple_event;
	| error_code3<>0
		= (free_descriptor_and_memory descriptor memory error_code3 0,-1);
	# error_code4 = AEPutParamPtr apple_event KeyDirectObject TypeChar command;
	| error_code4<>0
		= (free_apple_event_and_desciptor_and_memory apple_event descriptor memory error_code4 0,-1);
	# result_apple_event=memory+SizeOfAEDesc+SizeOfAppleEvent;
	# error_code5 = AESend apple_event 0/*result_apple_event*/ KAEQueueReply KAENormalPriority KNoTimeOut 0 0;
	| error_code5==(-609)
		= (free_apple_event_and_desciptor_and_memory apple_event descriptor memory error_code5 0,-2);
	| error_code5==(-903)
		= (free_apple_event_and_desciptor_and_memory apple_event descriptor memory error_code5 0,-2);
	| error_code5<>0
		= (free_apple_event_and_desciptor_and_memory apple_event descriptor memory error_code5 0,-1);
		= (free_apple_event_and_desciptor_and_memory apple_event descriptor memory error_code5 0,0);

free_result_apple_event_and_apple_event_and_desciptor_and_memory result_apple_event apple_event descriptor memory error_code6 error_code7
	# free_error_code = AEDisposeDesc result_apple_event;
	| error_code6==error_code6 && error_code7==error_code7
		= free_apple_event_and_desciptor_and_memory apple_event descriptor memory free_error_code 0;

free_apple_event_and_desciptor_and_memory apple_event descriptor memory error_code t
	# free_error_code = AEDisposeDesc apple_event;
	| error_code==0
		= free_descriptor_and_memory descriptor memory free_error_code t;
	| free_error_code==0
		= free_descriptor_and_memory descriptor memory error_code t;
		= free_descriptor_and_memory descriptor memory error_code t;

free_descriptor_and_memory descriptor memory error_code t
	# free_error_code = AEDisposeDesc descriptor;
	| error_code==0
		= free_memory memory free_error_code t;
	| free_error_code==0
		= free_memory memory error_code t;
		= free_memory memory error_code t;

free_memory memory error_code t
	# (free_error_code,_) = DisposPtr memory t;
	| error_code==0
		= if (free_error_code==255) 0 free_error_code;
	| free_error_code==0
		= error_code;
		= error_code;

psn_to_string {highLongOfPSN,lowLongOfPSN}
	= {	toChar (highLongOfPSN>>24),toChar (highLongOfPSN>>16),toChar (highLongOfPSN>>8),toChar highLongOfPSN,
		toChar (lowLongOfPSN>>24),toChar (lowLongOfPSN>>16),toChar (lowLongOfPSN>>8),toChar lowLongOfPSN };

string_to_psn psn_string
	= {	highLongOfPSN = (toInt psn_string.[0]<<24) bitor (toInt psn_string.[1]<<16) bitor (toInt psn_string.[2]<<8) bitor (toInt psn_string.[3]),
		lowLongOfPSN  = (toInt psn_string.[4]<<24) bitor (toInt psn_string.[5]<<16) bitor (toInt psn_string.[6]<<8) bitor (toInt psn_string.[7])
	  };

DisposPtr p t
	# t = DisposePtr p t
	= MemError t
where
	MemError :: !*Toolbox -> (!Int,!*Toolbox)
	MemError _ = code {
		ccall MemError "P:I:I"
		}

send_quit_event_to_clean_compiler :: !String -> Int;
send_quit_event_to_clean_compiler signature
	# (memory,error_code1,_) = NewPtr (SizeOfAEDesc+SizeOfAppleEvent+SizeOfAppleEvent) 0;
	  descriptor=memory;
	  apple_event=memory+SizeOfAEDesc;
	  result_apple_event=memory+SizeOfAEDesc+SizeOfAppleEvent;
	| error_code1<>0
		= error_code1;
	# error_code2 = AECreateDesc TypeApplSignature signature descriptor;
	= send_quit_event_to_clean_compiler_ error_code2 descriptor apple_event result_apple_event memory 

send_quit_event_to_clean_compiler_using_psn :: !PSN -> Int;
send_quit_event_to_clean_compiler_using_psn psn
	# (memory,error_code1,_) = NewPtr (SizeOfAEDesc+SizeOfAppleEvent+SizeOfAppleEvent) 0;
	  descriptor=memory;
	  apple_event=memory+SizeOfAEDesc;
	  result_apple_event=memory+SizeOfAEDesc+SizeOfAppleEvent;
	| error_code1<>0
		= error_code1;
	# error_code2 = AECreateDesc TypeProcessSerialNumber (psn_to_string psn) descriptor;
	= send_quit_event_to_clean_compiler_ error_code2 descriptor apple_event result_apple_event memory 

send_quit_event_to_clean_compiler_ error_code2 descriptor apple_event result_apple_event memory 
	| error_code2<>0
		= free_memory memory error_code2 0;
	# error_code3 = AECreateAppleEvent KCoreEventClass KAEQuitApplication descriptor KAutoGenerateReturnID KAnyTransactionID apple_event;
	| error_code3<>0
		= free_descriptor_and_memory descriptor memory error_code3 0;
	# error_code4 = AESend apple_event result_apple_event KAENoReply KAENormalPriority KNoTimeOut 0 0;
	| error_code4<>0
		= free_apple_event_and_desciptor_and_memory apple_event descriptor memory error_code4 0;
		= free_apple_event_and_desciptor_and_memory apple_event descriptor memory error_code4 0;

//--

import StdMaybe

:: ThreadId
	:==	Int

CompileHandleExitCode :: !Int !String !String !Int !(WindowFun *env) !(WindowFun *env) !Pathname
				!ListTypes !*env -> (!Pathname,!CompilerMsg,!*env) | FileEnv env
CompileHandleExitCode exitcode cocl startupdir slot errwin typewin path listTypes ps
	# out_file_name = out_file_path startupdir slot
	# errors_file_name = errors_file_path startupdir slot
	#	((type_text_not_empty,type_text),ps)
						= accFiles (ReadTypesInfo (listTypes<>NoTypes) out_file_name) ps
		((errors,errors_and_messages_not_empty,errors_and_messages),ps)
						= accFiles (ReadErrorsAndWarnings errors_file_name) ps
//		(abcpath,ps)	= accFiles (MakeABCSystemPathname path) ps
		abcpath			= MakeABCSystemPathname path
		ps				= case errors_and_messages_not_empty of
							True	-> trace_n "errwin" errwin (StrictListToList errors_and_messages) ps
							False	-> trace_n "ok" ps
		ps				= case type_text_not_empty of
							True	-> typewin (StrictListToList type_text) ps
							False	-> ps
     = (abcpath,if (exitcode==1) CompilerOK errors,ps)

:: CompilePollCompletedResult = NoFinishedCompiler | UnknownFinishedCompiler | FinishedCompiler !Int !Int

CompilePollCompleted :: !*env -> (!CompilePollCompletedResult, !*env) | FileEnv env
CompilePollCompleted env
	# (compiler_id,exit_code) = get_finished_compiler_id_and_exit_code
	| compiler_id<0
		| exit_code==1
			= (UnknownFinishedCompiler,env)
			= (NoFinishedCompiler,env)
		= (FinishedCompiler compiler_id exit_code,env);

get_finished_compiler_id_and_exit_code :: (!Int/*compiler_id*/,!Int/*exit_code*/);
get_finished_compiler_id_and_exit_code = code {
	ccall get_finished_compiler_id_and_exit_code ":II"
 }

:: CompilingInfo = CompilingInfo

InitCompilingInfo :: *CompilingInfo
InitCompilingInfo = CompilingInfo

ExitCleanCompiler :: !*(!*CompilingInfo,*env) -> *(!*CompilingInfo,*env)
ExitCleanCompiler (i,e) = (i,e)

CompilePersistent ::
	!String					// cocl
	!Bool
	!(WindowFun *env)		// errwin
	!(WindowFun *env)		// typewin
	!CompileOrCheckSyntax	// compileOrCheckSyntax
	!Pathname				// path
	!(List Pathname)		// paths
	!Bool					// projectHeapProfiling
	!Bool					// projectTimeProfiling
	!Bool					// projectEagerOrDynamic
	!CompilerOptions		// compileroptions
	!Pathname				// startupdir
	!*CompilingInfo			// compiler state
	!*env					// env
	-> (!*CompilingInfo,!(!*env, !Pathname, !CompilerMsg))
	| FileEnv env
CompilePersistent cocl write_module_times errwin typewin compileOrCheckSyntax path paths projectHeapProfiling projectTimeProfiling
	projectEagerOrDynamic compileroptions startupdir state env
	= (state,(errwin ["Error: Persistent not supported."] env,"",SyntaxError))

//--

from UtilIO import GetShortPathName
from DodoUtil import sSplit

mangleCompiler ccstring startupdir
	# (name,rest)			= sSplit ';' ccstring
	# (sign,cocl)			= sSplit ';' rest
	# name = case name of
				""	-> startupdir +++ toString dirseparator +++ "Clean Compiler"//\0"
				n	-> startupdir +++ toString dirseparator +++ n
	# sign = case sign of
				""	-> "ClCo"//\0"
				s	-> s
	# cocl = case cocl of
				""	-> "cocl"
				c	-> c
	= (cocl,name,sign)

mangleGenerator cgstring startupdir
	# (name,rest)			= sSplit ';' cgstring
	# (sign,cgen)			= sSplit ';' rest
	# name = case name of
				""	-> startupdir +++ toString dirseparator +++ "Clean Compiler"//\0"
				n	-> startupdir +++ toString dirseparator +++ n
	# sign = case sign of
				""	-> "ClCo"//\0"
				s	-> s
	# cgen = case cgen of
				""	-> "cg"
				c	-> c
	= (cgen,name,sign)

mangleLinker linkstr` startupdir
	# (linkstr`,opts)		= splitOptions linkstr`
	# (shortOK,linkstr)		= GetShortPathName (startupdir +++ toString dirseparator +++ linkstr` +++ "\0")
	| not shortOK
		# line				= "Error: Unable to get short path name '" +++ (startupdir +++ toString dirseparator +++ linkstr`) +++ "'."
		= (False,line)
	# linkstr = linkstr % (0, size linkstr - 2) +++ opts
	= (True,linkstr)

splitOptions str
	| first_q >= len_str	= (str,"")
	| last_q >= len_str		= (first_str,"")
	= (first_str,last_str)
where
	first_str =  str%(0,dec first_q)
	last_str = str % (inc first_q, dec last_q)

	len_str = size str
	
	first_q			= FindQuoteChar str len_str 0
	last_q			= FindQuoteChar str len_str (inc first_q)
		
	//	FindQuoteChar	:: !String !Int !Int -> Int;
	FindQuoteChar str len pos	= FindChar '\"' str len pos;

	FindChar	:: !Char !.String !.Int !Int -> Int;
	FindChar c line linelen pos
		| pos >= linelen		=  pos;
		| c ==  line.[pos]		=  pos;
								=  FindChar c line linelen (inc pos);
	
//////
//import code from "cpathutil.xo"
import code from library "winmod_library"

hfs2posix :: !String !String !Int !*OSToolbox -> (!Int,!*OSToolbox)
hfs2posix _ _ _ _ = code {
	ccall hfs2posix "ssI:I:I"
	}
//Boolean hfs2posix(char *hfsPath,char *buffer,int size)
/*
        e=FSMakeFSSpec (0/*vRefNum*/,0/*dirID*/,
#if 1
/*      "\pClean:Clean 13:Clean Compiler", */
//      "\pClean:Clean 2.0:Clean2.0InterfaceLib:CleanCocl copy",
//      "\pClean:Clean 2.0:CleanCoclTest 00",
//      "\pCleanCoclTest 00",
//      "\pLaunchApplication",
        "\pLaunchCleanCompiler",
#else
        "\pClean:Clean 13:Clean13:build:Clean13.app:Contents:MacOS:Clean13",
#endif
        &fs_spec);

        if (e!=noErr){
                printf ("%d\n",e);
                return 1;
        }

        e=FSpMakeFSRef (&fs_spec,&fs_ref);
        if (e!=noErr){
                printf ("%d\n",e);
                return 1;
        }

        {
                CFURLRef CFURL_ref;
                CFStringRef string_ref;
                Boolean r;
                int string_size;

                CFURL_ref=CFURLCreateFromFSRef (NULL,&fs_ref);
#if 0
                CFURL_ref=CFURLCreateCopyDeletingLastPathComponent (NULL,CFURL_ref);

                CFURL_ref=CFURLCreateCopyDeletingLastPathComponent (NULL,CFURL_ref);

                CFURL_ref=CFURLCreateCopyDeletingLastPathComponent (NULL,CFURL_ref);
#endif
                CFURL_ref=CFURLCreateCopyDeletingLastPathComponent (NULL,CFURL_ref);

                string_ref=CFStringCreateWithCString (NULL,"CleanCocl",kCFStringEncodingASCII);

                CFURL_ref=CFURLCreateCopyAppendingPathComponent (NULL,CFURL_ref,string_ref,0);

                string_size=512;
                r=CFURLGetFileSystemRepresentation (CFURL_ref,1,buffer,string_size);

                if (string_size<=512)
                        buffer[string_size]='\0';
                /*
                printf ("%d %s\n",string_size,buffer);
                */
                r=CFURLGetFSRef (CFURL_ref,&fs_ref);
        }
*/

from osevent import startTracking,::OSTime,OSTime,::OSToolbox

DelayEventLoop :: !.ps -> .ps;
DelayEventLoop ps
	| startTracking (OSTime -1) 0<=0x7fffffff
		= ps
		= ps
