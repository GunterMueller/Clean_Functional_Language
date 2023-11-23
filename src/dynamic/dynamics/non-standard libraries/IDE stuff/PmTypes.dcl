definition module PmTypes

/*	The types for the Editor */

import StdString
//from StdPicture import FontName, FontSize
import PmCompilerOptions
//1.3
from UtilStrictLists import List
from UtilNewlinesFile import
	NewlineConvention,
	NewlineConventionNone,
	NewlineConventionMac, NewlineConventionUnix, NewlineConventionDos

//3.1
/*2.0
from UtilStrictLists import ::List
from UtilNewlinesFile import
	::NewlineConvention(..),
	NewlineConventionNone,
	NewlineConventionMac, NewlineConventionUnix, NewlineConventionDos

0.2*/
//import StdPathname
//from PmMyIO import DATE
import UtilDate

::	Modulename			:== String

::	Processor = CurrentProcessor | MC68000 | MC68020 | MC68020_and_68881

instance == Processor
instance toString Processor
instance fromString Processor

:: LinkObjFileName	:== String
:: LinkLibraryName	:== String

//	The Defaults: default settings for the EditWindows, Compiler, Code Generator,
//	Application and search paths.
/*
::	Defaults	=
	{ defaultCompilerOptions	:: !CompilerOptions
	, cgo						:: !CodeGenOptions
	, linkOptions				:: !LinkOptions
	, ao						:: !ApplicationOptions
	, po						:: !ProjectOptions
	, paths						:: !List Pathname
//	, edit						:: !EditWdOptions
//	, clip						:: !EditWdOptions
//	, errors					:: !EditWdOptions
//	, types						:: !EditWdOptions
//	, dproject					:: !EditWdOptions 
	}
	// (compiler options,code generator options,application options, project manager options,
	// default search paths, edit/clipboard/errors/types/project window font&size)
*/
::	LinkOptions =
	{ extraObjectModules	:: !List {#Char}
	, libraries				:: !List {#Char}
	, method				:: !LinkMethod
	, generate_relocations	:: !Bool			// Win only option
	}

DefaultLinkOptions		:: LinkOptions

:: LinkMethod
	= LM_Static
	| LM_Eager
	| LM_Dynamic

instance toString LinkMethod
instance fromString LinkMethod
instance == LinkMethod

//	Window position and size

::	WindowPos_and_Size	=
	{ posx	:: !Int
	, posy	:: !Int
	, sizex	:: !Int
	, sizey	:: !Int
	}
	// (position of window, window size)
DefWindowPos_and_Size	:: WindowPos_and_Size

//	The Editor Options: default settings for the EditWindows.

::	EditOptions	=
	{ tabs		:: !Int
	, fontname	:: !String				// !FontName
	, fontsize	:: !Int					// !FontSize
	, autoi		:: !Bool
	, newlines	:: !NewlineConvention
	, showtabs	:: !Bool
	, showlins	:: !Bool
	, showsync	:: !Bool
	}
	// (tabs,font&size,auto indent)

//	The Window parameters: edit options and window position and size

::	EditWdOptions	=
	{ eo			:: !EditOptions
	, pos_size		:: !WindowPos_and_Size 
	}
	// edit options, window pos&size

//	The Code Generator Options: default settings for the code generator
::	CodeGenOptions	=
	{ cs	:: !Bool			// generate stack checks
	, ci	:: !Bool			// generate index checks
//	, kaf	:: !Bool			// keep abc-files
	, tp	:: !Processor
	}

DefCodeGenOptions		:: CodeGenOptions

//	The Application Options: default settings for the application.
::	ApplicationOptions	=
	{ hs								:: !Int			// heap size
	, ss								:: !Int			// stack size
	, em								:: !Int			// extra memory
	, heap_size_multiple				:: !Int
	, initial_heap_size					:: !Int
	, set								:: !Bool		// show execution time
	, sgc								:: !Bool		// show garbage collections
	, pss								:: !Bool		// print stack size
	, marking_collection				:: !Bool		// use marking garbage collector

	, o									:: !Output		// console type
	, fn								:: !String		// !FontName	// font name
	, fs								:: !Int			// !FontSize 	// font size
	, write_stderr_to_file				:: !Bool

	, memoryProfiling					:: !Bool
	, memoryProfilingMinimumHeapSize	:: !Int
	, profiling601						:: !Bool		// RWS: temporary
	, profiling							:: !Bool		// time profiling

	, standard_rte						:: !Bool		// DvA: use standard RTE (only in IDE)
	}

::	Output
	= BasicValuesOnly
	| ShowConstructors
	| NoConsole

DefApplicationOptions	:: ApplicationOptions

instance == Output
instance toString Output
instance fromString Output

//	The Project Manager Options: default settings for the project manager.
::	ProjectOptions =
	{ verbose	:: !Bool	//	be verbose
	}

DefProjectOptions		:: ProjectOptions

:: ModInfoAndName =
	{ info	:: ModInfo
	, name	:: {#Char}
	}

::	ModInfo =
	{ dir				:: !String				// !Pathname
	, compilerOptions	:: !CompilerOptions
	, defeo 			:: !EditWdOptions
	, impeo				:: !EditWdOptions
	, defopen 			:: !Bool
	, impopen 			:: !Bool
	, date 				:: !DATE
	, abcLinkInfo		:: !ABCLinkInfo
	}

:: ABCLinkInfo =
	{ linkObjFileNames :: !List LinkObjFileName
	, linkLibraryNames :: !List LinkLibraryName
	}

