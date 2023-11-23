definition module PmCleanSystem

// Interface module for calling the CLEAN compiler, code generator and linker

import StdFile, StdMaybe
import StdPathname
import UtilStrictLists
import PmCompilerOptions
import PmTypes
import PmCallBack

standardStaticLibraries	:: !Processor !LinkMethod -> List String
standardObjectFiles		:: !Bool !Bool !Bool !Processor !Bool -> List String

getLibs :: ![String] !*Files -> (!(![String],![String]),!*Files)

:: CompilerProcessIds

NoCompilerProcessIds :: CompilerProcessIds

ClearCompilerCache :: !String !String !.a -> (!Int,!.a)
ClearCompilerCaches :: !CompilerProcessIds !.a -> (!Int,!.a)
QuitCleanCompiler :: !Bool !CompilerProcessIds !*World -> *World

//::	CompileClearCache	= ClearCache | Don`tClearCache
//instance == CompileClearCache

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
	pco_generic_fusion :: !Bool,
	pco_link_dynamic :: !Bool
   }

Compile ::						// Compiles the given file:
	!String						// compiler exe name and options
								// !! should be full path so that cocl generates diagnostics in logical place...
								// should be quoted if required
	!Bool
	!Bool						// write module times to abc file
	!(WindowFun *env)			// error display fun
	!(WindowFun *env)			// types display fun
	!CompileOrCheckSyntax		// check syntax only?
	!ModuleDirAndName
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
	!Bool
	!(WindowFun *GeneralSt)		// error display fun
	!CodeGenerateAsmOrCode		// generate assembly only?
	!Pathname					// full .abc pathname of module to be compiled
	!Pathname					// full object pathname of module to be compiled
	!Bool						// time profiling...
	!CodeGenOptions				// code generator options
	!Processor					// target processor
	!ApplicationOptions			// application options
	!Pathname					// startup directory
	!CompilerProcessIds
	!*GeneralSt					// state
	->
	( !Pathname					// full pathname of generated object file
	, !Bool						// success status
	, !CompilerProcessIds
	, !*GeneralSt				// state
	)

Link ::							// Links the given file:
	!String						// linker exe name
								// !! should be full path so that linker generates diagnostics in logical place...
								// this is quoted by the Link function because it first needs to decompose it...
	!(WindowFun *GeneralSt)		// error display fun
	!Pathname					// full pathname of the executable
	!ApplicationOptions			// application options
	!Pathname					// options pathname
	!(List Pathname)			// dynamic library file names
	!(List Pathname)			// object file names
	!(List Pathname)			// static library file names
	!Bool						// link statically?
	!Bool						// generate relocations?
	!Bool						// generate symbol table?
	!Bool						// generate link map?
	!Bool						// link in resources?
	!String						// source of resources to link in
	!Bool						// generate dll?
	!String						// name of file containing symbols to be exported from dll
	!Pathname					// startup directory
	!String						// path to dynamic linker
	!Processor					// target processor
	!Bool						// 64 bit target processor
	!*GeneralSt					// state
	->
	( !*GeneralSt				// state
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
	!ProjectCompilerOptions
	!CompilerOptions
	!Pathname
	!CompilerProcessIds
	!*env
	-> (!Bool,!CompilerProcessIds,!*env) | FileEnv env
CompileHandleExitCode :: !Int !String !String !Int !(WindowFun *env) !(WindowFun *env) !ModuleDirAndName
				!ListTypes !*env -> (!Pathname,!CompilerMsg,!*env) | FileEnv env

:: CompilePollCompletedResult = NoFinishedCompiler | UnknownFinishedCompiler | FinishedCompiler !Int !Int

CompilePollCompleted :: !CompilerProcessIds !*env -> (!CompilePollCompletedResult, !*env) | FileEnv env

:: CompilingInfo

InitCompilingInfo :: *CompilingInfo

ExitCleanCompiler :: !*(!*CompilingInfo,*env) -> *(!*CompilingInfo,*env)

CompilePersistent ::
	!String					// cocl
	!Bool						// write module times to abc file
	!(WindowFun *env)		// errwin
	!(WindowFun *env)		// typewin
	!CompileOrCheckSyntax	// compileOrCheckSyntax
	!ModuleDirAndName
	!(List Pathname)		// paths
	!ProjectCompilerOptions
	!CompilerOptions		// compileroptions
	!Pathname				// startupdir
	!*CompilingInfo			// compiler state
	!*env					// env
	-> (!*CompilingInfo,!(!*env, !Pathname, !CompilerMsg))
	| FileEnv env

StartCodeGenerator	::	!String !(WindowFun *GeneralSt) !CodeGenerateAsmOrCode !Pathname !Int !Bool !CodeGenOptions !Processor !ApplicationOptions !Pathname !CompilerProcessIds !*GeneralSt -> (!Bool,!Pathname,!CompilerProcessIds,!*GeneralSt)
SendRepeatResult :: !Int !.a -> (!Int,!.a)

DelayEventLoop :: !.ps -> .ps

:: StartedCodeGenerator

start_code_generator ::	!String !(WindowFun *GeneralSt) !Pathname !Int !Bool !CodeGenOptions !Processor !Pathname !*GeneralSt
						-> (!Bool,!Int/*HANDLE*/,!StartedCodeGenerator,!*GeneralSt)
finish_code_generator :: !Int/*HANDLE*/ !StartedCodeGenerator !Int !(WindowFun *GeneralSt) !*GeneralSt -> (!Bool,!*GeneralSt)
wait_for_finished_code_generator :: !{#Int} !*GeneralSt -> (!Int,!Int,!*GeneralSt);

RunExternalCommand :: !String ![String] !String !*GeneralSt -> *(!Int, ![String], !*GeneralSt)
