implementation module PmCompilerOptions

import StdClass
import UtilDiagnostics

::	ListTypes	= NoTypes | InferredTypes | StrictExportTypes | AllTypes
	//	(Profile, NotUsed,Types,Show Attributes,Give Warnings,Be Verbose,
	//	Generate Comments)

instance == ListTypes
where
	(==) :: ListTypes ListTypes -> Bool
	(==) NoTypes NoTypes
		=	True
	(==) InferredTypes InferredTypes
		=	True
	(==) StrictExportTypes StrictExportTypes
		=	True
	(==) AllTypes AllTypes
		=	True
	(==) _ _
		=	False

instance toString ListTypes
where
	toString :: !ListTypes -> {#Char}
	toString NoTypes
		=	"NoTypes"
	toString InferredTypes
		=	"InferredTypes"
	toString StrictExportTypes
		=	"StrictExportTypes";
	toString AllTypes
		=	"AllTypes"

instance fromString ListTypes
where
	fromString :: {#Char} -> !ListTypes
	fromString "NoTypes"
		=	NoTypes
	fromString "InferredTypes"
		=	 InferredTypes
	fromString "StrictExportTypes"
		=	StrictExportTypes
	fromString "AllTypes"
		=	AllTypes
	fromString _
		=	Unexpected "fromString (Types): unknown Type" NoTypes


//	The Compiler Options: default settings for the compiler.
::	CompilerOptions	=
	{//	neverMemoryProfile	:: !Bool	// DvA: wordt niet meer op compiler niveau gedaan...
	//,
		neverTimeProfile	:: !Bool
	,	sa					:: !Bool
	,	listTypes			:: !ListTypes
	,	attr				:: !Bool
	,	gw					:: !Bool
	,	bv					:: !Bool
	,	gc					:: !Bool
	,	reuseUniqueNodes	:: !Bool 
	}

//	Compiler options that are stored in the abc file
::	ABCOptions		=
	{//	abcMemoryProfile 		:: !Bool
	//,
		abcTimeProfile			:: !Bool
	,	abcStrictnessAnalysis	:: !Bool
	,	abcGiveWarnings			:: !Bool
	,	abcBeVerbose			:: !Bool
	,	abcGenerateComments		:: !Bool
	,	abcReuseUniqueNodes 	:: !Bool 
	}

DefaultCompilerOptions :: CompilerOptions
DefaultCompilerOptions =
	{ neverTimeProfile		= False
	, sa					= True
	, listTypes				= NoTypes
	, attr					= False
	, gw					= False
	, bv					= False
	, gc					= False
	, reuseUniqueNodes		= False 
	}

DefaultABCOptions		:: ABCOptions;
DefaultABCOptions =
	{ abcTimeProfile			= False
	, abcStrictnessAnalysis		= True
	, abcGiveWarnings			= False
	, abcBeVerbose				= False
	, abcGenerateComments		= False
	, abcReuseUniqueNodes 		= False
	}
