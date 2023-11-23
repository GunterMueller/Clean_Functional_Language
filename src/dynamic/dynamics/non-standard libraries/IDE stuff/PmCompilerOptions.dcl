definition module PmCompilerOptions

import StdClass

::	ListTypes	= NoTypes | InferredTypes | StrictExportTypes | AllTypes

instance == ListTypes
instance toString ListTypes
instance fromString ListTypes

//	The Compiler Options: default settings for the compiler.
::	CompilerOptions	=
	{//	neverMemoryProfile	:: !Bool	// DvA: wordt niet meer op compiler niveau gedaan...
	//,
		neverTimeProfile	:: !Bool
	,	sa					:: !Bool	// strictness analysis
	,	listTypes			:: !ListTypes	// how to present inferred types
	,	attr				:: !Bool		// show attributes with inferred types
	,	gw					:: !Bool	// give warnings
	,	bv					:: !Bool	// be verbose
	,	gc					:: !Bool	// gen comments
	,	reuseUniqueNodes	:: !Bool 
	}

//	Compiler options that are stored in the abc file
::	ABCOptions		=
	{//	abcMemoryProfile 		:: !Bool
	//,
		abcTimeProfile			:: !Bool
	,	abcStrictnessAnalysis	:: !Bool
	,	abcGiveWarnings			:: !Bool //.
	,	abcBeVerbose			:: !Bool //.
	,	abcGenerateComments		:: !Bool
	,	abcReuseUniqueNodes 	:: !Bool 
	}

DefaultCompilerOptions :: CompilerOptions
DefaultABCOptions		:: ABCOptions
