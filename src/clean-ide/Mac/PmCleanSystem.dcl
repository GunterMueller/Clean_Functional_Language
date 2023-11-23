definition module PmCleanSystem

/* OS dependent module for windows */

/* Interface module for calling the CLEAN compiler, code generator and linker */

import StdFile, StdPSt
import StdPathname
import UtilStrictLists
import PmCompilerOptions
import PmTypes

//ifWindows w o :== o
standardStaticLibraries :: !Processor !LinkMethod -> List String
standardObjectFiles :: !Bool !Bool !Bool !Processor !Bool -> List String
getLibs :: ![String] !*Files -> (!(![String],![String]),!*Files)

:: CompilerProcessIds

NoCompilerProcessIds :: CompilerProcessIds

ClearCompilerCache :: !String !String !.a -> (!Int,!.a)
ClearCompilerCaches :: !CompilerProcessIds !.a -> (!Int,!.a)
QuitCleanCompiler :: !Bool !CompilerProcessIds !*World -> *World

::	CompileClearCache	= ClearCache | Don`tClearCache
instance == CompileClearCache

::	CompileOrCheckSyntax	= SyntaxCheck | Compilation
instance == CompileOrCheckSyntax

::	CodeGenerateAsmOrCode	= AsmGeneration | CodeGeneration
instance == CodeGenerateAsmOrCode

::	CompilerMsg
	= 	CompilerOK
	| 	SyntaxError
	| 	Patherror Pathname
instance == CompilerMsg

::	WindowFun env :== ([String]) -> env -> env

:: ProjectCompilerOptions = {
	pco_memory_profiling :: !Bool,
	pco_time_profiling :: !Bool,
	pco_callgraph_profiling :: !Bool,
	pco_desc_exl :: !Bool,
	pco_dynamics :: !Bool,
	pco_link_dynamic :: !Bool
   }

Compile ::						// Compiles the given file:
	!String						// compiler exe name and options
								// !! should be full path so that cocl generates diagnostics in logical place...
								// should be quoted if required
	!Bool						// use_compiler_process_psn
	!Bool						// send -wmt flag to compiler (write_module_times)
	!(WindowFun *env)			// error display fun
	!(WindowFun *env)			// types display fun
	!CompileOrCheckSyntax		// check syntax only?
	!Pathname					// full .icl pathname of module to be compiled
	!(List Pathname)			// list of paths where compiler can find imported .dcl files
	!ProjectCompilerOptions
	!CompilerOptions			// compiler options
	!Pathname					// startup directory
	!CompilerProcessIds
	!*env						// state
	->
	(!Pathname					// .abc pathname of generated code
//					Note: on the macintosh the .abc file is generated in the standard Clean System
//					Files Folder. On Unix, however, the location of the .abc depends on the user
//					settings.
	,!CompilerMsg				// indication whether compilation was successfull
	,!CompilerProcessIds
	,!*env						// state
	) | FileEnv env

CodeGen	::						// Generates code for the given file:
	!String						// generator exe name and options
								// !! should be full path so that cg generates diagnostics in logical place...
								// should be quoted if required
	!Bool						// use_compiler_process_psn
	!(WindowFun *(PSt .l))		// error display fun
	!CodeGenerateAsmOrCode		// generate assembly only?
	!Pathname					// full .abc pathname of module to be compiled
	!Bool						// timeprofiling option
	!CodeGenOptions				// code generator options
	!Processor					// target processor
	!ApplicationOptions			// application options
	!Pathname					// startup directory
	!CompilerProcessIds
	!*(PSt .l)					// state
	->
	(!Pathname					// full pathname of generated object file
//					Note: on the macintosh the .o file is generated in the standard Clean System
//					Files Folder. On Unix, however, the location of the .o depends on the user
//					settings.
	,!Bool							// success status
	,!CompilerProcessIds
	,!*(PSt .l)				// state
	)

StartCodeGenerator	::	!String !(WindowFun *(PSt .l)) !CodeGenerateAsmOrCode !Pathname !Int !Bool !CodeGenOptions !Processor !ApplicationOptions !Pathname
						!CompilerProcessIds !*(PSt .l)
	-> (!Bool,!Pathname,!CompilerProcessIds,!*(PSt .l))

Link ::							// Links the given file:
	!String						// linker exe name
								// !! should be full path so that linker generates diagnostics in logical place...
								// this is quoted by the Link function because it first needs to decompose it...
	!(WindowFun *(PSt .l))		// error display fun
	!Pathname					// full pathname of the executable
	!ApplicationOptions			// application options
	!Pathname					// options pathname
	!(List Pathname)			// dynamic library file names
	!(List Pathname)			// object file names
	!(List Pathname)			// static library file names
	!Bool						// link statically?
	!Bool						// generate relocations?
	!Bool						// generate link map?
	!Bool						// link in resources?
	!String						// source of resources to link in
	!Bool						// generate dll?
	!String						// name of file containing symbols to be exported from dll
	!Pathname					// startup directory
	!String						// dynamic linker name
//	!Bool						// add 'carb' 0 resource?
	!Processor					// target processor
	!Bool						// use_64_bit_processor
	!*(PSt .l)					// state
	->
	( !*(PSt .l)				// state
	, !Bool						// success status
	)

DynLink :: !String !String !String !*(PSt .l) -> (Bool,*PSt .l)

Execute	::						// Executes the given application
	!(WindowFun *env)			// error display fun
	!Pathname					// full pathname of the application
	!ApplicationOptions			// application options (only need the console flag)
	!*env						// state
	->
	( !*env						// state
	, !Bool						// success status
	)

Launch :: !{#Char} !.a -> (!Int, !.a)
Execute`	::	!String !*env -> (!Bool,!Int,!*env)

import StdMaybe

:: ThreadId
	:==	Int

CompileStartCommand :: !String !Bool !(WindowFun *env) !CompileOrCheckSyntax !Pathname !(List Pathname) !Int !Bool !Bool !Bool
				!CompilerOptions !Pathname !CompilerProcessIds !*env
								-> (!Bool, !CompilerProcessIds,!*env) | FileEnv env
CompileHandleExitCode :: !Int !String !String !Int !(WindowFun *env) !(WindowFun *env) !Pathname
				!ListTypes !*env -> (!Pathname,!CompilerMsg,!*env) | FileEnv env

:: CompilePollCompletedResult = NoFinishedCompiler | UnknownFinishedCompiler | FinishedCompiler !Int !Int

CompilePollCompleted :: !*env -> (!CompilePollCompletedResult, !*env) | FileEnv env

:: CompilingInfo

InitCompilingInfo :: *CompilingInfo

ExitCleanCompiler :: !*(!*CompilingInfo,*env) -> *(!*CompilingInfo,*env)

CompilePersistent ::
	!String					// cocl
	!Bool					// send -wmt flag to compiler (write_module_times)
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

SendRepeatResult :: !Int !.a -> (!Int,!.a)

DelayEventLoop :: !.ps -> .ps;
