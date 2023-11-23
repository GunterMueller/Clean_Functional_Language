implementation module target

import StdEnv
import PmMyIO
import UtilOptions
import UtilStrictLists
import StdPathname
import StdMaybe

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

openTargets :: !String !*env -> *(Bool,[Target],*env) | FileEnv env
openTargets envpath env
	# (stup,env)				= accFiles GetFullApplicationPath env
	# ((targets,ok,_),env)	= accFiles (openEnvironments envpath) env
	= (ok,map (fixAppPaths stup) targets,env)

/* Variant die in dir zoekt naar alle *.env bestanden?
 * Eerst beginnen met targets in leesbare variant weg te schrijven...
 * Rekening houden met exemplaren oude variant...
 */

EnvFileVersion :== "1.0"

emptyTarget :: !Target;
emptyTarget =
	{ target_name	= ""
	, target_path	= Nil
	, target_libs	= Nil
	, target_objs	= Nil
	, target_stat	= Nil
	, target_comp	= ""
	, target_cgen	= ""
	, target_link	= ""
	, target_dynl	= ""
	, target_vers	= 42
	}

openEnvironments :: !String *a -> *(([Target],.Bool,{#Char}),*a) | FileSystem a
openEnvironments envpath env
	# (opened, file, env)		= fopen envpath FReadData env
	| not opened
		= (([],False,"The file \"" +++  envpath +++ "\" could not be opened."),env)
	# (version, file)			= ReadVersion file
	| version <> EnvFileVersion
		# (_, env)				= fclose file env
		= (([],False,"The file \"" +++  envpath +++ "\" has the wrong version."+++version+++"<<<"),env)
	#! 	(options, file)			= ReadOptionsFile file
		targets					= REO options
		(closed, env)			= fclose file env
	| not closed
		=	((targets, True,"The file \"" +++ envpath +++ "\" clould not be closed."), env)	// warning genereren of zo?
	=	((targets, True,""), env)

saveEnvironments :: !String [.Target] *a -> *(Maybe .[{#Char}],*a) | FileSystem a
saveEnvironments envpath targets env
	# (opened, file, env)		= fopen envpath FWriteText env
	| not opened
		=	(Just ["Fatal open environments..."],env)
	#! options					= WEO targets
	#! file						= WriteOptionsFile EnvFileVersion options file
	# (closed,env)				= fclose file env
	| not closed
		= (Just ["Fatal close environments..."],env)
	= (Nothing,env)

WEO prefs
	= PutOptions TargetsTable prefs

REO options
	= GetOptions TargetsTable options []

TargetsTable =
	{ ListOption "Environments" (TargetTableOption) emptyTarget (\a->ListToStrictList a) (\v a->StrictListToList v)
	}

TargetTableOption = GroupedOption "Environment" TargetTable id const

TargetTable :: OptionsTable Target
TargetTable =
	{ SimpleOption	"EnvironmentName"			(\a->a.target_name) (\v a->{a & target_name=v})
	, ListOption	"EnvironmentPaths"			(PathOption) "" (\a-> a.target_path) (\v a->{a & target_path= v})
	, ListOption	"EnvironmentDynamicLibs"	(PathOption) "" (\a-> a.target_libs) (\v a->{a & target_libs= v})
	, ListOption	"EnvironmentObjects"		(PathOption) "" (\a-> a.target_objs) (\v a->{a & target_objs= v})
	, ListOption	"EnvironmentStaticLibs"		(PathOption) "" (\a-> a.target_stat) (\v a->{a & target_stat= v})
	, SimpleOption	"EnvironmentCompiler"		(\a->a.target_comp) (\v a->{a & target_comp=v})
	, SimpleOption	"EnvironmentCodeGen"		(\a->a.target_cgen) (\v a->{a & target_cgen=v})
	, SimpleOption	"EnvironmentLinker"			(\a->a.target_link) (\v a->{a & target_link=v})
	, SimpleOption	"EnvironmentDynLink"		(\a->a.target_dynl) (\v a->{a & target_dynl=v})
	, SimpleOption	"EnvironmentVersion"		(\a->toString a.target_vers) (\v a->{a & target_vers=toInt v})
	}

PathOption = SimpleOption "Path" id const


defaultTargets :: !String !*env -> *([Target],*env) | FileEnv env
defaultTargets envpath env
	#	(stup,env)		= accFiles GetFullApplicationPath env
	#	targets			= map (fixAppPaths stup) [t_StdEnv,t_StdIO]
	#	(_,env)			= saveTargets envpath targets env
	= (targets,env)

saveTargets :: !String ![Target] !*env -> *(Bool,*env) | FileEnv env
saveTargets envpath targets env
	# (stup,env)	= accFiles GetFullApplicationPath env
	# targets		= map (unfixAppPaths stup) targets
	# (err,env)		= accFiles (saveEnvironments envpath targets) env
	# ok			= isNothing err
	= (ok,env)
/*
toS [] = ""
toS [{target_name}:r] = "\n"+++target_name+++toS r
*/
//---

t_StdEnv :: !Target
t_StdEnv =
	{ target_name	= "StdEnv"
	, target_path	=
		( "{Application}\\StdEnv"
		:! Nil
		)
	, target_libs	=
		( "{Application}\\StdEnv\\Clean System Files\\user_library"
		:! "{Application}\\StdEnv\\Clean System Files\\gdi_library"
		:! "{Application}\\StdEnv\\Clean System Files\\comdlg_library"
		:! Nil
		)
	, target_objs	= Nil
	, target_stat	= Nil
	, target_comp	= "cocl.exe"
	, target_cgen	= "cg.exe"
	, target_link	= "StaticLinker.exe"
	, target_dynl	= "DynamicLinker.exe"
	, target_vers	= 918
	}

t_StdIO =
	{ target_name	= "IO 0.8"
	, target_path	=
		( "{Application}\\StdEnv"
		:! "{Application}\\IOInterface 0.8"
		:! Nil
		)
	, target_libs	=
		( "{Application}\\StdEnv\\Clean System Files\\user_library"
		:! "{Application}\\StdEnv\\Clean System Files\\gdi_library"
		:! "{Application}\\StdEnv\\Clean System Files\\comdlg_library"
		:! Nil
		)
	, target_objs	= Nil
	, target_stat	= Nil
	, target_comp	= "cocl.exe"
	, target_cgen	= "cg.exe"
	, target_link	= "StaticLinker.exe"
	, target_dynl	= "DynamicLinker.exe"
	, target_vers	= 918
	}

t_StdObj =
	{ target_name	= "Object IO 1.2"
	, target_path	=
		( "{Application}\\StdEnv"
		:! "{Application}\\Object IO 1.2"
		:! "{Application}\\Object IO 1.2\\OS Windows"
		:! "{Application}\\htmlHelp"
		:! Nil
		)
	, target_libs	=
		( "{Application}\\StdEnv Object IO\\Clean System Files\\user_library"
		:! "{Application}\\StdEnv Object IO\\Clean System Files\\gdi_library"
		:! "{Application}\\StdEnv Object IO\\Clean System Files\\comdlg_library"
		:! Nil
		)
	, target_objs	= Nil
	, target_stat	= Nil
	, target_comp	= "cocl.exe"
	, target_cgen	= "cg.exe"
	, target_link	= "StaticLinker.exe"
	, target_dynl	= "DynamicLinker.exe"
	, target_vers	= 918
	}

t_NewObj =
	{ target_name	= "Object IO 1.1"
	, target_path	=
		( "{Application}\\StdEnv"
		:! "{Application}\\Object IO 1.1"
		:! "{Application}\\Object IO 1.1\\OS Windows"
		:! Nil
		)
	, target_libs	=
		( "{Application}\\StdEnv\\Clean System Files\\user_library"
		:! "{Application}\\StdEnv\\Clean System Files\\gdi_library"
		:! "{Application}\\StdEnv\\Clean System Files\\comdlg_library"
		:! Nil
		)
	, target_objs	= Nil
	, target_stat	= Nil
	, target_comp	= "cocl.exe"
	, target_cgen	= "cg.exe"
	, target_link	= "StaticLinker.exe"
	, target_dynl	= "DynamicLinker.exe"
	, target_vers	= 918
	}


//--

fixAppPaths stup target=:{target_path = path, target_libs = libs, target_objs=objs, target_stat=stat}
	= {target & target_path = path`, target_libs = libs`, target_objs=objs`, target_stat = stat`}
where
	path` = Map (replace_prefix_path "{Application}" stup) path
	libs` = Map (replace_prefix_path "{Application}" stup) libs
	objs` = Map (replace_prefix_path "{Application}" stup) objs
	stat` = Map (replace_prefix_path "{Application}" stup) stat

unfixAppPaths stup target=:{target_path = path, target_libs = libs, target_objs=objs, target_stat=stat}
	= {target & target_path = path`, target_libs = libs`, target_objs=objs`, target_stat=stat`}
where
	path` = Map (replace_prefix_path stup "{Application}") path
	libs` = Map (replace_prefix_path stup "{Application}") libs
	objs` = Map (replace_prefix_path stup "{Application}") objs
	stat` = Map (replace_prefix_path stup "{Application}") stat
	