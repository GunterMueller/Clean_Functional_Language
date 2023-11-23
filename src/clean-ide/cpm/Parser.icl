implementation module Parser;

import StdEnv;
import StdMaybe;
import AbsSyn;
from PmEnvironment import EnvsFileName;
from PmTypes import :: Output(..);

parseCpmLogic :: ![String] -> CpmAction;
parseCpmLogic [_:args] = parse_CpmLogic args;
parseCpmLogic _ = CpmHelp;

parse_CpmLogic :: ![String] -> CpmAction;
parse_CpmLogic ["make"] = CpmMake;
parse_CpmLogic ["project",project_name:project_args] = parse_Project project_args project_name;
parse_CpmLogic ["module",module_name:module_args] = parse_Module module_args module_name;
parse_CpmLogic ["environment":environment_args] = parse_Environment environment_args;
parse_CpmLogic [project_name:project_build_args] = parse_Project_build_args project_build_args False EnvsFileName project_name CpmHelp;
parse_CpmLogic _ = CpmHelp;

parse_Project :: ![String] !String -> CpmAction;
parse_Project ["create"] project_name = Project project_name (CreateProject Nothing);
parse_Project ["create",s] project_name = Project project_name (CreateProject (Just s));
parse_Project ["show"] project_name = Project project_name ShowProject;
parse_Project ["build":project_build_args] project_name
	= parse_Project_build_args project_build_args False EnvsFileName project_name (Project "" ProjectHelp);
parse_Project ["compile":s] project_name
	| length s <> 0 = Project project_name (Compile s);
parse_Project ["path":project_path_args] project_name = parse_Project_path_args project_path_args project_name;
parse_Project ["root",s] project_name
	| size s > 0 && and [c == '.'\\ c<-:s]
		= Project project_name (SetRelativeRoot s);
parse_Project ["target",s] project_name = Project project_name (SetTarget s);
parse_Project ["exec",s] project_name = Project project_name (SetExec s);
parse_Project ["bytecode",s] project_name = Project project_name (SetBytecode (Just s));
parse_Project ["bytecode"] project_name = Project project_name (SetBytecode Nothing);
parse_Project ["template",s] project_name = Project project_name (ExportTemplate s);
parse_Project ["set":project_option_args] project_name
	# (ok,project_options) = parse_Project_options project_option_args;
	| ok
		= Project project_name (SetProjectOptions project_options);
		= Project "" ProjectHelp;
parse_Project _ project_name = Project "" ProjectHelp;

parse_Project_build_args :: ![String] !Bool !String !String !CpmAction -> CpmAction;
parse_Project_build_args ["--force":project_build_args] force environment project_name error_cpm_action
	= parse_Project_build_args project_build_args True environment project_name error_cpm_action;
parse_Project_build_args [project_build_arg:project_build_args] force environment project_name error_cpm_action
	| size project_build_arg>6 && project_build_arg % (0,5)=="--env="
		# environment = project_build_arg % (6,size project_build_arg-1);
		= parse_Project_build_args project_build_args force environment project_name error_cpm_action;
parse_Project_build_args [] force environment project_name error_cpm_action
	= Project project_name (BuildProject force environment);
parse_Project_build_args _ _ _ _ error_cpm_action
	= error_cpm_action;

parse_Project_path_args :: ![String] !String -> CpmAction;
parse_Project_path_args ["add":path] project_name
	| length path <> 0 = Project project_name (ProjectPath (AddPathAction path));
parse_Project_path_args ["remove",i] project_name
	| size i>0 && only_digits_in_string 0 i
		= Project project_name (ProjectPath (RemovePathAction (toInt i)));
parse_Project_path_args ["list"] project_name
	= Project project_name (ProjectPath ListPathsAction);
parse_Project_path_args ["move",i,direction_name] project_name
	# (is_direction,direction) = parse_PathDirection direction_name;
	| size i>0 && only_digits_in_string 0 i && is_direction
		= Project project_name (ProjectPath (MovePathAction (toInt i) direction));
parse_Project_path_args _ project_name
	= Project project_name (ProjectPath PathHelp);

parse_PathDirection :: !String -> (!Bool,PathDirection);
parse_PathDirection "up" = (True,MovePathUp);
parse_PathDirection "down" = (True,MovePathDown);
parse_PathDirection "top" = (True,MovePathTop);
parse_PathDirection "bottom" = (True,MovePathBottom);
parse_PathDirection _ = (False,abort "parse_PathDirection");

only_digits_in_string :: !Int !String -> Bool;
only_digits_in_string i s
	| i<size s
		= isDigit s.[i] && only_digits_in_string (i+1) s;
		= True;

parse_Project_options :: ![String] -> (!Bool,![ProjectOption]);
parse_Project_options ["-dynamics":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok,[DynamicsOn:project_options]);
parse_Project_options ["-ndynamics":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok,[DynamicsOff:project_options]);
parse_Project_options ["-generic_fusion":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok,[GenericFusionOn:project_options]);
parse_Project_options ["-ngeneric_fusion":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok,[GenericFusionOff:project_options]);
parse_Project_options ["-descexl":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok,[DescExLOn:project_options]);
parse_Project_options ["-ndescexl":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok,[DescExLOff:project_options]);
parse_Project_options ["-h",heap_size:project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	# heap_size = parseByteSuffix heap_size;
	| heap_size > 0
		= (ok,[HeapSize heap_size:project_options]);
parse_Project_options ["-s",stack_size:project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	# stack_size = parseByteSuffix stack_size;
	| stack_size > 0
		= (ok,[StackSize stack_size:project_options]);
parse_Project_options ["-b":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [Output BasicValuesOnly:project_options]);
parse_Project_options ["-sc":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [Output ShowConstructors:project_options]);
parse_Project_options ["-nr":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [Output NoReturnType:project_options]);
parse_Project_options ["-nc":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [Output NoConsole:project_options]);
parse_Project_options ["-nstrip":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [LinkerGenerateSymbolsOn:project_options]);
parse_Project_options ["-strip":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [LinkerGenerateSymbolsOff:project_options]);
parse_Project_options ["-nrtsopts":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [RTSFlagsOff:project_options]);
parse_Project_options ["-rtsopts":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [RTSFlagsOn:project_options]);
parse_Project_options ["-pt":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [TimeProfileOn:project_options]);
parse_Project_options ["-npt":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [TimeProfileOff:project_options]);
parse_Project_options ["-pg":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [CallgraphProfileOn:project_options]);
parse_Project_options ["-npg":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [CallgraphProfileOff:project_options]);
parse_Project_options ["-tst":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [StackTraceOn:project_options]);
parse_Project_options ["-ntst":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [StackTraceOff:project_options]);
parse_Project_options ["-mp":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [MemoryProfileOn:project_options]);
parse_Project_options ["-nmp":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [MemoryProfileOff:project_options]);
parse_Project_options ["-optimiseabc":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [PO_OptimiseABC True:project_options]);
parse_Project_options ["-noptimiseabc":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [PO_OptimiseABC False:project_options]);
parse_Project_options ["-genbytecode":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [PO_GenerateByteCode True:project_options]);
parse_Project_options ["-ngenbytecode":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [PO_GenerateByteCode False:project_options]);
parse_Project_options ["-stripbytecode":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [PO_StripByteCode True:project_options]);
parse_Project_options ["-nstripbytecode":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [PO_StripByteCode False:project_options]);
parse_Project_options ["-keepbytecodesymbols":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [PO_KeepByteCodeSymbols True:project_options]);
parse_Project_options ["-nkeepbytecodesymbols":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [PO_KeepByteCodeSymbols False:project_options]);
parse_Project_options ["-prelinkbytecode":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [PO_PreLinkByteCode True:project_options]);
parse_Project_options ["-nprelinkbytecode":project_option_args]
	# (ok,project_options) = parse_Project_options project_option_args;
	= (ok, [PO_PreLinkByteCode False:project_options]);
parse_Project_options []
	= (True,[]);
parse_Project_options _
	= (False,[]);

parseByteSuffix :: !String -> Int;
parseByteSuffix s
	| size s == 0
		= 0;
	# suffix = s.[dec (size s)];
	| suffix == 'k' || suffix == 'K'
		= 1024 * safeToInt (s % (0, size s - 2));
	| suffix == 'm' || suffix == 'M'
		= 1024 * 1024 * safeToInt (s % (0, size s - 2));
		= safeToInt s;

safeToInt :: !String -> Int;
safeToInt s
	| only_digits_in_string 0 s
		= toInt s;
		= 0;

parse_Module :: ![String] !String -> CpmAction;
parse_Module ["create"] module_name = Module module_name (CreateModule LibraryModule);
parse_Module ["create","application"] module_name = Module module_name (CreateModule ApplicationModule);
parse_Module _ module_name = Module "" ModuleHelp;

parse_Environment :: ![String] -> CpmAction;
parse_Environment ["list"] = Environment ListEnvironments;
parse_Environment ["import",s] = Environment (ImportEnvironment s);
parse_Environment ["create",s] = Environment (CreateEnvironment s Nothing);
parse_Environment ["create",s,s2] = Environment (CreateEnvironment s (Just s2));
parse_Environment ["remove",s] = Environment (RemoveEnvironment s);
parse_Environment ["show",s] = Environment (ShowEnvironment s);
parse_Environment ["export",s1,s2] = Environment (ExportEnvironment s1 s2);
parse_Environment ["rename",s1,s2] = Environment (RenameEnvironment s1 s2);
parse_Environment ["setcompiler",s1,s2] = Environment (SetEnvironmentCompiler s1 s2);
parse_Environment ["setcodegen",s1,s2] = Environment (SetEnvironmentCodeGen s1 s2);
parse_Environment _ = Environment EnvironmentHelp;
