definition module PmEnvironment

import StdFile,StdString,StdMaybe
import UtilStrictLists
from PmTypes import ::Processor

EnvsFileName :== "IDEEnvs"

:: Target =
	{ target_name	:: !String			// environment identifier
	, target_path	:: !List String		// search paths
	, target_libs	:: !List String		// dynamic libraries
	, target_objs	:: !List String		// object files
	, target_stat	:: !List String		// static libraries
	, target_comp	:: !String			// compiler
	, target_cgen	:: !String			// code generator
	, target_abcopt	:: !String			// abc optimiser
	, target_bcgen	:: !String			// bytecode generator
	, target_bclink	:: !String			// bytecode linker
	, target_bcstrip :: !String			// bytecode stripper
	, target_bcprelink :: !String		// bytecode prelinker
	, target_link	:: !String			// static/eager linker
	, target_dynl	:: !String			// dynamic linker
	, target_vers	:: !Int				// abc version
	, env_64_bit_processor :: !Bool
	, target_redc	:: !Bool			// redirect console?
	, target_meth	:: !CompileMethod	// compile strategy
	, target_proc	:: !Processor		// object type
	}

:: CompileMethod
	= CompileSync
	| CompileAsync !Int
	| CompilePers
	
getEnvironments :: !String !String !*env -> *([Target],*env) | FileSystem, FileEnv env
openEnvironments	:: !String !String !*env -> *([Target],*env) | FileEnv env
openEnvironment :: !String *a -> *(([Target],.Bool,{#Char}),*a) | FileSystem a
saveEnvironments	:: !String ![Target] !*env -> *(Bool,*env) | FileEnv env

t_StdEnv :: Target
