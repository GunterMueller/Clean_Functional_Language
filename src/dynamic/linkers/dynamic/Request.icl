implementation module Request;

import StdEnv,StdMaybe;
import Directory, StdDynamicTypes;
import pdRequest,link_library_instance,pdObjectToMem;
import utilities,ExtFile,ExtString,DefaultElem,directory_structure;
import State,ToAndFromGraph,pdExtInt,dus_label,LinkerMessages;

// platform independent
Quit :: !ProcessSerialNumber [String] !*DLServerState !*f -> (!Bool,!ProcessSerialNumber,!*DLServerState, !*f) | FileSystem f;
Quit client_id _ s io
	#! dl_client_state = {default_elemU & id = client_id, app_linker_state = EmptyState};
	= (True,client_id,AddToDLServerState dl_client_state s,io);

AddAndInit_ :: !ProcessSerialNumber [String] !*DLServerState !*f -> (!Bool,!ProcessSerialNumber,!*DLServerState, !*f) | FileSystem f;
AddAndInit_ client_id [eagerly_linked_client_name:_] s=:{application_path} io
	# dl_client_state = {default_elemU & id = client_id};
	#! (ok,dl_client_state) = IsErrorOccured dl_client_state;
	#! dl_client_state = output_message_begin "AddAndInit_" client_id dl_client_state
	#! s = AddToDLServerState dl_client_state s;
	= (not ok,client_id,s,io);

Close :: !ProcessSerialNumber [String] !*DLServerState !*f -> (!Bool,!ProcessSerialNumber,!*DLServerState, !*f) | FileSystem f;
Close client_id _ s=:{application_path} io
	#! (client_exists,dl_client_state,s) = RemoveFromDLServerState client_id s;
	| not client_exists
		= internal_error "Close (internal error): client not registered" client_id dl_client_state s io;
	#! dl_client_state = output_message_begin "Close application" client_id dl_client_state		
	// platform dependent
	#! dl_client_state = CloseClient dl_client_state;
	= (True,client_id,AddToDLServerState dl_client_state s,io);

// lookup addresses of some already linked in labels
GetLabelAddresses :: !ProcessSerialNumber [String] !*DLServerState !*f -> (!Bool,!ProcessSerialNumber,!*DLServerState, !*f) | FileEnv f;
GetLabelAddresses client_id [label_names_encoded_in_msg] s io
	#! (client_exists,dl_client_state,s) 
		= RemoveFromDLServerState client_id s;
	| not client_exists
		= internal_error "GetLabelAddresses (internal error): client not registered" client_id dl_client_state s io;

	#! dl_client_state = output_message_begin "GetLabelAddresses" client_id dl_client_state

	#! symbols = ExtractArguments '\n' 0 label_names_encoded_in_msg [];

	#! (Just main_library_instance_i,dl_client_state) = dl_client_state!cs_main_library_instance_i;

	#! (labels_to_be_linked,_)
		= mapSt (convert_symbol_name_into_dus_label main_library_instance_i) symbols 0;		

	#! (_,symbol_addresses,dl_client_state,io)
		= load_code_library_instance (Just labels_to_be_linked) main_library_instance_i dl_client_state io;

	// check for errors		
	#! (ok,dl_client_state) = IsErrorOccured dl_client_state;
	| not ok
		= (not ok,client_id,AddToDLServerState dl_client_state s,io);
	
	// verbose
	# messages = foldl2 produce_verbose_output2 [] labels_to_be_linked symbol_addresses;
	#! dl_client_state = DEBUG_INFO (SetLinkerMessages messages dl_client_state) dl_client_state;
	// end

	#! io = SendAddressToClient client_id symbol_addresses io;		
	= (not ok,client_id,AddToDLServerState dl_client_state s,io);
where {
	convert_symbol_name_into_dus_label library_instance_i label_name ith_address
		#! dus_label =
			{	dusl_label_name				= label_name
			,	dusl_library_instance_i		= library_instance_i
			,	dusl_linked					= False
			,	dusl_label_kind				= DSL_EMPTY
			,	dusl_ith_address			= ith_address
			,	dusl_address				= -1
			};
		= (dus_label,inc ith_address);
}

MessageFromSecondOrLaterLinker_ :: .(ProcessSerialNumber -> .(*DLServerState -> .(*a -> *(*DLServerState,*a)))) .b ![{#.Char}] !*DLServerState *a -> *(.Bool,ProcessSerialNumber,*DLServerState,*a) | FileSystem a;
MessageFromSecondOrLaterLinker_ open_client client_id l=:[cmd_line] s=:{application_path} io
	#! cmd_line = cmd_line % (1,dec (size cmd_line) - 2);
	#! x = ParseCommandLine cmd_line;
	= AddClient3 open_client client_id [s \\ s <-: x] s io;

DumpDynamic :: !ProcessSerialNumber [String] !*DLServerState !*f -> (!Bool,!ProcessSerialNumber,!*DLServerState, !*f) | FileSystem f;
DumpDynamic client_id [cmd_line] s=:{application_path} io
	#! (client_exists,dl_client_state,s) = RemoveFromDLServerState client_id s;
	| not client_exists
		= abort "DumpDynamic: client doesnot exist";
	# dl_client_state = AddDebugMessage "DumpDynamic" dl_client_state;
	#! dl_client_state = {dl_client_state & do_dump_dynamic	= True,	cs_dlink_dir = application_path};
	# io = SendAddressToClient client_id (FILE_IDENTIFICATION application_path "") io;
	# s = AddToDLServerState dl_client_state s;
	= (False,client_id,s,io);
	
GetDynamicLinkerDir :: !ProcessSerialNumber [String] !*DLServerState !*f-> (!Bool,!ProcessSerialNumber,!*DLServerState, !*f) | FileSystem f;
GetDynamicLinkerDir client_id [cmd_line] s=:{application_path} io
	#! (client_exists,dl_client_state,s) = RemoveFromDLServerState client_id s;
	| not client_exists
		= abort "DumpDynamic: client doesnot exist";
	#! dl_client_state = output_message_begin "GetDynamicLinkerDir" client_id dl_client_state
	# io = SendAddressToClient client_id application_path io;
	# s = AddToDLServerState dl_client_state s;
	= (False,client_id,s,io);
	
make_dynamic_linker_subdir :: !String !String -> String;	
make_dynamic_linker_subdir sub_dir dynamic_linker_dir 
	| IS_NORMAL_FILE_IDENTIFICATION
		= abort "make_dynamic_linker_dir; internal error; should only be called in md5-mode";
	= dynamic_linker_dir +++ "\\" +++ sub_dir;

make_dynamic_linker_library_path :: !String !String -> String;	
make_dynamic_linker_library_path dynamic_linker_dir library
	| IS_NORMAL_FILE_IDENTIFICATION
		= library;
	#! library_subdir = make_dynamic_linker_subdir DS_LIBRARIES_DIR dynamic_linker_dir;
	= library_subdir +++ "\\" +++ library;

encode_command_line :: ![String] -> {#Char};
encode_command_line cmd_line
	= foldSt quote_if_necessary cmd_line {};
	with {
		quote_if_necessary arg s 
			| arg_contains_spaces 0 (size arg)
				= s +++ " \"" +++ arg +++ "\"";
			
				= s +++ " " +++ arg;
		where {
			arg_contains_spaces i s_a
				| i == s_a
					= False;
				| isSpace arg.[i] 
					= True;
					= arg_contains_spaces (inc i) s_a;
		}
	}

AddClient3 :: .(ProcessSerialNumber -> .(*DLServerState -> .(*a -> *(*DLServerState,*a)))) .b ![{#.Char}] !*DLServerState *a -> *(.Bool,ProcessSerialNumber,*DLServerState,*a) | FileSystem a;
AddClient3 open_client client_id [_:xl] s=:{application_path} io
	// initialize dl_client_state
	# dl_client_state = {default_elemU & app_linker_state = EmptyState};

	# (batch_path, xl)
		=	parse_batch_path xl;
		with {
			parse_batch_path :: [{#Char}] -> ({#Char},[{#Char}]);
			parse_batch_path ["--client-batch-file",batch_path:args]
				=	(batch_path, args);
			parse_batch_path args
				=	("", args);
		};

	# parsed_cmd_arg = hd xl;
	# parsed_cmd_arg
		= case (FILE_IDENTIFICATION True False) of {
			True
				-> make_dynamic_linker_library_path application_path parsed_cmd_arg;
			_
				-> parsed_cmd_arg;
		};

	// console or gui application
	# (path_file,_) = ExtractPathFileAndExtension parsed_cmd_arg;
	# open_console_window
		= if IS_NORMAL_FILE_IDENTIFICATION (path_file.[dec (size path_file)] == 'c') True;
		
	# ((ok,path),io) = pd_StringToPath parsed_cmd_arg io;
	# ((error,_),io) = getFileInfo path io;

	#! (current_directory,file_name)
		=  if (batch_path=="")
			(ExtractPathAndFile parsed_cmd_arg)
			(fst (ExtractPathAndFile batch_path), batch_path);

	#! new_cmd_line = encode_command_line (tl xl)

	#! (client_started,client_id,client_executable,s)
		= StartClientApplication3 current_directory file_name open_console_window new_cmd_line s;

	#! dl_client_state = {dl_client_state & id = client_id};
	| not client_started
		#! msg = "file '" +++ client_executable +++ "' cannot be started";
		= (True,client_id,AddToDLServerState (AddMessage (LinkerError msg) dl_client_state) s,io);

		#! name = fst (ExtractPathFileAndExtension parsed_cmd_arg);
			
		# dl_client_state = {dl_client_state & cs_main_library_name = name, cs_dlink_dir = application_path};
			
		# title = "AddClient3"
		#! dl_client_state = output_message_begin title client_id dl_client_state;

		#! s = AddToDLServerState dl_client_state s;
		#! (s,io)
			= open_client client_id s io
		= (False,client_id,s,io);
where {
	build_cmdline_in_addclient_format i limit cmd_line
		| i == limit
			= "";
			= cmd_line.[i] +++ (if (i == (dec limit)) "" " ") +++ (build_cmdline_in_addclient_format (inc i) limit cmd_line);
};
	
// Loads an application from a library
//
// Output:
// - for each set of type equivalence with at least two types, a single implementation has been linked in.
LoadApplication :: !ProcessSerialNumber [String] !*DLServerState !*f -> (!Bool,!ProcessSerialNumber,!*DLServerState, !*f) | FileEnv, FileSystem f;
LoadApplication client_id args s=:{application_path} io
	// copy from Init
	#! (client_exists,dl_client_state,s) = RemoveFromDLServerState client_id s;
	| not client_exists
		= internal_error "LoadApplication (internal error): client not registered" client_id dl_client_state s io;

	# (main_code_type_lib,dl_client_state)
		= case args of {
			[arg:_]
				| size arg<>0
					# lib_path = make_dynamic_linker_library_path application_path arg;
					# name = fst (ExtractPathFileAndExtension lib_path);
					# dl_client_state = {dl_client_state & cs_main_library_name=name, cs_dlink_dir = application_path}
					-> (name,dl_client_state);
			_
				-> dl_client_state!cs_main_library_name;
		  }
	#! title = "LoadApplication: " +++ snd (ExtractPathAndFile main_code_type_lib)
	#! dl_client_state = output_message_begin title client_id dl_client_state

	#! (dlink_dir,s)
		= GetDynamicLinkerDirectory s;
	#! (to_and_from_graph_table,io)
		= init_to_and_from_graph_table dlink_dir io;

	#! (library_instance_i,_,dl_client_state=:{cs_main_library_instance_i},io)
		= RegisterLibrary Nothing main_code_type_lib dl_client_state io;
	# dl_client_state = { dl_client_state & cs_to_and_from_graph = to_and_from_graph_table };
	#! dl_server_state = s;
	#! (start_addr,_,dl_client_state,io)
		= load_code_library_instance Nothing library_instance_i dl_client_state io;

 	# io = SendAddressToClient client_id (FromIntToString start_addr) io;

	# dl_client_state = AddDebugMessage ("###start:" +++ (hex_int start_addr)) dl_client_state;
		
	// check for errors
	#! (ok,dl_client_state)
		= IsErrorOccured {dl_client_state & initial_link = False};
	= (not ok,client_id,AddToDLServerState dl_client_state dl_server_state,/*KillClient3 client_id ok*/ io);

AddAndInitPC_ :: ProcessSerialNumber ![{#.Char}] *DLServerState *a -> *({#{#Char}},*(!Bool,!ProcessSerialNumber,!*DLServerState,!*a)) | FileSystem a;
AddAndInitPC_ client_id [commandline] s io
	// extract executable name
	#! parsed_command_line = ParseCommandLine commandline;
	= (parsed_command_line,AddAndInit_ client_id [ p \\ p <-: parsed_command_line ] s io);
AddAndInitPC_ client_id q=:[commandline,do_add_project] s io
	#! parsed_command_line = ParseCommandLine commandline;
	= (parsed_command_line,AddAndInit_ client_id ([ p \\ p <-: parsed_command_line ] ++ [do_add_project]) s io);
AddAndInitPC_ _ l s io
	= abort ("AddAndInitPC" +++ toString (length l));
