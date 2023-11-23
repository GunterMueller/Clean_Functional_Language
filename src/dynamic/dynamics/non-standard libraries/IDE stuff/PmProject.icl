implementation module PmProject

import StdClass,StdBool, StdInt, StdString,StdArray, StdFunc, StdTuple, StdList
import StdMaybe
import PmPath, UtilStrictLists
//import PmConstants
import UtilNewlinesFile
import PmTypes
//1.3
from PmMyIO import NoDate, DATE
from StdMisc import abort;
//3.1
/*2.0
from PmMyIO import NoDate, ::DATE
import StdEnv;
0.2*/

/* Comparison functions for project options */

instance == ModInfo
where
	(==) :: !ModInfo !ModInfo -> Bool
	(==) info1 info2
		=	info1.defeo.eo == info2.defeo.eo &&
			info1.impeo.eo == info2.impeo.eo &&
			info1.compilerOptions == info2.compilerOptions &&
			info1.defeo.pos_size == info2.defeo.pos_size && 
			info1.impeo.pos_size == info2.impeo.pos_size &&
			info1.defopen == info2.defopen &&
			info1.impopen == info2.impopen

instance == EditOptions
where
	(==) :: !EditOptions !EditOptions -> Bool
	(==) eo1 eo2
		=	eo1.tabs == eo2.tabs &&
			eo1.EditOptions.fontname == eo2.EditOptions.fontname &&
			eo1.EditOptions.fontsize == eo2.EditOptions.fontsize &&
			eo1.EditOptions.autoi == eo2.EditOptions.autoi

instance == WindowPos_and_Size
where
	(==) :: !WindowPos_and_Size !WindowPos_and_Size -> Bool
	(==) pos1 pos2
		=	pos1.posx == pos2.posx &&
			pos1.posy == pos2.posy &&
			pos1.sizex == pos2.sizex &&
			pos1.sizey == pos2.sizey

instance == CompilerOptions
where
	(==) :: !CompilerOptions !CompilerOptions -> Bool
	(==) co1 co2
		=	co1.neverTimeProfile == co2.neverTimeProfile &&
//			co1.neverMemoryProfile == co2.neverMemoryProfile &&	// DvA: wordt niet meer op compiler niveau gedaan...
			co1.sa == co2.sa &&
			co1.CompilerOptions.listTypes == co2.CompilerOptions.listTypes &&
			co1.gw == co2.gw &&
			co1.bv == co2.bv &&
			co1.gc == co2.gc
		
instance == CodeGenOptions
where
	(==) :: !CodeGenOptions !CodeGenOptions -> Bool
	(==) cg1 cg2
		=	cg1.cs == cg2.cs &&
			cg1.ci == cg2.ci &&
			cg1.tp == cg2.tp

instance == ApplicationOptions
where
	(==) :: !ApplicationOptions !ApplicationOptions -> Bool
	(==) ao1 ao2
		=	ao1.hs == ao2.hs &&
			ao1.ss == ao2.ss &&
			ao1.em == ao2.em &&
			ao1.heap_size_multiple == ao2.heap_size_multiple &&
			ao1.initial_heap_size == ao2.initial_heap_size &&
			ao1.set == ao2.set &&
			ao1.sgc == ao2.sgc &&
			ao1.pss == ao2.pss &&
			ao1.marking_collection == ao2.marking_collection &&
			ao1.o == ao2.o &&
			ao1.fn == ao2.fn &&
			ao1.fs == ao2.fs &&
			ao1.write_stderr_to_file == ao2.write_stderr_to_file &&
			ao1.memoryProfiling == ao2.memoryProfiling &&
			ao1.memoryProfilingMinimumHeapSize == ao2.memoryProfilingMinimumHeapSize &&
			ao1.profiling601 == ao2.profiling601 &&
			ao1.profiling == ao2.profiling &&
			ao1.standard_rte == ao2.standard_rte

instance == LinkOptions
where
	(==) :: !LinkOptions !LinkOptions -> Bool
	(==) lo1 lo2 =

		lo1.method == lo2.method &&
		EQStrings (SortStrings lo1.extraObjectModules) (SortStrings lo2.extraObjectModules) &&
		EQStrings (SortStrings lo1.libraries) (SortStrings lo2.libraries)

instance == ProjectOptions
where
	(==) :: !ProjectOptions !ProjectOptions -> Bool
	(==) po1 po2
		= po1.ProjectOptions.verbose == po2.ProjectOptions.verbose
	
instance == DATE
where
	(==) :: !DATE !DATE -> Bool
	(==) date1 date2
		=	date1.exists == date2.exists &&
			date1.yy == date2.yy &&
			date1.mm == date2.mm &&
			date1.dd == date2.dd &&
			date1.DATE.h == date2.DATE.h &&
			date1.m == date2.m &&
			date1.s == date2.s

//--

::	Def_and_Imp				:== Bool;
DclMod					:== True;
IclMod					:== False;

::	WindowOpen_and_Closed	:== Bool;
WinOpen					:== True;
WinClosed				:== False;
	
::	Modification			:== Bool;
Modified				:== True;
Unmodified				:== False;

//	The Project: A list of constituent modules and their mutual dependencies

::	Project	=
	{	built				:: !Bool					// Was dependency list generated?
	,	saved				:: !Bool
	,	exec				:: !Bool					// exe linked ok?
	,	execpath			:: !String /*Pathname*/
	,	inflist				:: !InfList					// list with constituent modules
	,	codegenopt			:: !CodeGenOptions			// code generator options
	,	code_gen_options_unchanged :: !Bool
	,	applicationopt		:: !ApplicationOptions		// application options
	,	projectopt			:: !ProjectOptions
	,	linkOptions			:: !LinkOptions
	,	prjpaths			:: !List String /*Pathname*/			// project paths
	,	staticLibInfo		:: !StaticLibInfo
	,	target				:: !String

	, static_info			:: !ProjectStaticInfo
	, dynamic_info			:: !ProjectDynamicInfo
	}

//	First element of InfList (if any) is the root module.

::	InfList		:==	List InfListItem
	
::	InfListItem	=	{ mn	:: !Modulename		// module name
					, info	:: !ModInfo			// module info
					, src	:: !Bool			// src up to date?
					, abc	:: !Bool 			// abc up to date?
					}

::	InfUpdate 	:== !InfListItem -> (!InfListItem, !Bool)

PR_InitProject :: Project;
PR_InitProject =
	{ built				= True
	, saved				= True
	, exec				= True
	, execpath			= EmptyPathname
	, inflist			= Nil
	, codegenopt		= DefCodeGenOptions
	, code_gen_options_unchanged	= True
	, applicationopt	= DefApplicationOptions
	, projectopt		= DefProjectOptions
	, linkOptions		= DefaultLinkOptions
	, prjpaths			= Nil
	, staticLibInfo		= DefStaticLibInfo
	, target			= ""
	, static_info		= EmptyStaticInfo
	, dynamic_info		= EmptyDynamicInfo
	}

PR_GetExecPath	:: !Project -> !String /*Pathname*/
PR_GetExecPath {execpath} = execpath

PR_SetExecPath	:: !String /*Pathname*/ !Project -> !Project
PR_SetExecPath pth prj = {prj & execpath = pth}

DefStaticLibInfo =
	{ sLibs = Nil
	, sDcls = Nil
	, sDeps = Nil
	}

PR_ProjectSet :: !Project -> Bool;
PR_ProjectSet project=:{inflist=Nil}	=  False;
PR_ProjectSet project=:{inflist}		=  True;

PR_NewProject :: !String /*Pathname*/ !EditWdOptions !CompilerOptions !CodeGenOptions !ApplicationOptions !ProjectOptions
				!(List String /*Pathname*/) !LinkOptions -> Project;
PR_NewProject main_module_file_name eo compilerOptions cgo ao po prjpaths linkOptions =
	{ PR_InitProject
	& built			= True
	, saved			= False
	, exec			= True
	, execpath		= MakeExecPathname main_module_file_name
	, inflist		=
		{ mn		= modname
		, info		=	{ dir		= dirname
						, defeo	= eo
						, impeo	= eo
						, compilerOptions		= compilerOptions
						, defopen	= False
						, impopen = True
						, date	= NoDate
						, abcLinkInfo = {linkObjFileNames = Nil, linkLibraryNames = Nil}
						}
		, src		= True
		, abc		= True
		} :! Nil
	, codegenopt	= cgo
	, code_gen_options_unchanged	= True
	, applicationopt= ao
	, projectopt	= po
	, prjpaths		= if (StringOccurs dirname prjpaths) prjpaths (dirname:!prjpaths)
	, linkOptions	= linkOptions
	, staticLibInfo = DefStaticLibInfo
	, target		= "StdEnv"
	}
where 
	modname	= GetModuleName main_module_file_name;
	dirname	= RemoveFilename main_module_file_name;
	
//--
PR_SetBuilt	:: !(List Modulename) !Project -> Project;
PR_SetBuilt used project=:{inflist=Nil} = {Project | project & built = True};
PR_SetBuilt used prj=:{inflist=infl=:(root=:{mn=rootmn,info}:!rest),saved}
	#! len		= LLength rest
	# used		= Map GetModuleName used
	# rest		= RemoveUnusedModules used rest
	# len`		= LLength rest
//	# prj = trace_n ("RemUnused B: "+++toString len+++" A: "+++toString len`) prj
	# unchanged	= len == len`
	= {prj & built=True,saved=saved && unchanged,inflist= root:!rest}
where	
	RemoveUnusedModules used list = FilterR member list
	where
		member {mn}	= StringOccurs mn used && rootmn <> mn
		
//--
//import StdDebug

PR_AddABCInfo :: !String /*Pathname*/ !(List LinkObjFileName) !(List LinkLibraryName) !CompilerOptions !EditWdOptions !EditWdOptions !Project -> Project
PR_AddABCInfo mod_path dep_objects dep_libraries compilerOptions defeo impeo project=:{inflist=Nil}
//	# project = trace_n ("PR_Add: no root...") project
	= project
PR_AddABCInfo mod_path dep_objects dep_libraries compilerOptions defeo impeo project=:{inflist}
//	# project = trace_n ("PR_Add: adding "+++mod_path) project
	# inflist		= TryInsertInList mod_name mod_dir inflist
	# (inflist,_)	= UpdateList mod_name update inflist;
	= {project & saved=False,inflist=inflist, built=False}
where
	mod_name			= GetModuleName mod_path
	mod_dir				= RemoveFilename mod_path

	update infListItem=:{InfListItem | info}
		= (	{ InfListItem | infListItem
			& info.abcLinkInfo.linkObjFileNames		= dep_objects
			, info.abcLinkInfo.linkLibraryNames		= dep_libraries
			, info.dir								= mod_dir
			, info.compilerOptions					= compilerOptions
			}, True)

	TryInsertInList :: !String !String !InfList -> !InfList
	TryInsertInList importermn importerdir Nil	// no root module...
		= Nil
	TryInsertInList importermn importerdir ((root=:{mn,info}):!rest)
		| importermn == mn	// updating root module...
			# root	= {InfListItem | root & info = {ModInfo | info & dir = importerdir}}
			= root :! rest
		# rest		= TryInsertImporter rest rest
		= root :! rest
	where
		TryInsertImporter ::	!InfList !InfList -> !InfList
		TryInsertImporter Nil list
			# item =
				  {	mn		= importermn, 
					info	= { dir		= importerdir,
								compilerOptions	
										= compilerOptions,
								defeo	= defeo,
								impeo	= impeo,
								defopen	= False,
								impopen	= False,
								date	= NoDate,
								abcLinkInfo = {linkObjFileNames = Nil, linkLibraryNames = Nil} },
					src		= True,
					abc		= True }
			= item :! list
		TryInsertImporter (({mn}):!rest) list
			| importermn<>mn
				= TryInsertImporter rest list
				= list
					

//--

PR_ClearDependencies :: !Project -> Project
PR_ClearDependencies project=:{inflist=Nil}
	= {project & saved = False, inflist = Nil, built = False}
PR_ClearDependencies project=:{inflist=il=:(root :! rest)}
	= {project & saved = False, inflist = root` :! Nil, built = False}
where
	root` =
		{ InfListItem
		| root
		& info =
			{ root.InfListItem.info
			& date = NoDate
			, abcLinkInfo = {linkObjFileNames = Nil, linkLibraryNames = Nil}}}
	
PR_SetRoot :: !String /*Pathname*/ !EditWdOptions !CompilerOptions !Project -> Project;
PR_SetRoot root eo co project=:{inflist=Nil}
	= project;
PR_SetRoot newroot eo compilerOptions project=:{prjpaths}
	=	{project &	saved	= False,
					built	= False,
					inflist	= {	mn		= modname,
								info	= {	dir		= dirname,
											defeo	= eo,
											impeo	= eo,
											compilerOptions		= compilerOptions,
											defopen	= False,	/* onzin, dat weet je niet! */
											impopen = True,
											date	= NoDate,
											abcLinkInfo = {linkObjFileNames = Nil, linkLibraryNames = Nil} },
								src		= True,
								abc		= True
								} :! Nil,
					prjpaths= if (StringOccurs dirname prjpaths) prjpaths (dirname:!prjpaths) /* ook een beetje iffy */
		  };
where 
	modname	= GetModuleName newroot;
	dirname	= RemoveFilename newroot;
	

PR_SetCompiled	:: !Modulename !Project -> Project;
PR_SetCompiled modname project=:{inflist}
	=  {project & inflist = inf`}
	where 
	(inf`, _)	= UpdateList modname setcompiled inflist;
	
	setcompiled	:: !InfListItem -> (!InfListItem,!Bool);
	setcompiled itm=:{src,abc}
		= ({itm & src = True},True);
	
		
PR_SetCodeGenerated	:: !Modulename !Project -> Project;
PR_SetCodeGenerated modname project=:{inflist}
	= {project & inflist = inf`};
	where 
	(inf`,_)	= UpdateList modname setcode inflist;
	
	setcode :: !InfListItem -> (!InfListItem, !Bool);
	setcode itm=:{InfListItem | src}
		= ({InfListItem | itm & abc = True}, True);
	
	
PR_SetSysCodeGenerated :: !Project -> Project;
PR_SetSysCodeGenerated project = {project & code_gen_options_unchanged = True};
	
PR_SetLinked	:: !Project -> Project;
PR_SetLinked project=:{inflist}
	=  {project & exec = True};
	
PR_SetSaved	:: !Project -> Project;
PR_SetSaved project = {Project | project & saved = True};
		
PR_SetCodeGenOptions	:: !CodeGenOptions !Project -> Project;
PR_SetCodeGenOptions options project=:{inflist,saved,codegenopt,code_gen_options_unchanged} =
	{ project
	& inflist						= infl`
	, saved							= saved && unchanged
	, code_gen_options_unchanged	= code_gen_options_unchanged && cg_unchanged
	, codegenopt					= options
	}
where 
	(infl`,_)				= infl`_;
	infl`_ | cg_unchanged	= (inflist,True);
							= P_MapR setcode inflist;
	unchanged				= cg_unchanged //&& options.kaf == codegenopt.kaf;
	cg_unchanged			= options == codegenopt;
	
	setcode :: !InfListItem -> (!InfListItem, !Bool);
	setcode itm=:{InfListItem | src}
		= ({InfListItem | itm & abc = False}, True);
	
	
PR_SetApplicationOptions :: !ApplicationOptions !Project -> Project;
PR_SetApplicationOptions options project=:{saved,exec,applicationopt}
	= {project & applicationopt = options, exec = exec && unchanged,saved=saved && unchanged};
	where 
		unchanged	= options == applicationopt;
	
	
PR_SetProjectOptions	:: !ProjectOptions !Project -> Project;
PR_SetProjectOptions options project=:{projectopt,saved}
	=  {project &	saved		= saved && unchanged,
					projectopt	= options };
	where 
		unchanged	= options == projectopt;
	

PR_SetLinkOptions	:: !Project !LinkOptions -> Project;
PR_SetLinkOptions project linkOptions
	| linkOptions == project.Project.linkOptions
		=	project;
	| otherwise
		=	{Project | project & linkOptions = linkOptions, exec = False, saved = False};

PR_GetLinkOptions	:: !Project -> LinkOptions;
PR_GetLinkOptions project
	=  project.Project.linkOptions;

PR_SetPaths	:: !Bool !(List String /*Pathname*/) !(List String /*Pathname*/) !Project -> Project;
PR_SetPaths _ _ _ _
	= abort "dkdk";
/*
PR_SetPaths def defs new project=:{Project | inflist=Nil} = project;
PR_SetPaths def defs new project=:{Project | built,inflist=infl=:(root=:{InfListItem | info={dir}}):!rest,prjpaths,saved}
	| def	= {Project | project &	built				= built && olddirs,
							saved				= saved && olddirs,
							inflist				= inflist1 };
			= {Project | project &	built 				= built && olddirs,
							saved				= saved && unchanged && olddirs,
							inflist				= inflist1,
							prjpaths			= prjpaths1 };
	where 
		(inflist1,olddirs)	= P_MapR SetDcl_and_Icl_and_ABCModified infl;
		unchanged			= EQStrings (SortStrings prjpaths) (SortStrings prjpaths1);
		prjpaths1 	| def	= prjpaths;
					| StringOccurs dir new
							= new;
							= dir:!new;
						
		SetDcl_and_Icl_and_ABCModified :: !InfListItem -> (!InfListItem,!Bool);
		SetDcl_and_Icl_and_ABCModified itm=:{InfListItem | info=minfo=:{dir}}
		| unchanged	= ({itm & src=False}, True);
					= ({itm & info = {minfo & dir="", date=NoDate}, src=False},False);
			where 
				unchanged	= StringOccurs dir defs || StringOccurs dir prjpaths1;
*/			
		
		
PR_GetCodeGenOptions :: !Project -> CodeGenOptions;
PR_GetCodeGenOptions project=:{codegenopt} =  codegenopt;

PR_GetProcessor :: !Project -> Processor;
PR_GetProcessor project=:{codegenopt={tp}} = tp;
	
PR_GetApplicationOptions :: !Project -> ApplicationOptions;
PR_GetApplicationOptions project=:{applicationopt} =  applicationopt;
	
PR_GetProjectOptions :: !Project -> ProjectOptions;
PR_GetProjectOptions project=:{projectopt} = projectopt;

PR_GetPaths	:: !Project -> List String /*Pathname*/;
PR_GetPaths project=:{Project | prjpaths} = prjpaths;

PR_GetRootModuleName :: !Project -> (String /*Pathname*/,Project)
PR_GetRootModuleName p=:{inflist=Nil}
	= (EmptyPathname,p)
PR_GetRootModuleName p=:{inflist={mn}:!rest}
	= (mn,p)

PR_GetRootPathName	:: !Project -> (String /*Pathname*/,Project)
PR_GetRootPathName p=:{inflist=Nil}
	= (EmptyPathname,p)
PR_GetRootPathName p=:{inflist={mn,info={dir}}:!rest}
	| size dir==0
		= (EmptyPathname,p)
		= (MakeFullPathname dir (MakeImpPathname mn),p)

PR_GetRootPath	:: !Project -> String /*Pathname*/;
PR_GetRootPath {inflist=Nil}
	= EmptyPathname;
PR_GetRootPath {inflist={mn,info={dir}}:!rest}
	| size dir==0
		= EmptyPathname;
		= dir;

PR_GetModulenames	:: !Bool !Def_and_Imp !Project -> List String /*Pathname*/
PR_GetModulenames full def project=:{inflist}
	= modnames
	where 
	(modnames,_)	= P_MapR GetModulenames inflist
	
	GetModulenames :: !InfListItem -> (!String /*Pathname*/,!Bool)
	GetModulenames {mn,info={dir}}
		| full && def	= (MakeFullPathname dir (MakeDefPathname mn),True)
		| full			= (MakeFullPathname dir (MakeImpPathname mn),True)
						= (mn,True)

PR_GetOpenModulenames	:: !Project -> List String /*Pathname*/
PR_GetOpenModulenames project=:{inflist}
	= FlattenList modnames
where 
	(modnames,_)	= P_MapR GetModulenames inflist
	
	GetModulenames :: !InfListItem -> (List !String /*Pathname*/,!Bool)
	GetModulenames {mn,info={dir,defopen,impopen}}
		| defopen && impopen	= ((defname :! impname :! Nil),True)
		| defopen				= ((defname :! Nil),True)
		| impopen				= ((impname :! Nil),True)
								= (Nil,True)
	where
		defname = MakeFullPathname dir (MakeDefPathname mn)
		impname = MakeFullPathname dir (MakeImpPathname mn)

PR_GetModuleStuff :: !Project -> List (Modulename,String /*Pathname*/,Modulename,String /*Pathname*/)
PR_GetModuleStuff project=:{inflist}
	= stuff
	where 
	(stuff,_)	= P_MapR GetModulenames inflist
	
	GetModulenames :: !InfListItem -> ((!Modulename,!String /*Pathname*/,!Modulename,!String /*Pathname*/),!Bool)
	GetModulenames {mn,info={dir}}
						= ((MakeDefPathname mn,dir,MakeImpPathname mn,dir),True)

PR_Built :: !Project -> Bool;
PR_Built project=:{Project | built} =  built;
		
PR_SrcUpToDate :: !Modulename !Project -> Bool;
PR_SrcUpToDate modname project=:{inflist}
	# item = FindInList modname inflist
	| isNothing item
		= False
	# item = fromJust item
	= item.src
	
	
PR_ABCUpToDate	:: !Modulename !Project -> Bool;
PR_ABCUpToDate modname project=:{inflist}
	# item = FindInList modname inflist
	| isNothing item
		= False
	# item = fromJust item
	= item.abc
	
	
PR_SysUptoDate :: !Project -> Bool;
PR_SysUptoDate project=:{code_gen_options_unchanged} = code_gen_options_unchanged;
	
PR_ExecUpToDate	:: !Project -> Bool;		
PR_ExecUpToDate project=:{exec} = exec;

PR_Saved :: !Project -> Bool;
PR_Saved {Project | saved} = saved;

PR_AddRootModule ::	!Bool !CodeGenOptions !ApplicationOptions !ProjectOptions !(List String /*Pathname*/) !LinkOptions
					!Modulename !ModInfo -> Project;
PR_AddRootModule built cg ao po prjs linkOptions mn info=:{dir}
  = { PR_InitProject
  	& built			= built && dir <> ""
	, saved			= False	// ???
	, exec			= True
	, execpath		= MakeExecPathname (MakeFullPathname dir mn)
	, code_gen_options_unchanged
						= True
	, inflist			= root:!Nil
	, codegenopt		= cg
	, applicationopt	= ao
	, projectopt		= po
	, prjpaths		= prjs
	, linkOptions	= linkOptions
	, staticLibInfo = DefStaticLibInfo
	, target = ""
	};
where 
	root	= {	mn		= mn,info	= info,src		= True,abc		= True };
	
	
PR_AddModule :: !Modulename !ModInfo !Project -> Project;
PR_AddModule mn info=:{dir} project=:{built,inflist=root:!rest}
	= {project & built = built && dir<>"", inflist = root:!new:!rest};
where 
	new	= {	mn		= mn,
			info	= info,
			src		= True,
			abc		= True };
	
	
PR_GetModuleInfo :: !Modulename !Project -> !Maybe ModInfo
PR_GetModuleInfo mn {Project | inflist}
	# item = FindInList mn inflist
	| isNothing item
		= Nothing
	= Just (fromJust item).InfListItem.info
	
PR_UpdateModule :: !Modulename !(!ModInfo -> ModInfo) !Project -> Project;
PR_UpdateModule mn update project=:{inflist,saved}
	= {project & inflist = infl`,saved = saved && unchanged};
where 
	(infl`,unchanged)	= UpdateList mn update` inflist;
	update` itm=:{InfListItem | info}	= ({InfListItem | itm & info = info`}, unchanged);
	where 
		info`		= update info;
		unchanged	= info == info`;
							
PR_UpdateModules :: ![Modulename] !(!ModInfo -> ModInfo) !Project -> Project
PR_UpdateModules mn update project
	= seq [(PR_UpdateModule m update) \\ m <- mn] project	// DvA quick hack, not very efficient!

//
//	Operations on tables
//

UpdateList :: !String InfUpdate !InfList -> (!InfList,!Bool)
UpdateList key update list = UpdateList2 key update list Nil
where
	UpdateList2 :: !String InfUpdate !InfList !InfList -> (!InfList,!Bool)
	UpdateList2 key update Nil acc
		=  (Reverse2 acc Nil,True)
	UpdateList2 key update ((first=:{mn,info}):!rest) acc
		| mn <> key
			= UpdateList2 key update rest (first:!acc)
		# (first,changed)	= update first
		= (Reverse2 acc (first :! rest), changed)

FindInList	:: !String !InfList -> !Maybe InfListItem
FindInList key Nil									= Nothing
FindInList key ((itm=:{mn,info}):!rest)	| mn <> key	= FindInList key rest
													= Just itm

//--

SetProject :: !{#Char} !{#Char} !ProjectGlobalOptions -> Project
SetProject applicationDir projectDir
		{ pg_built
		, pg_codegen
		, pg_application
		, pg_projectOptions
		, pg_projectPaths, pg_link, pg_mainModuleInfo={name, info},pg_otherModules
		, pg_target
		, pg_staticLibInfo
		, pg_execpath
		, pg_static
		, pg_dynamic
		}
	#! paths		= ExpandPaths applicationDir projectDir  pg_projectPaths
	#! linkOptions	= ExpandLinkOptionsPaths applicationDir projectDir pg_link
	#! project		= PR_AddRootModule pg_built pg_codegen pg_application pg_projectOptions paths linkOptions name (ExpandModuleInfoPaths applicationDir projectDir info)
	#! project		= addModules pg_otherModules project
	#! staticLibInfo = ExpandStaticLibPaths applicationDir projectDir pg_staticLibInfo
	#! project		= PR_SetStaticLibsInfo staticLibInfo project
	#! project		= PR_SetTarget pg_target project
	#! exepath		= ExpandPath applicationDir projectDir pg_execpath
	#! project		= PR_SetExecPath exepath project
	// default van gebruikte appopts in exe zijn ok klopt niet :-(
	#! pg_static = FixStatic applicationDir projectDir pg_static
	#! project		= {project & static_info = pg_static, dynamic_info = pg_dynamic}
	= project
where
	addModules Nil project
		=	project
	addModules ({name, info} :! t) project
		=	addModules t (PR_AddModule name (ExpandModuleInfoPaths applicationDir projectDir info) project)

FixStatic ap pp si=:{stat_mods,stat_objs,stat_slibs,stat_dlibs,stat_paths} =
	{ si
	& stat_mods		= ExpandPaths ap pp stat_mods
	, stat_objs		= ExpandPaths ap pp stat_objs
	, stat_slibs	= ExpandPaths ap pp stat_slibs
	, stat_dlibs	= ExpandPaths ap pp stat_dlibs
	, stat_paths	= ExpandPaths ap pp stat_paths
	}
GetProject :: !{#Char} !{#Char} !Project -> ProjectGlobalOptions
GetProject applicationDir projectDir project`
	=	{	pg_built			= PR_Built project
		,	pg_codegen			= PR_GetCodeGenOptions project
		,	pg_application		= PR_GetApplicationOptions project
		,	pg_projectOptions	= PR_GetProjectOptions project
		,	pg_projectPaths		= projectPaths
		,	pg_link				= linkOptions
		,	pg_mainModuleInfo	= mainModuleInfo
		,	pg_otherModules		= otherModules
		,	pg_staticLibInfo	= staticLibInfo
		,	pg_target			= target
		,	pg_execpath			= exepath
		, pg_static = project.static_info
		, pg_dynamic = project.dynamic_info
		}
where
	exepath
		# xp	= PR_GetExecPath project
		# xp	= replace_prefix_path applicationDir "{Application}" xp
		# xp	= replace_prefix_path projectDir "{Project}" xp
		= xp
	mainModuleInfo		=	getModule mainModuleName
	(mainModuleName,project)		=	PR_GetRootModuleName project`
	otherModuleNames	=	Filter ((<>) mainModuleName) (PR_GetModulenames False IclMod project)
	otherModules		=	Map getModule otherModuleNames
	getModule name	
		# info = PR_GetModuleInfo name project
		# info = if (isJust info) (fromJust info) defaultModInfo
		# info = SubstituteModuleInfoPaths applicationDir projectDir info
		= {name = name, info = info}
	linkOptions			=	SubstituteLinkOptionsPaths applicationDir projectDir (PR_GetLinkOptions project)
	projectPaths		=	SubstitutePaths applicationDir projectDir  (PR_GetPaths project)
	staticLibInfo		=	SubstituteStaticLibPaths applicationDir projectDir (PR_GetStaticLibsInfo project)
	target				=	PR_GetTarget project

	defaultModInfo :: ModInfo
	defaultModInfo	=
		{ dir		= EmptyPathname
		, compilerOptions		= DefaultCompilerOptions
		, defeo 	= {eo=DefaultEditOptions,pos_size=DefWindowPos_and_Size}
		, impeo	= {eo=DefaultEditOptions,pos_size=DefWindowPos_and_Size}
		, defopen = False
		, impopen = False
		, date	= NoDate
		, abcLinkInfo = {linkObjFileNames = Nil, linkLibraryNames = Nil} 
		}
	where
		DefaultEditOptions =
			{ tabs = 4
			, fontname = "Courier New"	//NonProportionalFontDef.fName
			, fontsize = 10				//NonProportionalFontDef.fSize
			, autoi = True
			, newlines = HostNativeNewlineConvention
			, showtabs = False
			, showlins = False
			, showsync = True
			} 
//import StdPicture
//--

ExpandModuleInfoPaths :: {#Char} {#Char} ModInfo -> ModInfo
ExpandModuleInfoPaths applicationDir projectDir moduleInfo=:{dir}
	= {moduleInfo & dir = ExpandPath applicationDir projectDir dir}

ExpandLinkOptionsPaths :: {#Char} {#Char} LinkOptions -> LinkOptions
ExpandLinkOptionsPaths applicationDir projectDir linkOptions=:{extraObjectModules, libraries}
	=	{ linkOptions
		& extraObjectModules	= ExpandPaths applicationDir projectDir extraObjectModules
		, libraries				= ExpandPaths applicationDir projectDir libraries
		}

ExpandStaticLibPaths :: {#Char} {#Char} StaticLibInfo -> StaticLibInfo
ExpandStaticLibPaths applicationDir projectDir staticLibs=:{sLibs}
	=	{ staticLibs
		& sLibs = ExpandPaths applicationDir projectDir sLibs
		}

ExpandPaths :: {#Char} {#Char} (List {#Char}) -> List {#Char}
ExpandPaths applicationDir projectDir list
	=	Map (ExpandPath applicationDir projectDir) list

ExpandPath applicationDir projectDir path
	= replace_prefix_path "{Application}" applicationDir (replace_prefix_path "{Project}" projectDir path)

SubstituteModuleInfoPaths :: {#Char} {#Char} ModInfo -> ModInfo
SubstituteModuleInfoPaths applicationDir projectDir info
	=	{info & dir = SubstitutePath applicationDir projectDir info.dir}

SubstituteLinkOptionsPaths :: {#Char} {#Char} LinkOptions -> LinkOptions
SubstituteLinkOptionsPaths applicationDir projectDir linkOptions=:{extraObjectModules, libraries}
	=	{linkOptions
		& extraObjectModules = SubstitutePaths applicationDir projectDir extraObjectModules
		, libraries = SubstitutePaths applicationDir projectDir libraries
		}

SubstituteStaticLibPaths :: {#Char} {#Char} StaticLibInfo -> StaticLibInfo
SubstituteStaticLibPaths applicationDir projectDir staticLibs=:{sLibs}
	=	{ staticLibs
		& sLibs = SubstitutePaths applicationDir projectDir sLibs
		}

SubstitutePaths :: {#Char} {#Char} (List {#Char}) -> List {#Char}
SubstitutePaths applicationDir projectDir list
	=	Map (SubstitutePath applicationDir projectDir) list

SubstitutePath applicationDir projectDir path
	= replace_prefix_path applicationDir "{Application}" (replace_prefix_path projectDir "{Project}" path)

//---

PR_GetABCLinkInfo	:: !Project -> !ABCLinkInfo;
PR_GetABCLinkInfo project=:{inflist}
	#	allLinkInfoRecords	= map (\{InfListItem | info={abcLinkInfo}} -> abcLinkInfo) (StrictListToList inflist);
		oneLinkInfoRecord	= foldl mergeTwoRecords emptyRecord allLinkInfoRecords;
	= oneLinkInfoRecord;
where
		mergeTwoRecords { linkObjFileNames=linkObjFileNames1, linkLibraryNames=linkLibraryNames1}
						{ linkObjFileNames=linkObjFileNames2, linkLibraryNames=linkLibraryNames2}
			= { linkObjFileNames	= UnionStringList linkObjFileNames2 linkObjFileNames1,
				linkLibraryNames	= UnionStringList linkLibraryNames2 linkLibraryNames1};
		emptyRecord
			= { linkObjFileNames = Nil, linkLibraryNames	= Nil};

/*
PR_GetABCLinkPathsCache	::	!Project -> ABCLinkPathsCache;
PR_GetABCLinkPathsCache {abcLinkPathsCache}
	= abcLinkPathsCache;

PR_SetABCLinkPathsCache	::	!ABCLinkPathsCache !Project -> Project;
PR_SetABCLinkPathsCache abcLinkPathsCache project
	= { project & abcLinkPathsCache=abcLinkPathsCache };
*/

//---

PR_GetStaticLibsInfo :: !Project -> !StaticLibInfo
PR_GetStaticLibsInfo {Project | staticLibInfo} = staticLibInfo

PR_SetStaticLibsInfo :: !StaticLibInfo !Project -> Project
PR_SetStaticLibsInfo staticLibInfo project
	= {Project | project & staticLibInfo = staticLibInfo}

PR_GetTarget :: !Project -> !String
PR_GetTarget {Project | target} = target

PR_SetTarget :: !String !Project -> Project
PR_SetTarget target project = {Project | project & target = target}

isLibraryModule :: !.String !.StaticLibInfo -> Bool;
isLibraryModule mod info
	= StringOccurs mod info.sDcls//ObjectIOInfo.sDcls	//info.sDcls

addLibraryDeps :: !.Modulename !(List .Modulename) !.StaticLibInfo -> List Modulename;
addLibraryDeps mod paths info
	= Concat paths info.sDeps//ObjectIOInfo.sDeps	//info.sDeps

//--

SL_Add :: !String /*Pathname*/ !StaticLibInfo -> StaticLibInfo
SL_Add pathname sl
	// enne sDcls en sDeps info binnen halen...
	// eoa libdef bestand binnenhalen en uitlezen...
	= {sl & sLibs = Append sl.sLibs pathname}

SL_Rem :: ![String /*Pathname*/] !String /*Pathname*/ !String /*Pathname*/ !StaticLibInfo -> StaticLibInfo
SL_Rem pathsel ap pp sl
	// enne weer sDcls en sDeps verwijderen...
	= {sl & sLibs = seq
		[ RemoveStringFromList (
			(replace_prefix_path "{Project}" pp) (
			(replace_prefix_path "{Application}" ap s)))
		\\ s <- pathsel
		] sl.sLibs}

SL_Libs :: !StaticLibInfo -> List String /*Pathname*/
SL_Libs sl=:{sLibs} = sLibs

SL_Dcls :: !StaticLibInfo -> List String /*Pathname*/
SL_Dcls sl=:{sDcls} = sDcls

SL_Deps :: !StaticLibInfo -> List String /*Pathname*/
SL_Deps sl=:{sDeps} = sDeps

SL_SetLibs :: !(List String /*Pathname*/) !StaticLibInfo -> StaticLibInfo
SL_SetLibs lp sl = {sl & sLibs = lp}

SL_SetDcls :: !(List String /*Pathname*/) !StaticLibInfo -> StaticLibInfo
SL_SetDcls lp sl = {sl & sDcls = lp}

SL_SetDeps :: !(List String /*Pathname*/) !StaticLibInfo -> StaticLibInfo
SL_SetDeps lp sl = {sl & sDeps = lp}

//--
//:: LDCInfo =
/*
StdEnvInfo :: StaticLibInfo
StdEnvInfo =
	{ sLibs = Nil
	, sDcls =
				( "StdEnv"
				:! "StdInt"
				:! "StdClass"
				:! "StdMisc"
				:! "StdEnum"
				:! "StdInt"
				:! "StdChar"
				:! "StdBool"
				:! "StdArray"
				:! "StdString"
				:! "StdReal"
				:! "StdOverloaded"
				:! "StdFunc"
				:! "StdCharList"
				:! "StdTuple"
				:! "StdOrdList"
				:! "StdList"
				:! "StdFile"
				:! "_SystemArray"
				:! "_SystemEnum"
				:! Nil
				)
	, sDeps = Nil
	}

ObjectIOInfo :: StaticLibInfo
ObjectIOInfo =
	{ sLibs = Nil
	, sDcls =	(	"StdId"
				:!	"StdIOBasic"
				:!	"StdIOCommon"
				:!	"StdMaybe"
				:!	"StdPSt"
				:!	"StdSystem"
						
				:!	"StdFileSelect"
						
				:!	"StdPictureDef"
				:!	"StdPicture"
				:!	"StdBitmap"
						
				:!	"StdProcessDef"
				:!	"StdProcess"
						
				:!	"StdClipboard"
						
				:!	"StdControlDef"
				:!	"StdControlAttribute"
				:!	"StdControlClass"
				:!	"StdControlReceiver"
				:!	"StdControl"
						
				:!	"StdMenuDef"
				:!	"StdMenuAttribute"
				:!	"StdMenuElementClass"
				:!	"StdMenuReceiver"
				:!	"StdMenuElement"
				:!	"StdMenu"
						
				:!	"StdReceiverDef"
				:!	"StdReceiver"
						
				:!	"StdTimerDef"
				:!	"StdTimerElementClass"
				:!	"StdTimerReceiver"
				:!	"StdTimer"
				:!	"StdTime"
						
				:!	"StdWindowDef"
				:!	"StdWindowAttribute"
				:!	"StdWindow"
					
				:! "StdSound"
				:! "id"
				:! "iostate"
				:! "key"
				:! "osfont"
				:! "ospicture"
				:! "osbitmap"
				:! "windowhandle"
				:! "menuhandle"
				:! "timerhandle"
					
				:! "devicesystemstate"
				:! "systemid"
				:! "receivertable"
				:! "timertable"
				:! "processstack"
				:! "osevent"
				:! "ostoolbox"
				:! "osguishare"
				:! "osactivaterequests"
				:! "oswindow"
				:! "ostime"
				:! "roundrobin"
				:! "osdocumentinterface"
				:! "intrface"
				:! "osrgn"
				:! "commondef"
				:! "keyfocus"
				:! "receiverhandle"
				:! "osmenu"
				:! "device"
				:! "ostypes"
				:! "receivermessage"
				:! Nil
				)
	, sDeps = ("StdEnv.dcl" :! Nil)
	}
*/
//--
import UtilOptions, PmFiles

/* MPM */
UpdatePDIProjectFile :: .ProjectDynamicInfo {#.Char} {#.Char} *a -> *((.Bool,{#Char}),*a) | FileSystem a;
UpdatePDIProjectFile pdi projectPath applicationDir ps
	// Read project
	#	(opened, file, ps)		= fopen projectPath FWriteData ps
		emptyProject			= PR_InitProject
		projectName				= RemovePath projectPath
		projectDir				= RemoveFilename projectPath
	| not opened
		#	(_, ps)				= fclose file ps
		= ((False,"The file \"" +++  projectName +++ "\" could not be opened."),ps)
	#	(version, file)			= ReadVersion file
	| version == ""
		#	(_, ps)				= fclose file ps
		=	((False,"The file \"" +++  projectName +++ "\" is an old project and could not be opened."),ps)
	#!	(options, file)			= ReadOptionsFile file
		projectGO				= GetProject applicationDir projectDir emptyProject
		project					= GetOptions ProjectTable options projectGO
		project					= (if (version == "1.3")
									(\p->{p&pg_target="StdEnv"})
									(id)
								) project	// DvA: need to set needs save flag for project;
/*
Mooier is om ipv bovenstaande een dialoogje te laten zien met popupje met mogelijke environments.
Plus button om in htmlHelp in relevante sectie over environments te komen.
*/
		project					= SetProject applicationDir projectDir project
		execpath				= PR_GetExecPath project
		(rootpath,project)		= PR_GetRootPathName project
		project					= PR_SetExecPath (if (execpath=="") (MakeExecPathname rootpath) execpath) project
		
	// Update project
	#! project
		= setDynamicInfo pdi project;
	#! (_,file)
		= fseek file 0 FSeekSet;
		
	// Save project
	#! projectDir			  	=	RemoveFilename projectPath
	#! projectGO				=	GetProject applicationDir projectDir project
	#! options				  	=	PutOptions ProjectTable projectGO
	#! file						=	WriteOptionsFile ProjectFileVersion options file
	#! (_,ps)
			=	fclose file ps;

	= ((True,""),ps);

SaveProjectFile	:: !String /*Pathname*/ !Project !String /*Pathname*/ !*Files -> (!Bool, !*Files);
SaveProjectFile	projectPath project applicationDir files
	#! (opened, file, files)		=	fopen projectPath FWriteText files
	| not opened
		=	(False, files)
	#! projectDir			  	=	RemoveFilename projectPath
	#! projectGO				=	GetProject applicationDir projectDir project
	#! options				  	=	PutOptions ProjectTable projectGO
	#! file						=	WriteOptionsFile ProjectFileVersion options file
	=	fclose file files

//import DebugUtilities;

ReadProjectFile	:: !String /*Pathname*/ !String /*Pathname*/ !*Files -> ((!Project, !Bool, !{#Char}),!*Files)
ReadProjectFile projectPath applicationDir ps
//	| F "ReadProjectFile" True
	#	(opened, file, ps)		= fopen projectPath FReadData ps
		emptyProject			= PR_InitProject
		projectName				= RemovePath projectPath
		projectDir				= RemoveFilename projectPath
	| not opened
		= ((emptyProject,False,"The file \"" +++  projectName +++ "\" could not be opened."),ps)
	#	(version, file)			= ReadVersion file
	| version == ""
		#	(_, ps)				= fclose file ps
		=	((emptyProject,False,"The file \"" +++  projectName +++ "\" is an old project and could not be opened."),ps)
	#!	(options, file)			= ReadOptionsFile file
		projectGO				= GetProject applicationDir projectDir emptyProject
		project					= GetOptions ProjectTable options projectGO
		project					= (if (version == "1.3")
									(\p->{p&pg_target="StdEnv"})
									(id)
								) project	// DvA: need to set needs save flag for project;
/*
Mooier is om ipv bovenstaande een dialoogje te laten zien met popupje met mogelijke environments.
Plus button om in htmlHelp in relevante sectie over environments te komen.
*/
		project					= SetProject applicationDir projectDir project
		execpath				= PR_GetExecPath project
		(rootpath,project)		= PR_GetRootPathName project
		project					= PR_SetExecPath (if (execpath=="") (MakeExecPathname rootpath) execpath) project
		(closed, ps)			= fclose file ps
	| not closed
		=	((project, True,"The file \"" +++ projectName +++ "\" clould not be closed."), ps)	// warning genereren of zo?
	=	((project, True,""), ps)

getStaticInfo :: !Project -> (ProjectStaticInfo,Project)
getStaticInfo prj=:{static_info} = (static_info,prj)

setStaticInfo :: !.ProjectStaticInfo !.Project -> .Project
setStaticInfo inf prj = {prj & static_info = inf}

getDynamicInfo :: !Project -> (ProjectDynamicInfo,Project)
getDynamicInfo prj=:{dynamic_info} = (dynamic_info,prj)

setDynamicInfo :: !.ProjectDynamicInfo !.Project -> .Project
setDynamicInfo inf prj = {prj & dynamic_info = inf}
