definition module PmProject

import PmTypes
//1.3
from UtilStrictLists import List
//3.1
/*2.0
from UtilStrictLists import ::List
0.2*/
//from StdPictureDef import FontName, FontSize
import PmFiles
import StdMaybe

DclMod :== True
IclMod :== False

:: Def_and_Imp		:== Bool

:: Project

:: InfList

//--

SaveProjectFile	::
	!String			// !Pathname		// path to projectfile
	!Project		// the project
	!String			// !Pathname		// the application directory
	!*Files			// the filesystem environment
	->
	( !Bool			// success
	, !*Files		// returned filesystem
	);
ReadProjectFile	::
	!String			// !Pathname		// path to projectfile
	!String			// !Pathname		// the application directory
	!*Files			// the filesystem environment
	->
	((!Project		// the project
	, !Bool			// success: true if successful except when failed to close
					// project file. Then success is true but errmsg (next entry)
					// is nonempty.
	, !{#Char}		// errmsg: reports the encountered error if any
	),!*Files		// returned filesystem
	)

getStaticInfo :: !Project -> (ProjectStaticInfo,Project)
setStaticInfo :: !.ProjectStaticInfo !.Project -> .Project
getDynamicInfo :: !Project -> (ProjectDynamicInfo,Project)
setDynamicInfo :: !.ProjectDynamicInfo !.Project -> .Project

//--

PR_InitProject :: Project
PR_ProjectSet :: !Project -> Bool
PR_NewProject :: !String /*Pathname*/ !EditWdOptions !CompilerOptions !CodeGenOptions !ApplicationOptions !ProjectOptions
				!(List String /*Pathname*/) !LinkOptions -> Project

PR_SetBuilt	:: !(List Modulename) !Project -> Project
PR_ClearDependencies :: !Project -> Project
PR_SetRoot :: !String /*Pathname*/ !EditWdOptions !CompilerOptions !Project -> Project
PR_SetCompiled :: !Modulename !Project -> Project
PR_SetCodeGenerated	:: !Modulename !Project -> Project
PR_SetSysCodeGenerated :: !Project -> Project
PR_SetLinked :: !Project -> Project
PR_SetSaved :: !Project -> Project
PR_SetCodeGenOptions :: !CodeGenOptions !Project -> Project
PR_SetApplicationOptions :: !ApplicationOptions !Project -> Project
PR_SetProjectOptions :: !ProjectOptions !Project -> Project
PR_SetPaths	:: !Bool !(List String /*Pathname*/) !(List String /*Pathname*/) !Project -> Project

PR_GetCodeGenOptions :: !Project -> CodeGenOptions
PR_GetProcessor :: !Project -> Processor
PR_GetApplicationOptions :: !Project -> ApplicationOptions
PR_GetProjectOptions :: !Project -> ProjectOptions
PR_GetPaths	:: !Project -> List String /*Pathname*/
PR_GetRootModuleName :: !Project -> (String /*Pathname*/,Project)
PR_GetRootPathName :: !Project -> (String /*Pathname*/,Project)
PR_GetRootPath	:: !Project -> String /*Pathname*/;
PR_GetModulenames :: !Bool !Def_and_Imp !Project -> List String /*Pathname*/
PR_GetOpenModulenames	:: !Project -> List String /*Pathname*/
PR_GetModuleStuff :: !Project -> List (Modulename,String /*Pathname*/,Modulename,String /*Pathname*/)

PR_Built :: !Project -> Bool
PR_SrcUpToDate :: !Modulename !Project -> Bool
PR_ABCUpToDate :: !Modulename !Project -> Bool
PR_SysUptoDate :: !Project -> Bool
PR_ExecUpToDate :: !Project -> Bool
PR_Saved :: !Project -> Bool

PR_AddRootModule ::	!Bool !CodeGenOptions !ApplicationOptions !ProjectOptions !(List String /*Pathname*/) !LinkOptions
					!Modulename !ModInfo -> Project

PR_GetModuleInfo :: !Modulename !Project -> !Maybe ModInfo

PR_UpdateModule :: !Modulename !(!ModInfo -> ModInfo) !Project -> Project
PR_UpdateModules :: ![Modulename] !(!ModInfo -> ModInfo) !Project -> Project

PR_SetLinkOptions	:: !Project !LinkOptions -> Project
PR_GetLinkOptions	:: !Project -> LinkOptions

PR_AddABCInfo :: !String /*Pathname*/ !(List LinkObjFileName) !(List LinkLibraryName) !CompilerOptions !EditWdOptions !EditWdOptions !Project -> Project

PR_GetABCLinkInfo	:: !Project -> !ABCLinkInfo

PR_GetStaticLibsInfo :: !Project -> !StaticLibInfo
PR_SetStaticLibsInfo :: !StaticLibInfo !Project -> Project

isLibraryModule :: !.String !.StaticLibInfo -> Bool;
addLibraryDeps :: !.Modulename !(List .Modulename) !.StaticLibInfo -> List Modulename;

PR_GetTarget :: !Project -> !String
PR_SetTarget :: !String !Project -> Project

PR_GetExecPath	:: !Project -> !String /*Pathname*/
PR_SetExecPath	:: !String /*Pathname*/ !Project -> !Project

SL_Add :: !String /*Pathname*/ !StaticLibInfo -> StaticLibInfo
SL_Rem :: ![String /*Pathname*/] !String /*Pathname*/ !String /*Pathname*/ !StaticLibInfo -> StaticLibInfo
SL_Libs :: !StaticLibInfo -> List String /*Pathname*/
SL_Dcls :: !StaticLibInfo -> List String /*Pathname*/
SL_Deps :: !StaticLibInfo -> List String /*Pathname*/
SL_SetLibs :: !(List String /*Pathname*/) !StaticLibInfo -> StaticLibInfo
SL_SetDcls :: !(List String /*Pathname*/) !StaticLibInfo -> StaticLibInfo
SL_SetDeps :: !(List String /*Pathname*/) !StaticLibInfo -> StaticLibInfo

/* MPM */
UpdatePDIProjectFile :: .ProjectDynamicInfo {#.Char} {#.Char} *a -> *((.Bool,{#Char}),*a) | FileSystem a;
