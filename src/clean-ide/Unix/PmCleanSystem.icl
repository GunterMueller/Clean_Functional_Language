implementation module PmCleanSystem

import StdEnv,StdMisc,StdMaybe
from Directory import pd_StringToPath,getFileInfo,createDirectory,::Path,::FileInfo{pi_fileInfo},::PI_FileInfo{isDirectory},::DirError(..)
import UtilStrictLists
from Platform import DirSeparatorString,IF_MACOSX,IF_ARM
import StdPathname
import PmTypes
from PmCompilerOptions import ::CompilerOptions(..),::ListTypes(..),instance == ListTypes
from PmPath import ModuleDirAndNameToABCSystemPathname,ModuleDirAndNameToObjSystemPathname
import PmCallBack
from PmParse import IsTypeSpec,IsImportError20
from linkargs import ReadLinkErrors,WriteLinkOpts,:: LinkInfo`(..),:: LPathname

from Platform import TempDir
tooltempdir =: TempDir

:: CompileOrCheckSyntax = SyntaxCheck | Compilation

:: CompilePollCompletedResult = NoFinishedCompiler | UnknownFinishedCompiler | FinishedCompiler !Int !Int
:: CodeGenerateAsmOrCode = AsmGeneration | CodeGeneration

:: CompilingInfo = NoCompiler | CompilerProcess !CompilerProcess

:: CompilerProcess = {
	commands_file_name :: !{#Char},
	results_file_name :: !{#Char},
	compiler_pid :: !Int,
	commands_fd :: !Int,
	results_fd :: !Int
  }

:: CompilerProcessIds :== [CompilerProcess]

::	CompilerMsg
	= 	CompilerOK
	| 	SyntaxError
	| 	Patherror Pathname

::	WindowFun env :== ([String]) -> env -> env

instance == CompileOrCheckSyntax where
	(==) SyntaxCheck SyntaxCheck = True
	(==) SyntaxCheck _ = False
	(==) Compilation Compilation = True
	(==) Compilation _ = False

instance == CodeGenerateAsmOrCode where
	(==) CodeGeneration CodeGeneration = True
	(==) AsmGeneration AsmGeneration = True
	(==) _ _ = False

NoCompilerProcessIds :: CompilerProcessIds
NoCompilerProcessIds = []

standardStaticLibraries :: !Processor !LinkMethod -> List String
standardStaticLibraries _ method
	= Nil

standardObjectFiles :: !Bool !Bool !Bool !Processor !Bool -> List String
standardObjectFiles stack_traces callgraph_profiling profiling _ use_64_bit_processor
	#! startup_file = if stack_traces "_startupTrace.o"
					  (if callgraph_profiling "_startupProfileGraph.o"
					  (if profiling "_startupProfile.o" "_startup.o"))
	= (startup_file :! "_system.o" :! Nil)

getLibs :: ![String] !*Files -> (!(![String],![String]),!*Files)
getLibs [] files = (([],[]),files)
getLibs libs files = abort "getLibs\n"

InitCompilingInfo :: *CompilingInfo
InitCompilingInfo = NoCompiler

Compile :: !String !Bool !Bool !(WindowFun *env) !(WindowFun *env) !CompileOrCheckSyntax !ModuleDirAndName !Pathname
	!(List Pathname) !ProjectCompilerOptions !CompilerOptions !Pathname !CompilerProcessIds !*env
	-> (!Pathname,!CompilerMsg,!CompilerProcessIds,!*env)
	| FileEnv env
Compile
	cocl use_compiler_process_ids write_module_times errwin typewin compileOrCheckSyntax mdn path paths project_compiler_options
	co=:{CompilerOptions | listTypes}
	startupdir compiler_process_ids env
	# (cocl,cocl_dir,options1,options2) = get_path_name_and_options2 cocl startupdir

	# temp_dir = temp_dir_path startupdir
	  out_file_name = out_file_path temp_dir 0
	  errors_file_name = errors_file_path temp_dir 0

	# cocl_arguments = compiler_arguments out_file_name errors_file_name compileOrCheckSyntax path paths write_module_times project_compiler_options co
	  cocl_arguments = add_options_string_to_args 0 options2 cocl_arguments
	  cocl_arguments = add_options_string_to_args 0 options1 cocl_arguments

	# (argv,args_memory) = make_argv [cocl:cocl_arguments]

	# compiler_pid = fork
	| compiler_pid<0
		= abort "fork failed\n"
	| compiler_pid==0
		| execv (cocl+++"\0") argv<0
			= abort "execv failed\n"
			= abort "execution continued after execv\n"
	| free args_memory<0
		= abort "free failed\n"
	# (w_pid,status) = wait_pid compiler_pid 0
	| w_pid <> -1 && w_pid<>compiler_pid
		= abort "waitpid failed\n"
	# result = (status bitand 0xff00) >> 8
	# wtermsig = status bitand 0x7f
	| wtermsig<>0
		= abort "compiler exited abnormally\n"


	# exitcode = if (result==0) 0 1

	# dummy_slot = 0
	# (path,mess,env) =	CompileHandleExitCode exitcode cocl startupdir dummy_slot errwin typewin mdn listTypes env
	= (path,mess,compiler_process_ids,env)

CompilePersistent ::
	!String !Bool !(WindowFun *env) !(WindowFun *env) !CompileOrCheckSyntax !ModuleDirAndName
	!(List Pathname) !ProjectCompilerOptions !CompilerOptions !Pathname !*CompilingInfo !*env
	-> (!*CompilingInfo,!(!*env, !Pathname, !CompilerMsg))
	| FileEnv env
CompilePersistent cocl write_module_times errwin typewin compileOrCheckSyntax mdn paths project_compiler_options
					co=:{CompilerOptions | listTypes}
					startupdir compiling_info env
	# (cocl,cocl_dir,options1,options2) = get_path_name_and_options2 cocl startupdir

	# (compiling_info=:CompilerProcess {commands_fd,results_fd})
		= start_compiler_if_not_yet_started cocl options1 compiling_info

	# temp_dir = temp_dir_path startupdir
	  out_file_name = out_file_path temp_dir 0
	  errors_file_name = errors_file_path temp_dir 0

	# args = makeCompilerOptionsArguments compileOrCheckSyntax write_module_times project_compiler_options co
	# args_string = concat_args args+++
		" "+++mdn.mdn_name+++
		" -P "+++"\""+++concatenate_paths paths+++"\""+++
		" -RE "+++"\""+++errors_file_name+++"\""+++
		" -RO "+++"\""+++out_file_name+++"\""
	# args_string = if (size options2==0) args_string (options2+++" "+++args_string)
	# args_string = "cocl "+++args_string+++"\n"
	  n_chars = size args_string
	# r = write commands_fd args_string n_chars
	| r<>n_chars
		= abort "write_failed\n"

	# result_string = createArray 6 '\0'
	# r = read results_fd result_string 6;
	| r<=1
		= abort ("read failed "+++toString r +++ "\n")

	# exitcode = parse_result_number 0 result_string

	# dummy_slot = 0
	# (path,mess,env) =	CompileHandleExitCode exitcode cocl startupdir dummy_slot errwin typewin mdn listTypes env
	= (compiling_info,(env,path,mess))

parse_result_number i result_string
	# c=result_string.[i]
	| c>='0' && c<='9'
		= parse_result_number2 (i+1) (toInt c-48) result_string
	| c=='-'
		= 0 - parse_result_number (i+1) result_string
		= abort "parse_result_number failed\n"
where
	parse_result_number2 i n result_string
		| i<size result_string
			# c=result_string.[i]
			| c>='0' && c<='9'
				= parse_result_number2 (i+1) (n*10+(toInt c-48)) result_string
			| c=='\n'
				= n
				= abort "parse_result_number2 failed\n"
			= abort "parse_result_number2 failed\n"

CompileStartCommand ::
	!String !Bool !(WindowFun *env) !CompileOrCheckSyntax !Pathname
	!(List Pathname) !Int !ProjectCompilerOptions !CompilerOptions !Pathname !CompilerProcessIds !*env
	-> (!Bool,!CompilerProcessIds,!*env)
	| FileEnv env
CompileStartCommand cocl write_module_times errwin compileOrCheckSyntax path
		paths slot project_compiler_options co startupdir compiler_process_ids ps
	# (cocl,cocl_dir,options1,options2) = get_path_name_and_options2 cocl startupdir

	# ({commands_fd,results_fd},compiler_process_ids)
		= start_a_compiler_if_not_yet_started cocl slot compiler_process_ids options1

	# temp_dir = temp_dir_path startupdir
	  out_file_name = out_file_path temp_dir slot
	  errors_file_name = errors_file_path temp_dir slot

	# args = makeCompilerOptionsArguments compileOrCheckSyntax write_module_times project_compiler_options co
	# args_string = concat_args args+++
		" "+++path+++
		" -P "+++concatenate_paths paths+++
		" -RE "+++errors_file_name+++
		" -RO "+++out_file_name
	# args_string = if (size options2==0) args_string (options2+++" "+++args_string)
	# args_string = "cocl "+++args_string+++"\n"
	  n_chars = size args_string
	# r = write commands_fd args_string n_chars
	| r<>n_chars
		= abort "write_failed\n"
	= (True,compiler_process_ids,ps)

exit_clean_compiler {compiler_pid,commands_fd,results_fd,commands_file_name,results_file_name} env
	# args_string = "quit\n"
	  n_chars = size args_string
	# r = write commands_fd args_string n_chars
	| r<>n_chars
		= abort "write_failed\n"
	# (w_pid,status) = wait_pid compiler_pid 0
	| w_pid <> -1 && w_pid<>compiler_pid
		= abort "waitpid failed\n"
	# result = (status bitand 0xff00) >> 8
	# wtermsig = status bitand 0x7f
	| wtermsig<>0
		= abort "compiler exited abnormally\n"
	# r=close commands_fd
	| r==(-1)
		= abort "close failed\n"
	# r=close results_fd
	| r==(-1)
		= abort "close failed\n"
	| unlink (commands_file_name+++"\0")<>0
		= abort "unlink failed\n"
	| unlink (results_file_name+++"\0")<>0
		= abort "unlink failed\n"
	= env

ExitCleanCompiler :: !*(!*CompilingInfo,*env) -> *(!*CompilingInfo,*env)
ExitCleanCompiler (NoCompiler,env)
	= (NoCompiler,env)
ExitCleanCompiler (CompilerProcess compiler,env)
	#! env = exit_clean_compiler compiler env
	= (NoCompiler,env)

QuitCleanCompiler :: !Bool !CompilerProcessIds !*World -> *World
QuitCleanCompiler async compiler_process_ids world
	| async
		= exit_compilers compiler_process_ids world
		= world
where
	exit_compilers [compiler:compilers] world
		= exit_compilers compilers (exit_clean_compiler compiler world)
	exit_compilers [] world
		= world

CodeGen	::	!String !Bool !(WindowFun *GeneralSt) !CodeGenerateAsmOrCode !Pathname !Pathname !Bool
			!CodeGenOptions !Processor !ApplicationOptions !Pathname !CompilerProcessIds !*GeneralSt
			-> (!Pathname,!Bool,!CompilerProcessIds,!*GeneralSt)
CodeGen cgen used_compiler_process_ids wf genAsmOrCode abc_path obj_path timeprofile cgo tp ao startupdir compiler_process_ids ps
	# (cgen,cgendir,options) = get_path_name_and_options cgen startupdir
	# path_without_suffix = RemoveSuffix abc_path
	# cg_arguments = make_code_generator_arguments genAsmOrCode cgo

	# temp_dir = temp_dir_path startupdir
	  errors_file_name = errors_file_path temp_dir 0
	# stderr_fd = creat (errors_file_name+++"\0") 0777;
	| stderr_fd== (-1)
		= abort "creat failed\n"

	# (argv,args_memory) = make_argv [cgen : add_options_string_to_args 0 options (cg_arguments++[path_without_suffix])]

	# code_generator_pid = fork
	| code_generator_pid<0
		= abort "fork failed\n"
	| code_generator_pid==0
		# r=dup2 stderr_fd 2
		| r== (-1)
			= abort "dup2 failed\n"
		| execv (cgen+++"\0") argv<0
			= abort "execv failed\n"
			= abort "execution continued after execv\n"
	| free args_memory<0
		= abort "free failed\n"

	# (w_pid,status) = wait_pid code_generator_pid 0
	| w_pid <> -1 && w_pid<>code_generator_pid
		= abort "waitpid failed\n"
	# result = (status bitand 0xff00) >> 8
	# wtermsig = status bitand 0x7f
	| wtermsig<>0
		= abort "code generator exited abnormally\n"

	# r=close stderr_fd
	| r==(-1)
		= abort "close failed\n"

	# exit_code = if (result==0) 0 1

	# ((_, errors_not_empty, error_text),ps) = accFiles (readErrorsAndWarnings errors_file_name) ps
	  ps = if errors_not_empty
				(wf (StrictListToList error_text) ps)
				(if (exit_code <> 0)
					(wf ["Error: Code generator failed for '"+++abc_path+++"' with exit code: "+++toString exit_code,(quoted_string path_without_suffix)] ps)
					ps
					)
	= (obj_path,exit_code==0,compiler_process_ids,ps)

:: StartedCodeGenerator = !{
	scg_abc_path :: !{#Char},
	scg_path_without_suffix :: !{#Char},
	scg_std_error_fd :: !Int,
	scg_errors_file_name :: !{#Char}
  }

start_code_generator ::	!String !(WindowFun *GeneralSt) !Pathname !Int !Bool !CodeGenOptions !Processor !Pathname !*GeneralSt
						-> (!Bool,!Int/*HANDLE*/,!StartedCodeGenerator,!*GeneralSt)
start_code_generator cgen wf path slot timeprofile cgo tp startupdir ps
	# (cgen,cgendir,options) = get_path_name_and_options cgen startupdir
	# path_without_suffix = RemoveSuffix path
	# cg_arguments = make_code_generator_arguments CodeGeneration cgo

	# temp_dir = temp_dir_path startupdir
	  errors_file_name = errors_file_path temp_dir slot
	# stderr_fd = creat (errors_file_name+++"\0") 0777;
	| stderr_fd== (-1)
		= abort "creat failed\n"

	# (argv,args_memory) = make_argv [cgen : add_options_string_to_args 0 options (cg_arguments++[path_without_suffix])]

	# code_generator_pid = fork
	| code_generator_pid<0
		= abort "fork failed\n"
	| code_generator_pid==0
		# r=dup2 stderr_fd 2
		| r== (-1)
			= abort "dup2 failed\n"
		| execv (cgen+++"\0") argv<0
			= abort "execv failed\n"
			= abort "execution continued after execv\n"
	| free args_memory<0
		= abort "free failed\n"
	# scg = {scg_abc_path=path,scg_path_without_suffix=path_without_suffix,
			 scg_std_error_fd=stderr_fd,scg_errors_file_name=errors_file_name}
	= (True,code_generator_pid,scg,ps)

wait_for_finished_code_generator :: !{#Int} !*GeneralSt -> (!Int,!Int,!*GeneralSt)
wait_for_finished_code_generator process_ids ps
	# (w_pid,status) = wait_pid -1 0
	| w_pid<0
		= abort "waitpid failed\n"
	# process_n = find_process_id_index 0 w_pid process_ids
	# result = (status bitand 0xff00) >> 8
	# wtermsig = status bitand 0x7f
	| wtermsig<>0
		= abort "code generator exited abnormally\n"
	= (process_n,result,ps)
where
	find_process_id_index i w_pid pids
		| i<size pids
			| pids.[i]==w_pid
				= i
				= find_process_id_index (i+1) w_pid pids

finish_code_generator :: !Int/*HANDLE*/ !StartedCodeGenerator !Int !(WindowFun *GeneralSt) !*GeneralSt -> (!Bool,!*GeneralSt)
finish_code_generator process_handle {scg_abc_path,scg_path_without_suffix,scg_std_error_fd,scg_errors_file_name} exit_code wf ps
	# r=close scg_std_error_fd
	| r==(-1)
		= abort "close failed\n"
	# ((_, errors_not_empty, error_text),ps) = accFiles (readErrorsAndWarnings scg_errors_file_name) ps
	  ps = if errors_not_empty
				(wf (StrictListToList error_text) ps)
				(if (exit_code <> 0)
					(wf ["Error: Code generator failed for '" +++ scg_abc_path +++ "' with exit code: "+++toString exit_code,(quoted_string scg_path_without_suffix)] ps)
					ps)
	= (exit_code==0, ps)

Link ::	!String !(WindowFun *GeneralSt) !Pathname !ApplicationOptions
		!Pathname !(List Pathname) !(List Pathname) !(List Pathname) !Bool !Bool !Bool !Bool !Bool !String
		!Bool !String !Pathname !String !Processor !Bool !*GeneralSt
		 -> (!*GeneralSt,!Bool)
Link linker winfun path
		applicationOptions=:{ss,hs,initial_heap_size,profiling,heap_size_multiple,o,memoryProfilingMinimumHeapSize=minheap}
		optionspathname library_file_names object_file_names static_libraries static gen_relocs gen_symbol_table gen_linkmap
		link_resources resource_path gen_dll dll_syms startupdir dynlstr _ use_64_bit_processor ps
	# (calling_convention,linker) = get_optional_calling_convention linker
	# (linker,linker_dir,options12) = get_path_name_and_options linker startupdir
	# (options1,options2) = splitOptions options12
	# flags = ApplicationOptionsToFlags applicationOptions
	  optdirpath = RemoveFilename optionspathname
	  ((ok,pd_optdirpath),ps) = pd_StringToPath optdirpath ps
	| not ok
		= (winfun ["Linker error: Unable to understand path: "+++optdirpath] ps,False)
	# ((err,{pi_fileInfo={isDirectory}}),ps) = getFileInfo pd_optdirpath ps
	  (err,ps) = if (case err of DoesntExist -> True; _ -> not isDirectory)
					(createDirectory pd_optdirpath ps)
					(err,ps)
	| case err of NoDirError -> False; _ -> True
		= (winfun ["Linker error: Unable to access or create: "+++optdirpath] ps,False)
	# (options_file_ok,ps) = accFiles (write_options_file optionspathname flags hs ss initial_heap_size heap_size_multiple minheap use_64_bit_processor) ps
	| not options_file_ok
		= (winfun ["Linker error: Could not write the options object file: "+++optionspathname] ps,False)
	# object_paths = [optionspathname : StrictListToList (RemoveDup object_file_names)]
	| size calling_convention==0
		# len = size linker
		| len >= 14 && linker % (len - 14, len) == "lib/exe/linker"
			= linkOptimizingGCC linker object_paths options1 options2 ps
		| len >= 12 && linker % (len - 12, len) == "/usr/bin/gcc"
			= linkGCC linker object_paths options2 ps
			= linkOther linker object_paths ps
	| calling_convention=="gcc"
		= linkGCC linker object_paths options2 ps
	| calling_convention=="linker"
		= linkOther linker object_paths ps
	| calling_convention=="linker+gcc"
		= linkOptimizingGCC linker object_paths options1 options2 ps
		= (winfun ["Linker error: Unknown calling convention : "+++calling_convention] ps,False)
where
	//First call the optimizing linker to generate an intermediate optimized object file which is then passed to gcc
	linkOptimizingGCC linker object_paths options1 options2 ps
		# temp_file_name = "/tmp/linkerXXXXXX" +++ "\0" // +++ because modified by mkstemp
		# fd = mkstemp temp_file_name
		| fd== -1
			= abort "mkstemp failed\n"
		# r = close fd
		| r== -1
			= abort "close failed\n"
		//Call optimized linker
		# linker_args = add_options_string_to_args 0 options1 [temp_file_name:object_paths]
		# (argv,args_memory) = make_argv [linker:linker_args]

		# linker_pid = fork
		| linker_pid<0
			= abort "fork failed\n"
		| linker_pid==0
			| execv (linker+++"\0") argv<0
				= abort "execv failed\n"
				= abort "execution continued after execv\n"
		# (w_pid,status) = wait_pid linker_pid 0
		| w_pid <> -1 && w_pid<>linker_pid
			= abort "waitpid failed\n"
		# exit_code = (status >> 8) bitand 0xff
		# wtermsig = status bitand 0x7f
		| wtermsig<>0
			= abort "linker exited abnormally\n"
		| free args_memory<0
			= abort "free failed\n"

		# link_ok = exit_code==0
		| not link_ok
			| unlink (temp_file_name+++"\0")<>0
				=  (ps,link_ok)
				=  (ps,link_ok)
		//Call gcc
		#! (ps, link_ok) = linkGCC "/usr/bin/gcc" [temp_file_name] options2 ps
		| unlink (temp_file_name+++"\0")<>0
			= (ps,link_ok)
			= (ps,link_ok)

	//Just link with gcc
	linkGCC gcc_file_name object_paths gccOptions ps
		# ld_args = add_options_string_to_args 0 gccOptions (StrictListToList (Append library_file_names "-lm"))
		# ld_args = ["-o", path : object_paths ] ++ ld_args
		  ld_args = IF_MACOSX ld_args (IF_INT_64_OR_32 ["-no-pie":ld_args] ["-m32","-no-pie":ld_args])
		  ld_args = if gen_symbol_table ld_args ["-s":ld_args]
		# (argv,args_memory) = make_argv [gcc_file_name:ld_args]
		# ld_pid = fork
		| ld_pid<0
			= abort "fork failed\n"
		| ld_pid==0
			| execv (gcc_file_name+++"\0") argv<0
				= abort "execv failed\n"
				= abort "execution continued after execv\n"
		| free args_memory<0
			= abort "free failed\n"
		# (w_pid,status) = wait_pid ld_pid 0
		| w_pid <> -1 && w_pid<>ld_pid
			= abort "waitpid failed\n"
		# wtermsig = status bitand 0x7f
		# exit_code = (status >> 8) bitand 0xff;
		| wtermsig<>0
			= abort "ld exited abnormally\n"
		# link_ok = exit_code==0
		= (ps,link_ok)

	//Call other/additional linker
	linkOther linker object_paths ps
		# linkopts  =
			{ exe_path                  = path
			, res_path                  = resource_path
			, open_console              = o <> NoConsole
			, static_link               = static
			, gen_relocs                = gen_relocs
			, gen_symbol_table          = gen_symbol_table
			, gen_linkmap               = gen_linkmap
			, link_resources            = link_resources
			, object_paths              = ListToStrictList object_paths
			, dynamic_libs              = RemoveDup library_file_names
			, static_libs               = RemoveDup static_libraries
			, stack_size                = ss
			, gen_dll                   = gen_dll
			, dll_names                 = dll_syms
			, dynamics_path             = startupdir +++. DirSeparatorString +++. dynlstr
			, lib_name_obj_path         = MakeFullPathname tooltempdir "lib_name.o"
			}
		# linkoptspath = MakeFullPathname tooltempdir "linkopts"
		# linkerrspath = MakeFullPathname tooltempdir "linkerrs"
		# (err,ps) = accFiles (WriteLinkOpts linkoptspath linkopts) ps
		| isJust err
			= (winfun (fromJust err) ps,False)
		# linker_args = ["-I",linkoptspath,"-O",linkerrspath]
		# (argv,args_memory) = make_argv [linker:linker_args]
		# linker_pid = fork
		| linker_pid<0
			= abort "fork failed\n"
		| linker_pid==0
			| execv (linker+++"\0") argv<0
				= abort "execv failed\n"
				= abort "execution continued after execv\n"
		# (w_pid,status) = wait_pid linker_pid 0
		| w_pid <> -1 && w_pid<>linker_pid
			= abort "waitpid failed\n"
		# exit_code = (status >> 8) bitand 0xff
		# wtermsig = status bitand 0x7f
		| wtermsig<>0
			= abort "linker exited abnormally\n"
		| free args_memory<0
			= abort "free failed\n"
		# link_ok = exit_code==0
		= (ps,link_ok)

DelayEventLoop :: !.ps -> .ps
DelayEventLoop ps
	= ps

POLLIN :== 1

CompilePollCompleted :: !CompilerProcessIds !*env -> (!CompilePollCompletedResult, !*env) | FileEnv env
CompilePollCompleted compiler_process_ids ps
	# n_processes = length compiler_process_ids
	  fda = createArray (IF_INT_64_OR_32 n_processes (n_processes<<1)) 0
	  fda = fill_fda compiler_process_ids 0 fda
	  r = poll fda n_processes -1
	| r<0
		= abort "poll failed\n"
	| r==0
		= (NoFinishedCompiler,ps)
		# compiler_id = find_fd_index 0 fda
		# results_fd = (compiler_process_ids !! compiler_id).results_fd

		# result_string = createArray 6 '\0'
		# r = read results_fd result_string 6;
		| r<=1
			= abort ("read failed "+++toString r+++ "\n")
		# exit_code = parse_result_number 0 result_string

		= (FinishedCompiler compiler_id exit_code,ps)
where
	fill_fda :: !CompilerProcessIds !Int !*{#Int} -> *{#Int}
	fill_fda [{results_fd}:process_ids] i fda
		# fda = IF_INT_64_OR_32
					{fda & [i] = results_fd + (POLLIN<<32)}
					{fda & [i] = results_fd, [i+1] = POLLIN}
		= fill_fda process_ids (i+(IF_INT_64_OR_32 1 2)) fda
	fill_fda [] i fda
		= fda

	find_fd_index i fda
		| i<size fda
			#! r_events = (fda.[IF_INT_64_OR_32 i ((i<<1)+1)] >> (IF_INT_64_OR_32 48 16)) bitand 0xffff;
			| r_events==0
				= find_fd_index (i+1) fda
			| r_events==POLLIN
				= i
				= abort ("polling file descriptors failed with event"+++toString r_events+++"\n")

O_RDONLY:==0;
O_WRONLY:==1;
O_RDWR:==2;

start_compiler :: !{#Char} !{#Char} -> *CompilerProcess
start_compiler compiler_file_name initial_args
	# commands_file_name = "/tmp/comXXXXXX" +++ "\0" // +++ because modified by mkstemp
	# fd = mkstemp commands_file_name
	| fd== -1
		= abort "mkstemp failed\n"
	# r = close fd
	| r== -1
		= abort "close failed\n"
	# r = unlink commands_file_name
	| r== -1
		= abort "unlink failed\n"
	# r = mkfifo commands_file_name (S_IRUSR bitor S_IWUSR)
	| r== -1
		= abort "mkfifo failed\n"

	# results_file_name = "/tmp/resXXXXXX" +++ "\0" // +++ because modified by mkstemp
	# fd = mkstemp results_file_name
	| fd== -1
		= abort "mkstemp failed\n"
	# r = close fd
	| r== -1
		= abort "close failed\n"
	# r = unlink results_file_name
	| r== -1
		= abort "unlink failed\n"
	# r = mkfifo results_file_name (S_IRUSR bitor S_IWUSR)
	| r== -1
		= abort "mkfifo failed\n"

	# cocl_arguments = add_options_string_to_args 0 initial_args ["--pipe",commands_file_name,results_file_name]

	# (argv,args_memory) = make_argv [compiler_file_name:cocl_arguments]

	# compiler_pid = fork
	| compiler_pid<0
		= abort "fork failed\n"
	| compiler_pid==0
		| execv (compiler_file_name+++"\0") argv<0
			= abort "execv failed\n"
			= abort "execution continued after execv\n"
	| free args_memory<0
		= abort "free failed\n"

	# commands_fd = open (commands_file_name+++"\0") O_WRONLY 0
	| commands_fd == -1
		= abort "open failed\n"
	# results_fd = open (results_file_name+++"\0") O_RDONLY 0
	| results_fd == -1
		= abort "open failed\n"

	= {	commands_file_name=commands_file_name, results_file_name=results_file_name,
		compiler_pid=compiler_pid, commands_fd=commands_fd, results_fd=results_fd}

start_compiler_if_not_yet_started :: !{#Char} !{#Char} !*CompilingInfo -> *CompilingInfo
start_compiler_if_not_yet_started compiler_file_name initial_args NoCompiler
	= CompilerProcess (start_compiler compiler_file_name initial_args)
start_compiler_if_not_yet_started compiler_file_name initial_args compiling_info
	= compiling_info

start_a_compiler_if_not_yet_started compiler_file_name slot compiler_process_ids initial_args
	| slot<length compiler_process_ids
		= (compiler_process_ids !! slot,compiler_process_ids)
		# compiler_process = start_compiler compiler_file_name initial_args
		# compiler_process_ids = compiler_process_ids++[compiler_process]
		= (compiler_process,compiler_process_ids)

CompileHandleExitCode :: !Int !String !String !Int !(WindowFun *env) !(WindowFun *env) !ModuleDirAndName
				!ListTypes !*env -> (!Pathname,!CompilerMsg,!*env) | FileEnv env
CompileHandleExitCode exitcode cocl startupdir slot errwin typewin mdn listTypes ps
	# temp_dir = temp_dir_path startupdir
	  out_file_name = out_file_path temp_dir slot
	  errors_file_name = errors_file_path temp_dir slot
	#	((type_text_not_empty,type_text),ps)
			= accFiles (readTypesInfo (listTypes<>NoTypes) out_file_name) ps
		((errors,errors_and_messages_not_empty,errors_and_messages),ps)
			= accFiles (readErrorsAndWarnings errors_file_name) ps
	| exitcode <> 0 && not errors_and_messages_not_empty
	  = ( ""
		, SyntaxError
		, errwin [  "Error: Compiler crashed: "+++cocl
				 : (case errors of CompilerOK -> ["Unable to open Errors file"] ; _ -> [])
				 ] ps
		)
	#	abcpath			= ModuleDirAndNameToABCSystemPathname mdn
		ps				= (if type_text_not_empty (typewin (StrictListToList type_text)) id) ps
		ps				= (if errors_and_messages_not_empty (errwin (StrictListToList errors_and_messages)) id) ps
		errors			= case exitcode of
							0	-> CompilerOK
							_	-> errors
     = (abcpath,errors,ps)
where
	readTypesInfo :: !Bool !Pathname !*Files -> ((!Bool,!(List String)),!*Files)
	readTypesInfo readtypes	path env
		| not readtypes
			= ((False,Nil),env)
		# (opened,file,env) = fopen path FReadText env
		| not opened
			= ((False,Nil),env)
		# (typelist,types_read,file`) = readTypeMsg file
		  (_,env) = fclose file` env
		= ((types_read,typelist),env)

	readTypeMsg :: !*File -> (!List String,!Bool,!*File)
	readTypeMsg file
		#	(string,file)					= freadline file
			(eof,file)						= fend file
		| eof && IsTypeSpec string
			= (strip_newlines string :! Nil,True,file)
		| eof
			= (Nil,False,file)
		#	(typeslist,types_read,file)	= readTypeMsg file
		= (strip_newlines string :! typeslist,types_read,file)

readErrorsAndWarnings :: !Pathname !*Files -> ((!CompilerMsg, !Bool, !(List String)), !*Files)
readErrorsAndWarnings path env
	# (opened,file,env) = fopen path FReadText env
	| not opened
		= ((CompilerOK,False,Nil),env)
	# (errors,errors_and_warnings_read,errlist,file`) = readErrorAndWarningMessages file
	  (_,env) = fclose file` env
	= ((errors,errors_and_warnings_read,errlist),env)
where
	readErrorAndWarningMessages :: !*File -> (!CompilerMsg,!Bool,!List String,!*File)
	readErrorAndWarningMessages file
		#!	(string, file1)					= freadline file
			(eof,file2)						= fend file1
			(is_import_error,path)			= IsImportError20 string
		| eof
			#!	not_empty_or_newline 		= (size string)<>0 && string.[0]<>'\n'
			= (if is_import_error (Patherror path) SyntaxError,not_empty_or_newline,strip_newlines string :! Nil,file2)
		#	(path_error,_,errlist,file3) = readErrorAndWarningMessages file2
		= (if is_import_error (Patherror path) path_error,True,strip_newlines string:!errlist,file3)

strip_newlines :: !{#Char} -> {#Char}
strip_newlines s
	| size s==0
		= s
		# last = dec (size s)
		  char = s.[last]
		| char == '\n' || char == '\r'
			= strip_newlines (s % (0,dec last))
		= s

temp_dir_path startupdir
	= startupdir +++ DirSeparatorString +++ "Temp"

out_file_path temp_dir slot
	| slot==0
		= temp_dir +++ DirSeparatorString +++ "out"
		= temp_dir +++ DirSeparatorString +++ "out"+++toString slot

errors_file_path temp_dir slot
	| slot==0
		= temp_dir +++ DirSeparatorString +++ "errors"
		= temp_dir +++ DirSeparatorString +++ "errors"+++toString slot

get_optional_calling_convention :: !{#Char} -> (!{#Char},!{#Char})
get_optional_calling_convention s
	# s_size = size s;
	| s_size>0 && s.[0]==':'
		# next_c = FindColonChar 1 s s_size
		| next_c<s_size
			= (s % (1,next_c-1),s % (next_c+1,s_size));
			= ("",s);
		= ("",s);

get_path_name_and_options2 ccstring startupdir
	# (ccstring,rem) = splitOptions ccstring
	  (opts,opts`) = splitOptions rem
	  cocl = startupdir +++ "/" +++ ccstring
	  cocldir = RemoveFilename cocl
	= (cocl,cocldir,opts,opts`)

get_path_name_and_options codegen_or_linker startupdir
	# (codegen_or_linker,opts) = splitOptions codegen_or_linker
	| size codegen_or_linker>0 && codegen_or_linker.[0]=='/'
		# codegen_or_linker_dir = RemoveFilename codegen_or_linker
		= (codegen_or_linker,codegen_or_linker_dir,opts)
		# codegen_or_linker = startupdir +++ "/" +++ codegen_or_linker
		# codegen_or_linker_dir = RemoveFilename codegen_or_linker
		= (codegen_or_linker,codegen_or_linker_dir,opts)

splitOptions :: !{#Char} -> (!{#Char},!{#Char})
splitOptions str
	# len_str = size str
	  first_c = FindColonChar 0 str len_str
	| first_c >= len_str
		= (str,"")
		# first_str = str % (0,dec first_c)
		  last_str = str % (first_c+1, len_str)
		= (first_str,last_str)

FindColonChar :: !Int !String !Int -> Int;
FindColonChar pos line linelen
	| pos<linelen && line.[pos]<>':'
		= FindColonChar (pos+1) line linelen;
		= pos;

add_options_string_to_args :: !Int !{#Char} ![{#Char}] -> [{#Char}]
add_options_string_to_args i s args
	# first_i = skip_spaces_and_tabs i s
	| first_i>=size s
		= args
		# end_i = skip_to_space_or_tab (i+1) s
		= [s % (first_i,end_i-1) : add_options_string_to_args end_i s args]
where
	skip_spaces_and_tabs i s
		| i<size s
			# c=s.[i]
			| c==' ' || c=='\t'
				= skip_spaces_and_tabs (i+1) s
				= i
			= i

	skip_to_space_or_tab i s
		| i<size s
			# c=s.[i]
			| c==' ' || c=='\t'
				= i
				= skip_to_space_or_tab (i+1) s
			= i

compiler_arguments :: !String !String !CompileOrCheckSyntax !Pathname !(List Pathname) !Bool !ProjectCompilerOptions !CompilerOptions -> [String]
compiler_arguments out_file_name errors_file_name compileOrCheckSyntax path paths
					write_module_times project_compiler_options co
	# args = makeCompilerOptionsArguments compileOrCheckSyntax write_module_times project_compiler_options co
	= args ++ [path,"-P",concatenate_paths paths,"-RE",errors_file_name,"-RO",out_file_name];

concat_args [] = ""
concat_args [arg] = arg
concat_args [arg:args] = arg+++" "+++concat_args args

makeCompilerOptionsArguments :: !CompileOrCheckSyntax !Bool !ProjectCompilerOptions !CompilerOptions -> [String]
makeCompilerOptionsArguments compileOrCheckSyntax write_module_times
		{pco_memory_profiling,pco_time_profiling,pco_callgraph_profiling,pco_desc_exl,pco_dynamics,pco_generic_fusion,pco_link_dynamic}
		{neverMemoryProfile,neverTimeProfile,sa,gw,gc,listTypes,attr,reuseUniqueNodes,fusion}
	= write_module_times_arg ++ checksyntax ++ timeProfileSwitch ++ callgraphProfileSwitch ++ memoryProfileSwitch ++ descExlSwitch ++ dynamicsSwitch
		++ strictness ++ warnings ++ comments ++ listtypes ++ show_attr ++ reuse ++ fusion_arg
where
	write_module_times_arg
		| write_module_times
			= ["-wmt"]
			= []
	memoryProfileSwitch
		| (not neverMemoryProfile && pco_memory_profiling) || pco_desc_exl || pco_link_dynamic
			= ["-desc"]
			= []
	timeProfileSwitch
		| not neverTimeProfile && pco_time_profiling
			= ["-pt"]
			= []
	callgraphProfileSwitch
		| not neverTimeProfile && pco_callgraph_profiling
			= ["-pg"]
			= []
	descExlSwitch = if (pco_desc_exl || pco_link_dynamic) ["-exl"] []
	dynamicsSwitch = if (pco_dynamics || pco_link_dynamic) ["-dynamics"] []
	strictness
		| sa
			= []
			= ["-sa"]
	warnings
		| gw
			= []
			= ["-w"]
	comments
		| gc
			= ["-d"]
			= []
	listtypes
		| listTypes == InferredTypes
			= ["-lt"]
		| listTypes == AllTypes
			= ["-lat"]
		| listTypes == StrictExportTypes
			= ["-lset"]
			= []
	show_attr
		| attr
			= []
			= ["-lattr"]
	checksyntax
		| compileOrCheckSyntax == SyntaxCheck
			= ["-c"]
			= []
	reuse
		| reuseUniqueNodes
			= ["-ou"]
			= []
	fusion_arg
		= case fusion of FusionOn -> ["-fusion"]; FusionDefault | pco_generic_fusion -> ["-generic_fusion"]; _ -> []

make_code_generator_arguments genAsmOrCode {ci,cs}
	= checkindex++checkstack++genasm
where
	checkindex	| ci = ["-ci"]; = []
	checkstack	| cs = ["-os"]; = []
	genasm		| genAsmOrCode == AsmGeneration
								= ["-a"]
								= []

concatenate_paths :: (List Pathname) -> String
concatenate_paths ss
	# s = createArray (sSize ss) ':'
	= sUpdate 0 s ss
where
	sSize Nil = 0
	sSize (string :! Nil) = size string
	sSize (string :! rest) = size string + 1 + sSize rest

	sUpdate i s Nil = s
	sUpdate i s (string :! Nil)
		# (_,s) = sU (size string) i 0 s string
		= s
	sUpdate i s (string :! rest)
		# (i,s) = sU (size string) i 0 s string
		# i = inc i
		= sUpdate i s rest

	sU l i j s h
		| j >= l = (i,s)
		# s = update s i h.[j]
		= sU l (inc i) (inc j) s h

make_argv argv_list
	# args_size = argv_length argv_list 0
	  args_string = create_args_string args_size argv_list
	  args_memory = malloc args_size
	| args_memory==0
		= abort "malloc failed\n"
	# args_memory = memcpy_string_to_pointer args_memory args_string args_size
	  argv = create_argv argv_list args_memory
	= (argv,args_memory)
where
	argv_length [a:as] l
		= argv_length as (l+((size a+4) bitand -4))
	argv_length [] l
		= l

	create_args_string args_size argv_list
		# s = createArray args_size '\0'
		= copy_args argv_list 0 s
	where
		copy_args [a:as] i s
			# s = copy_chars 0 a i s
			= copy_args as (i+((size a+4) bitand -4)) s
		copy_args [] i s
			= s

		copy_chars :: !Int !{#Char} !Int !*{#Char} -> *{#Char}
		copy_chars ai a si s
			| ai<size a
				# s = {s & [si]=a.[ai]}
				= copy_chars (ai+1) a (si+1) s
				= s

	create_argv argv_list args_memory
		# n_args = length argv_list
		# argv = createArray (n_args+1) 0;
		= fill_argv 0 argv_list argv args_memory
	where
		fill_argv :: !Int ![{#Char}] !*{#Int} !Int -> *{#Int}
		fill_argv arg_n [a:as] argv args_memory
			# argv = {argv & [arg_n]=args_memory}
			  args_memory = args_memory + ((size a+4) bitand -4)
			= fill_argv (arg_n+1) as argv args_memory
		fill_argv arg_n [] argv args_memory
			= {argv & [arg_n]=0}

ApplicationOptionsToFlags :: !ApplicationOptions -> Int
ApplicationOptionsToFlags {sgc,pss,marking_collection,set,o,memoryProfiling,write_stderr_to_file,disable_rts_flags}
	= showgc+printstacksize+showexectime+cons+marking_collection_mask+memory_profiling_mask+write_stderr_to_file_mask+disable_rts_flags_mask
where
	showgc
		| sgc	= 2
				= 0
	printstacksize
		| pss	= 4
				= 0
	showexectime
		| set	= 8
				= 0
	write_stderr_to_file_mask
		| write_stderr_to_file	= 128
								= 0
	marking_collection_mask
		| marking_collection 	= 64
								= 0
	memory_profiling_mask
		| memoryProfiling	= 32
							= 0
	cons
		= case o of
			BasicValuesOnly		-> 1
			ShowConstructors	-> 0
			NoReturnType		-> 16
			NoConsole			-> 16

	disable_rts_flags_mask
		| disable_rts_flags	= 8192
							= 0

(FWI) infixl
(FWI) f i :== fwritei i f

write_options_file :: !{#.Char} !.Int !.Int !.Int !.Int !.Int !.Int !Bool !*Files -> *(!Bool,!*Files)
write_options_file options_file_name flags heap_size stack_size initial_heap_size heap_size_multiple min_write_heap_size use_64_bit_processor files
	# (opened,file,files)
		= fopen options_file_name FWriteData files
	| not opened
		= (False,files)
	#! file = IF_INT_64_OR_32
			(file FWI
			0x464c457f FWI 0x00010102 FWI 0x00000000 FWI 0x00000000 FWI
			(IF_ARM 0x00b70001 0x003e0001) FWI 0x00000001 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000094 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000040 FWI 0x00400000 FWI 0x00040007 FWI

			heap_size FWI (heap_size>>32) FWI stack_size FWI (stack_size>>32) FWI
			flags      FWI 0x00000000 FWI heap_size_multiple FWI 00 FWI
			initial_heap_size FWI (initial_heap_size>>32) FWI
										  0x79732e00 FWI 0x6261746d FWI
			0x74732e00 FWI 0x62617472 FWI 0x68732e00 FWI 0x74727473 FWI
			0x2e006261 FWI 0x74786574 FWI 0x61642e00 FWI 0x2e006174 FWI
			0x00737362 FWI
						   0x00000000 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI
						   0x0000001b FWI 0x00000001 FWI 0x00000006 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000000 FWI 0x00000040 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000004 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI
						   0x00000021 FWI 0x00000001 FWI 0x00000003 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000000 FWI 0x00000040 FWI
			0x00000000 FWI 0x00000028 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000004 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI
						   0x00000027 FWI 0x00000008 FWI 0x00000003 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000000 FWI 0x00000068 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000004 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI
						   0x00000011 FWI 0x00000003 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000000 FWI 0x00000068 FWI
			0x00000000 FWI 0x0000002c FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000001 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI
						   0x00000001 FWI 0x00000002 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000000 FWI 0x00000254 FWI
			0x00000000 FWI 0x000000d8 FWI 0x00000000 FWI 0x00000006 FWI
			0x00000004 FWI 0x00000004 FWI 0x00000000 FWI 0x00000018 FWI
			0x00000000 FWI
						   0x00000009 FWI 0x00000003 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000000 FWI 0x0000032c FWI
			0x00000000 FWI 0x00000044 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000001 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI
						   0x00000000 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000000 FWI
														 0x00000000 FWI
			0x00010003 FWI 0x00000000 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI
				           0x00000000 FWI 0x00020003 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000000 FWI
														 0x00000000 FWI
			0x00030003 FWI 0x00000000 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI
				           0x00000001 FWI 0x00020011 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000000 FWI
														 0x0000000b FWI
			0x00020011 FWI 0x00000008 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI
				           0x00000019 FWI 0x00020011 FWI 0x00000010 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000000 FWI
														 0x0000001f FWI
			0x00020011 FWI 0x00000018 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI
				           0x00000032 FWI 0x00020011 FWI 0x00000020 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000000 FWI
														 0x61656800 FWI
			0x69735f70 FWI 0x6100657a FWI 0x74735f62 FWI 0x5f6b6361 FWI
			0x657a6973 FWI 0x616c6600 FWI 0x68007367 FWI 0x5f706165 FWI
			0x657a6973 FWI 0x6c756d5f FWI 0x6c706974 FWI 0x6e690065 FWI
			0x61697469 FWI 0x65685f6c FWI 0x735f7061 FWI 0x00657a69)

			(file FWI
			0x464c457f FWI 0x00010101 FWI 0x00000000 FWI 0x00000000 FWI
			0x00030001 FWI 0x00000001 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000074 FWI 0x00000000 FWI 0x00000034 FWI 0x00280000 FWI
			0x00040007 FWI heap_size FWI stack_size FWI flags FWI
			heap_size_multiple FWI initial_heap_size FWI 0x79732e00 FWI 0x6261746d FWI
			0x74732e00 FWI 0x62617472 FWI 0x68732e00 FWI 0x74727473 FWI
			0x2e006261 FWI 0x74786574 FWI 0x61642e00 FWI 0x2e006174 FWI
			0x00737362 FWI 0x00000000 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000000 FWI 0x0000001b FWI
			0x00000001 FWI 0x00000006 FWI 0x00000000 FWI 0x00000034 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000000 FWI 0x00000004 FWI
			0x00000000 FWI 0x00000021 FWI 0x00000001 FWI 0x00000003 FWI
			0x00000000 FWI 0x00000034 FWI 0x00000014 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000004 FWI 0x00000000 FWI 0x00000027 FWI
			0x00000008 FWI 0x00000003 FWI 0x00000000 FWI 0x00000048 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000000 FWI 0x00000004 FWI
			0x00000000 FWI 0x00000011 FWI 0x00000003 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000048 FWI 0x0000002c FWI 0x00000000 FWI
			0x00000000 FWI 0x00000001 FWI 0x00000000 FWI 0x00000001 FWI
			0x00000002 FWI 0x00000000 FWI 0x00000000 FWI 0x0000018c FWI
			0x00000090 FWI 0x00000006 FWI 0x00000004 FWI 0x00000004 FWI
			0x00000010 FWI 0x00000009 FWI 0x00000003 FWI 0x00000000 FWI
			0x00000000 FWI 0x0000021c FWI 0x00000044 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000001 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000000 FWI 0x00000000 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000000 FWI 0x00010003 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000000 FWI 0x00020003 FWI 0x00000000 FWI
			0x00000000 FWI 0x00000000 FWI 0x00030003 FWI 0x00000001 FWI
			0x00000000 FWI 0x00000000 FWI 0x00020211 FWI 0x0000000b FWI
			0x00000004 FWI 0x00000000 FWI 0x00020211 FWI 0x00000019 FWI
			0x00000008 FWI 0x00000000 FWI 0x00020211 FWI 0x0000001f FWI
			0x0000000c FWI 0x00000000 FWI 0x00020211 FWI 0x00000032 FWI
			0x00000010 FWI 0x00000000 FWI 0x00020211 FWI 0x61656800 FWI
			0x69735f70 FWI 0x6100657a FWI 0x74735f62 FWI 0x5f6b6361 FWI
			0x657a6973 FWI 0x616c6600 FWI 0x68007367 FWI 0x5f706165 FWI
			0x657a6973 FWI 0x6c756d5f FWI 0x6c706974 FWI 0x6e690065 FWI
			0x61697469 FWI 0x65685f6c FWI 0x735f7061 FWI 0x00657a69)
	# (close_ok,files)
		= fclose file files
	= (close_ok,files)

ClearCompilerCache :: .a
ClearCompilerCache = abort "ClearCompilerCache\n"

ClearCompilerCaches :: .a
ClearCompilerCaches = abort "ClearCompilerCaches\n"

SendRepeatResult :: .a
SendRepeatResult = abort "SendRepeatResult\n"

StartCodeGenerator :: .a
StartCodeGenerator = abort "StartCodeGenerator\n"

Execute` :: .a
Execute` = abort "Execute`\n"

RunExternalCommand :: !String ![String] !String !*GeneralSt -> *(!Int, ![String], !*GeneralSt)
RunExternalCommand cmd args startupdir ps
	# temp_dir = temp_dir_path startupdir
	  errors_file_name = errors_file_path temp_dir 0
	# stderr_fd = creat (errors_file_name+++"\0") 0644
	| stderr_fd== (-1)
		= abort "creat failed\n"

	# (argv,args_memory) = make_argv [cmd : args]

	# pid = fork
	| pid<0
		= abort "fork failed\n"
	| pid==0
		# r=dup2 stderr_fd 2
		| r== (-1)
			= abort "dup2 failed\n"
		| execv (cmd+++"\0") argv<0
			= abort "execv failed\n"
			= abort "execution continued after execv\n"
	| free args_memory<0
		= abort "free failed\n"

	# (w_pid,status) = wait_pid pid 0
	| w_pid <> -1 && w_pid<>pid
		= abort "waitpid failed\n"
	# result = (status bitand 0xff00) >> 8
	# wtermsig = status bitand 0x7f
	| wtermsig<>0
		= abort "external command exited abnormally\n"

	# r=close stderr_fd
	| r==(-1)
		= abort "close failed\n"

	# (out,ps) = accFiles (readFileLines errors_file_name) ps

	= (result,out,ps)
where
	readFileLines :: !String !*Files -> *(![String], !*Files)
	readFileLines path env
	# (ok,f,env) = fopen path FReadText env
	| not ok = ([], env)
	# (out,f) = read [] f
	# (_,env) = fclose f env
	= (out,env)
	where
		read :: ![String] !*File -> *(![String], !*File)
		read acc f
		# (e,f) = fend f
		| e = (reverse acc,f)
		# (line,f) = freadline f
		#! line = strip_newlines line
		= read [line:acc] f

wait_pid :: !Int !Int -> (!Int,!Int)
wait_pid pid options
	# status_a = createArray 1 0
	# w_pid = waitpid pid status_a 0
	| w_pid==w_pid
		# status = status_a.[0]
		= (w_pid,status)
		# status = status_a.[0]
		= (w_pid,status)

S_IRUSR:==0x100
S_IWUSR:==0x080

mkstemp :: !{#Char} -> Int;
mkstemp temp_file_name = code {
	ccall mkstemp "s:I"
}

creat :: !{#Char} !Int -> Int;
creat string0 mode = code {
	ccall creat "sI:I"
}

open :: !{#Char} !Int !Int -> Int;
open path_name flags mode = code {
	ccall open "sII:I"
}

write :: !Int !{#Char} !Int -> Int;
write fd buffer count = code {
	ccall write "Isp:p"
}

read :: !Int !{#Char} !Int -> Int;
read fd buffer count = code {
	ccall read "Isp:p"
}

close :: !Int -> Int;
close fd = code {
	ccall close "I:I"
}

unlink :: !{#Char} -> Int;
unlink file_name = code {
	ccall unlink "s:I"
}

mkfifo :: !{#Char} !Int -> Int;
mkfifo name flags = code {
	ccall mkfifo "sI:I"
}

dup2 :: !Int !Int -> Int
dup2 oldfd newfd = code {
	ccall dup2 "II:I"
}

fork :: Int
fork = code {
	ccall fork ":I"
}

execv :: !{#Char} !{#Int} -> Int
execv program argv = code {
	ccall execv "sA:I"
}

waitpid :: !Int !{#Int} !Int -> Int
waitpid pid status_p options = code {
	ccall waitpid "IAI:I"
}

poll :: !{#Int} !Int !Int -> Int;
poll fds nfds timeout = code {
	ccall poll "AII:I"
}

malloc :: !Int -> Int
malloc s = code {
	ccall malloc "p:p"
}

free :: !Int -> Int
free p = code {
	ccall free "p:I"
}

memcpy_string_to_pointer :: !Int !{#Char} !Int -> Int
memcpy_string_to_pointer p s n = code {
	ccall memcpy "psp:p"
}
