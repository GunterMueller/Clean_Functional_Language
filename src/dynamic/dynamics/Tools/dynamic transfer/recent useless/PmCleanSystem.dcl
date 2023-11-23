definition module PmCleanSystem

// Interface module for calling the CLEAN compiler, code generator and linker

import StdFile, StdPSt, StdMaybe
import StdPathname
import UtilStrictLists
import PmCompilerOptions
import PmTypes

standardStaticLibraries	:: !LinkMethod -> List String
standardObjectFiles		:: !Bool !Bool -> List String

getLibs :: ![String] !*Files -> (!(![String],![String]),!*Files)

ClearCompilerCache :: !.a -> (!Int,!.a)
QuitCleanCompiler :: !*(IOSt .l) -> *(IOSt .l)

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

::	WindowFun env :== !([String]) -> env -> env

Compile ::						// Compiles the given file:
	!String						// compiler exe name and options
								// !! should be full path so that cocl generates diagnostics in logical place...
								// should be quoted if required
	!Bool						// write module times to abc file
	!(WindowFun *env)			// error display fun
	!(WindowFun *env)			// types display fun
	!CompileOrCheckSyntax		// check syntax only?
	!Pathname					// full .icl pathname of module to be compiled
	!(List Pathname)			// list of paths where compiler can find imported .dcl files
	!Bool						// project memory profiling?
	!Bool						// project time profiling?
	!Bool						// project eager or dynamic linking?
	!CompilerOptions			// compiler options
	!Pathname					// startup directory
	!*env						// state
	->
	(!*env,						// state
	!Pathname					// .abc pathname of generated code
//					Note: on the macintosh the .abc file is generated in the standard Clean System
//					Files Folder. On Unix, however, the location of the .abc depends on the user
//					settings.
	,!CompilerMsg				// indication whether compilation was successfull
	) | FileEnv env

CodeGen	::						// Generates code for the given file:
	!String						// generator exe name and options
								// !! should be full path so that cg generates diagnostics in logical place...
								// should be quoted if required
	!(WindowFun *(PSt .l))		// error display fun
	!CodeGenerateAsmOrCode		// generate assembly only?
	!Pathname					// full .abc pathname of module to be compiled
	!Bool						// time profiling...
	!CodeGenOptions				// code generator options
	!ApplicationOptions			// application options
	!Pathname					// startup directory
	!*(PSt .l)					// state
	->
	( !*(PSt .l)				// state
	, !Pathname					// full pathname of generated object file
//					Note: on the macintosh the .o file is generated in the standard Clean System
//					Files Folder. On Unix, however, the location of the .o depends on the user
//					settings.
	, !Bool							// success status
	)

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
	!String						// path to dynamic linker
	!*(PSt .l)					// state
	->
	( !*(PSt .l)				// state
	, !Bool						// success status
	)
/*
DynLink :: !String !String !String !*(PSt .l) -> (Bool,*PSt .l)
*/
Execute	::						// Executes the given application
	!(WindowFun *env)			// error display fun
	!Pathname					// full pathname of the application
	!ApplicationOptions			// application options (only need the console flag)
	*env						// state
	->
	( *env						// state
	, !Bool						// success status
	)

Execute`	::	!String !*env -> (!Bool,!Int,!*env)


:: ThreadId
	:==	Int

CompileStartCommand ::
	!String
	!Bool						// write module times to abc file
	!(WindowFun *env)
	!CompileOrCheckSyntax
	!Pathname
	!(List Pathname)
	!Int
	!Bool
	!Bool
	!Bool
	!CompilerOptions
	!Pathname
	!*env
	-> (!Bool, !*env) | FileEnv env
CompileHandleExitCode :: !Int !String !String !Int !(WindowFun *env) !(WindowFun *env) !Pathname
				!ListTypes !*env -> (!*env,!Pathname,!CompilerMsg) | FileEnv env

/* old
CompilePollCompleted :: !*env -> (Maybe !(!Int,!Int), !*env) | FileEnv env
*/
:: CompilePollCompletedResult = NoFinishedCompiler | UnknownFinishedCompiler | FinishedCompiler !Int !Int

CompilePollCompleted :: !*env -> (!CompilePollCompletedResult, !*env) | FileEnv env

:: CompilingInfo

InitCompilingInfo :: !*CompilingInfo

ExitCleanCompiler :: !*(!*CompilingInfo,*env) -> *(!*CompilingInfo,*env)

CompilePersistent ::
	!String					// cocl
	!Bool						// write module times to abc file
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

ClearCompilerCaches :: !Int !.a -> (!Int,!.a)
StartCodeGenerator	::	!String !(WindowFun *(PSt .l)) !CodeGenerateAsmOrCode !Pathname !Int !Bool !CodeGenOptions !ApplicationOptions !Pathname !*(PSt .l) -> (!Bool,!Pathname,!*(PSt .l))
SendRepeatResult :: !Int !.a -> (!Int,!.a)


CallProcess :: !String [(!String,!String)] !String !String !String !String !*OSToolbox -> (!Bool, !Int, !*OSToolbox)

