implementation module PmTypes

/*	The types for the Editor */

import StdEnv//, StdIO
//import StdPathname
import PmMyIO, UtilDiagnostics, UtilStrictLists
//1.3
from UtilNewlinesFile import
	NewlineConvention,
	NewlineConventionNone,
	NewlineConventionMac, NewlineConventionUnix, NewlineConventionDos
//3.1
/*2.0
from UtilNewlinesFile import
	::NewlineConvention,
	NewlineConventionNone,
	NewlineConventionMac, NewlineConventionUnix, NewlineConventionDos
0.2*/
import PmCompilerOptions

::	Modulename			:== String

//--

::	Processor = CurrentProcessor | MC68000 | MC68020 | MC68020_and_68881

instance == Processor
where
	(==) :: Processor Processor -> Bool
	(==) CurrentProcessor CurrentProcessor
		=	True
	(==) MC68000 MC68000
		=	True
	(==) MC68020 MC68020
		=	True
	(==) MC68020_and_68881 MC68020_and_68881
		=	True
	(==) _ _
		=	False

instance fromString Processor
where
	fromString :: {#Char} -> Processor
	fromString "CurrentProcessor"
		=	CurrentProcessor
	fromString "MC68000"
		=	MC68000
	fromString "MC68020"
		=	MC68020
	fromString "MC68020_and_68881"
		=	MC68020_and_68881
	fromString string
		=	UnexpectedConstructor "Processor" string CurrentProcessor

instance toString Processor
where
	toString :: Processor -> {#Char}
	toString MC68000
		=	"MC68000"
	toString MC68020
		=	"MC68020"
	toString MC68020_and_68881
		=	"MC68020_and_68881"
	toString CurrentProcessor
		=	"CurrentProcessor"

:: ModInfoAndName =
	{
		info	:: ModInfo,
		name	:: {#Char}
	}

::	ModInfo	=
	{ dir				:: !String				// !Pathname			// directory
	, compilerOptions	:: !CompilerOptions		// compiler options
	, defeo 			:: !EditWdOptions		// edit options def module
	, impeo				:: !EditWdOptions		// edit options imp module
	, defopen 			:: !Bool				// dcl open?
	, impopen			:: !Bool				// icl open?
	, date				:: !DATE				// last scan date of file???
	, abcLinkInfo		:: !ABCLinkInfo
	}

:: ABCLinkInfo = {linkObjFileNames :: !List LinkObjFileName, linkLibraryNames :: !List LinkLibraryName}

:: LinkObjFileName	:== String
:: LinkLibraryName	:== String

//	The Defaults: default settings for the EditWindows, Compiler, Code Generator,
//	Application and search paths.

::	Defaults	=
	{ defaultCompilerOptions	:: !CompilerOptions
	, cgo						:: !CodeGenOptions
	, linkOptions				:: !LinkOptions
	, ao						:: !ApplicationOptions
	, po						:: !ProjectOptions
	, paths						:: !List String			// Pathname
	}

::	LinkOptions =
	{ extraObjectModules	:: !List {#Char}
	, libraries				:: !List {#Char}
	, method				:: !LinkMethod
	, generate_relocations	:: !Bool			// Win only option
	}

DefaultLinkOptions :: LinkOptions;
DefaultLinkOptions =
	{ extraObjectModules		= Nil
	, libraries					= Nil
	, method					= LM_Static
	, generate_relocations		= False
	}

:: LinkMethod
	= LM_Static
	| LM_Eager
	| LM_Dynamic

instance toString LinkMethod
where
	toString LM_Static	= "Static"
	toString LM_Eager	= "Eager"
	toString LM_Dynamic	= "Dynamic"
	
instance fromString LinkMethod
where
	fromString "Static"		= LM_Static
	fromString "Eager"		= LM_Eager
	fromString "Dynamic"	= LM_Dynamic
	fromString _			= LM_Static

instance == LinkMethod
where
	(==) :: !LinkMethod !LinkMethod -> Bool
	(==) LM_Static	LM_Static	= True
	(==) LM_Eager	LM_Eager	= True
	(==) LM_Dynamic	LM_Dynamic	= True
	(==) _			_			= False

//	Window position and size

::	WindowPos_and_Size	=
	{	posx	:: !Int
	,	posy	:: !Int
	,	sizex	:: !Int
	,	sizey	:: !Int
	}
	// (position of window, window size)
DefWindowPos_and_Size :: WindowPos_and_Size
DefWindowPos_and_Size =
	{ posx=0
	, posy=0
	, sizex=500
	, sizey=300
	}


//	The Editor Options: default settings for the EditWindows.

::	EditOptions	=
	{	tabs		:: !Int
	,	fontname	:: !String				// !FontName
	,	fontsize	:: !Int					// !FontSize
	,	autoi		:: !Bool
	,	newlines	:: !NewlineConvention
	,	showtabs	:: !Bool
	,	showlins	:: !Bool
	,	showsync	:: !Bool
	}
	// (tabs,font&size,auto indent)

//	The Window parameters: edit options and window position and size
::	EditWdOptions	=
	{	eo			:: !EditOptions
	,	pos_size	:: !WindowPos_and_Size 
	}
	// edit options, window pos&size
	
//	The Code Generator Options: default settings for the code generator
::	CodeGenOptions	=	{	cs	:: !Bool,
							ci	:: !Bool,
//							kaf	:: !Bool,
							tp	:: !Processor }

DefCodeGenOptions :: CodeGenOptions;
DefCodeGenOptions =
	{	cs		= False
	,	ci		= False
	,	tp		= CurrentProcessor
	}

//	The Application Options: default settings for the application.
::	ApplicationOptions	=
	{	hs								:: !Int
	,	ss								:: !Int
	,	em								:: !Int
	,	heap_size_multiple				:: !Int
	,	initial_heap_size				:: !Int
	,	set								:: !Bool
	,	sgc								:: !Bool
	,	pss								:: !Bool
	,	marking_collection				:: !Bool
	,	o								:: !Output
	,	fn								:: !String		// !FontName
	,	fs								:: !Int			// !FontSize
	,	write_stderr_to_file			:: !Bool
	,	memoryProfiling 				:: !Bool
	,	memoryProfilingMinimumHeapSize	:: !Int
	,   profiling601 					:: !Bool // RWS: temporary
	,	profiling 						:: !Bool 
	,	standard_rte					:: !Bool		// DvA: use standard RTE (only in IDE)
	}

DefApplicationOptions :: ApplicationOptions;
DefApplicationOptions =
	{	hs	= 409600
	,	ss	= 102400
	,	em	= 81920
	,	heap_size_multiple = 4096/*16*256*/
	,	initial_heap_size = 204800
	,	set	= False
	,	sgc	= False
	,	pss	= False
	,	marking_collection = False
	,	o	= ShowConstructors
	,	fn	= "Courier"
	,	fs	= 9
	,	write_stderr_to_file
						= False
	,	memoryProfiling = False
	,	memoryProfilingMinimumHeapSize = 0
	,	profiling601 = False
	,	profiling = False
	,	standard_rte = True
	}
	
::	Output = BasicValuesOnly | ShowConstructors | NoConsole
instance == Output
where
	(==) :: Output Output -> Bool
	(==) BasicValuesOnly BasicValuesOnly
		=	True
	(==) ShowConstructors ShowConstructors
		=	True
	(==) NoConsole NoConsole
		=	True
	(==) _ _
		=	False;

instance fromString Output
where
	fromString :: {#Char} -> Output
	fromString "BasicValuesOnly"
		=	BasicValuesOnly
	fromString "ShowConstructors"
		=	ShowConstructors
	fromString "NoConsole"
		=	NoConsole
	fromString string
		=	UnexpectedConstructor "Output" string BasicValuesOnly

instance toString Output
where
	toString :: Output -> {#Char}
	toString BasicValuesOnly
		=	"BasicValuesOnly"
	toString ShowConstructors
		=	"ShowConstructors"
	toString NoConsole
		=	"NoConsole"


	// Heap Size, Stack Size, Extra Memory,Show Execution Time,Show Garbage
	//		Collections, Print Stack Size,Output,Font Name,Font Size

//	The Project Manager Options: default settings for the project manager.
::	ProjectOptions		=	{	verbose	:: !Bool  }
	//	be verbose

DefProjectOptions :: ProjectOptions;
DefProjectOptions = {ProjectOptions | verbose = False}
		
