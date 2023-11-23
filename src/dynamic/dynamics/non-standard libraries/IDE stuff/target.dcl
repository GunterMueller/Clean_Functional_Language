definition module target

import StdFile,StdString,StdMaybe//, StdPSt, IDE
import UtilStrictLists

:: Target =
	{ target_name	:: !String		// environment identifier
	, target_path	:: !List String	// search paths
	, target_libs	:: !List String	// dynamic libraries
	, target_objs	:: !List String	// object files
	, target_stat	:: !List String	// static libraries
	, target_comp	:: !String		// compiler
	, target_cgen	:: !String		// code generator
	, target_link	:: !String		// static/eager linker
	, target_dynl	:: !String		// dynamic linker
	, target_vers	:: !Int			// abc version
	}

openTargets	:: !String !*env -> *(Bool,[Target],*env) | FileEnv env
defaultTargets :: !String !*env -> *([Target],*env) | FileEnv env
saveTargets	:: !String ![Target] !*env -> *(Bool,*env) | FileEnv env

//openEnvironments :: !String *a -> *(([Target],.Bool,{#Char}),*a) | FileSystem a
//saveEnvironments :: !String [.Target] *a -> *(Maybe .[{#Char}],*a) | FileSystem a

t_StdEnv :: !Target
emptyTarget :: !Target;
