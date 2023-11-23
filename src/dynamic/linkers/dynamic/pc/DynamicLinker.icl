module DynamicLinker;

from StdReal import entier; // RWS marker

import DLState;
import DynamicLink;
from pdRequest import ParseCommandLine;
import Request;
import encode_dynamic;
import decode_dynamic;
import directory_structure;
import ExtFile;
import ArgEnv;
import StdEnv;
import ExtString;
import LinkerMessages;
import DefaultElem;
import ProcessSerialNumber;
import pdExtFile;
import State;

Start :: *World -> *World;
Start world
	| is_first_instance
		#! start_state = default_elemU;
		#! (start_state,world)
			= init_io2 start_state world

		#! (start_state,world)
			= dynamic_linker_message_loop start_state world;
		with {
			dynamic_linker_message_loop start_state=:{quit_server} world
				| quit_server
					= (start_state,world);
				#! (start_state,world)
					= any_clients_left (receive_and_handle_dynamic_linker_message start_state world);
				= dynamic_linker_message_loop start_state world
		}
		= world;
				
		#! command_line = getCommandLine;
		#! new_cmd_line = encode_command_line [ c \\ c <-: command_line];
		#! new_cmd_line = new_cmd_line % (1,dec (size new_cmd_line));
		| PassCommandLine (new_cmd_line +++ "\0")
			= world
			= abort ("error executing " +++ new_cmd_line);
where {
	quote_and_add_arg :: !Int !String !String -> String;
	quote_and_add_arg i arg s
		# s = if (i == 0) s (s +++ " ");
		# s
			= case (arg.[0] <> '\"' && (fst (CharIndex arg 0 ' ')) ) of {
				True
					// string should have been quoted
					-> s +++ "\"" +++ arg +++ "\"";
				_
					-> s +++ arg;
			};
		= s;

	init_io2 :: !*DLServerState !*f -> (!*DLServerState, !*f) | FileEnv f & FileSystem f;
	init_io2 s io
		// no arguments?
		# cmd_line = getCommandLine;

		| size cmd_line <= 1
			= abort "DynamicLinker needs an argument";

		// compatibility mode
		# option = cmd_line.[1];
		| (size cmd_line == 2) && ((option == "/W") || (option  == "/w"))
			# project_name
				= cmd_line.[2];

			// read environments
			# application_path = (ParseCommandLine GetDynamicLinkerPath).[0];

			# (sep_found,sep_index)
				= CharIndexBackwards application_path (size application_path - 1) path_separator;
			| not sep_found
				= abort ("could not read IDEEnvs");
			
			# application_path = application_path % (0,dec sep_index);
				
			# s = { s &
					application_path				= application_path
				,	static_application_as_client	= (option == "/W") || (option  == "/w")
				};
			= InitServerState s io;
			
			#! dynamic_linker_dir
				= fst (ExtractPathAndFile cmd_line.[0]);
			# s = { s &
					dlss_lib_mode			= True
				,	dlss_lib_command_line	= cmd_line
				, 	application_path		= dynamic_linker_dir
				};
			# (s,io)
				= InitServerState s io;
			# (_,io)
				= ds_create_directory DS_SYSTEM_DYNAMICS_DIR dynamic_linker_dir io;
			= (s,io);
	where {
		build_cmdline_in_addclient_format :: !Int !Int {{#Char}} -> {#Char};
		build_cmdline_in_addclient_format i limit cmd_line
			| i == limit
				= "";
				= cmd_line.[i] +++ (if (i == (dec limit)) "" " ") +++ (build_cmdline_in_addclient_format (inc i) limit cmd_line);
	};
}

// windows specific
dummy s io
	= (s,io);
dummy_ignore_arg _ s io
	= (s,io);

receive_and_handle_dynamic_linker_message :: !*DLServerState !*f -> *(*DLServerState,!*f) | FileEnv, FileSystem f;
receive_and_handle_dynamic_linker_message s=:{dlss_lib_mode=True,dlss_lib_command_line} io
	// matches only when there is no other dynamic rts running
	# s = { s & dlss_lib_mode	= False };
	#! (timeout,_,_)
		= ReceiveReqWithTimeOutE True;
	| timeout || not timeout
		# (remove_state,client_id,s,io)
			= (AddClient3 dummy_ignore_arg DefaultProcessSerialNumber [ arg \\ arg <-: dlss_lib_command_line] s io)
		= handle_request_result dummy dummy_ignore_arg (remove_state,client_id,s,io);

receive_and_handle_dynamic_linker_message s=:{static_application_as_client} io
	#! (timeout,client_id,request_name)
		= ReceiveReqWithTimeOutE static_application_as_client;
	| timeout
		= (s,io);

	#! s = { s & static_application_as_client = False };
	#! requests = filter (\(_,name,_) -> (fst (starts name request_name))) RequestList;
	| (length requests) == 1
		// extract arguments and execute request
		#! request = hd requests;
		#! request_args
			= case (fst3 request) of {
				True
					-> tl (ExtractArguments '\n' 0 request_name []);
				False
					#! index = size (snd3 request);
					-> [request_name % (index, size request_name - 1)];
			};
		
		// do request
		#! (remove_state,client_id,s,io)
			= (thd3 (hd requests)) client_id request_args s io;
		= handle_request_result dummy dummy_ignore_arg (remove_state,client_id,s,io);
			
		= (s,io);
where {
	AddAndInitPC1_ client_id args s io
		#! (x,t)
			= AddAndInitPC_ client_id args s io;
		= t;
		
	// If requests have common prefixes, then the first request with the common prefix is used.
	RequestList
		= [
			// eagerly linked applications
			(True,"AddAndInit",AddAndInitPC1_)
			// compute address descriptor table using the descriptor usage set
		,	(False,"Compute2DescAddressTable",LinkPartition)
			// get address of the graph to string function
		,	(False,"GetGraphToStringFunction",HandleGetGraphToStringMessage)
			// closing client
		,	(True,"Close",Close)
			// general
		,	(True,"Quit",Quit)
			// send by second or later instance of dynamic rts to first instance of dynamic rts
		,	(False,"MessageFromSecondOrLaterLinker",MessageFromSecondOrLaterLinker_ (\_ s io -> (s,io)) )
			// send to get extra dynamic rts information
		,	(False,"GetDynamicRTSInfo",HandleGetDynamicRTSInfoMessage)
			// Get Type definitions
		,	(True,"LibInit",LoadApplication)		
			// dumpDynamic is the caller
		,	(False,"DumpDynamic",DumpDynamic)		
			// adding addresses
		,	(False,"GetLabelAddresses",GetLabelAddresses)
			// register lazy dynamic
		,	(False,"RegisterLazyDynamic",HandleRegisterLazyDynamicMessage)
			// dumpDynamic is the caller
		,	(False,"GetDynamicLinkerDir",GetDynamicLinkerDir)
		];
}

	any_clients_left (s=:{quit_server},io)
		// update window
		#! (no_more_clients,s)
			= acc_dl_client_states is_empty s;
		#! (static_application_as_client,s)
			= s!static_application_as_client;
		| (not no_more_clients || static_application_as_client) && (not quit_server)
			= (s,io);
			= ({ s & quit_server = True},io);

	where {
		is_empty []
			= (True,[]);
		is_empty l
			= (False,l);
	};

handle_request_result :: !.(*DLServerState -> .(.a -> *(*DLServerState,.b))) .(*DLClientState -> .(*DLServerState -> .(.b -> *(*DLServerState,.b)))) !*(!.Bool,!ProcessSerialNumber,!*DLServerState,.a) -> *(*DLServerState,.b);
handle_request_result callback_before_remove_dl_client_state callback_after_remove_dl_client_state (remove_state,client_id,s,io)
	// platform independent ...; check for errors
	#! ((messages,ok),s)
		= selacc_app_linker_state client_id get_error_and_messages s;
		
	// update client windows	
	// als window nog niet geopened, dan openen
	#! (s,io)
		= callback_before_remove_dl_client_state s io;

	// remove client if necessary
	#! (s,io)
		= case remove_state of {
			True
				#! (_,removed_dl_client_state,s)
					= RemoveFromDLServerState client_id s;
				#! (s,io)
					= callback_after_remove_dl_client_state removed_dl_client_state s io;
				-> (s,io);
			False
				-> (s,io);
		};
		
	// check for error fatal for client application
	| not ok
		# io
			= abort ("!kk"  +++ (pr_linker_message messages "")) //KillClient2 client_id io;
		= (s,io);
		
		= (s,io);
where {	
	get_error_and_messages state 
		#! (messages,state)
			= GetLinkerMessages state;		
		#! (ok,state)
			= IsErrorOccured state;
		= ((messages,ok),state);

	pr_linker_message [] s
		= s;
	pr_linker_message [LinkerError x:xs] s
		# new_s = "LinkerError:\t " +++ x +++ "\n";
		= pr_linker_message xs (s +++ new_s);
	pr_linker_message [LinkerWarning x:xs] s
		# new_s = "LinkerWarning:\t " +++ x  +++ "\n";
		= pr_linker_message xs (s +++ new_s);
	pr_linker_message [Verbose x:xs] s
		# new_s = "Verbose:\t " +++ x  +++ "\n";
		= pr_linker_message xs (s +++ new_s);
} // HandleRequestResult
