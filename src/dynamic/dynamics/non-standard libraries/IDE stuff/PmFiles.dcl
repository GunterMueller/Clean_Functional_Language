definition module PmFiles

//	File I/O routines for the project manager.

import PmPath
import UtilOptions
import PmCompilerOptions
import PmTypes

ProjectTable :: OptionsTable ProjectGlobalOptions

CompilerOptionsTable :: OptionsTable CompilerOptions
CodeGenOptionsTable :: OptionsTable CodeGenOptions
LinkOptionsTable :: OptionsTable LinkOptions
ApplicationOptionsTable :: OptionsTable ApplicationOptions
ProjectOptionsTable :: OptionsTable ProjectOptions

ProjectFileVersion :== "1.4"

:: ProjectGlobalOptions =
	{ pg_built				:: !Bool
	, pg_codegen			:: CodeGenOptions
	, pg_application		:: ApplicationOptions
	, pg_projectOptions		:: ProjectOptions
	, pg_link				:: LinkOptions
	, pg_projectPaths		:: List Pathname
	, pg_otherModules		:: List ModInfoAndName
	, pg_mainModuleInfo		:: ModInfoAndName
	, pg_staticLibInfo		:: StaticLibInfo
	, pg_target				:: String
	, pg_execpath			:: String
	, pg_static				:: !ProjectStaticInfo
	, pg_dynamic			:: !ProjectDynamicInfo
	}

:: StaticLibInfo =
	{ sLibs :: !List Pathname
	, sDcls :: !List Modulename
	, sDeps :: !List Modulename
	}

:: ProjectStaticInfo =
	{ stat_mods				:: !List Pathname
	, stat_objs				:: !List Pathname
	, stat_slibs			:: !List Pathname
	, stat_dlibs			:: !List Pathname
	, stat_paths			:: !List Pathname
	, stat_app_path			:: !Pathname
	, stat_prj_path			:: !Pathname
	}

:: ProjectDynamicInfo =
	{ dyn_syms				:: !List UndefSymbol
	, dyn_mods				:: !List UndefModule
	, dyn_objs				:: !List Pathname
	, dyn_slibs				:: !List Pathname
	, dyn_dlibs				:: !List Pathname
	, dyn_paths				:: !List Pathname
	}

EmptyStaticInfo :: ProjectStaticInfo
EmptyDynamicInfo :: ProjectDynamicInfo

:: UndefSymbol =
	{ symbol_name	:: !String
	, path			:: !String
	}
 
:: UndefModule =
	{ module_name	:: !String
	, path			:: !String
	}
 
EmptyUndefSymbol	:: UndefSymbol
EmptyUndefModule	:: UndefModule
