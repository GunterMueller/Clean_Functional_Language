implementation module pdRequest;

import StdEnv;
import DynamicLink;
import State;
import DLState;
import ExtFile;
import expand_8_3_names_in_path;
from DynID import DS_UTILITIES_DIR;
import ProcessSerialNumber;
import ExtString;
import pdSymbolTable;

// AddClient
ExtractProjectPathName :: !String -> String;
ExtractProjectPathName cmdline
	=  fst (ExtractPathFileAndExtension project_name);
where {
	parsed_command_line
		= ParseCommandLine cmdline;
		
	(_,project_name)
		= case (size parsed_command_line) of {
			1 	-> ("","");
			2	-> ("",parsed_command_line.[1]);
			3	-> (parsed_command_line.[1],parsed_command_line.[2]);
		};
}

StartClientApplication3 :: !String !String !.Bool !String !*DLServerState -> *(Bool,ProcessSerialNumber,{#Char},!*DLServerState);
StartClientApplication3 current_directory file_name open_console_window cmd_line_without_executable dl_server_state=:{application_path}
	#! client_executable
		= "\"" +++ application_path
			+++ "\\" +++ DS_UTILITIES_DIR +++
			(if open_console_window "\\ConsoleClient.exe" "\\GuiClient.exe") +++ "\"" +++ cmd_line_without_executable +++ "\0";

	#! (client_started,client_id)
		= StartProcess (current_directory +++ "\0\0\0\0") (file_name +++ "\0") client_executable
	| client_started == client_started

	= (client_started,CreateProcessSerialNumber client_id,("test " +++ toString (size cmd_line_without_executable) +++ " <" +++ client_executable +++ ">"),dl_server_state);

// Init
ParseCommandLine :: !String -> {#{#Char}};
ParseCommandLine s
	# command_line
		= parse_command_line s 0 [];
	# command_line
		= [expand_8_3_names_in_path (hd command_line):tl command_line];
	= { s \\ s <- command_line };
where {
	parse_command_line :: String Int [{#Char}] -> [{#Char}];
	parse_command_line s i l
		| i == (size s)
			= l;
			
			| (s.[i] <> '\"')
				// not found, no " then search for space
				#! (_,index)
					= CharIndex s i ' ';
				= parse_command_line s (skip_spaces s index) (l ++ [s % (i,index-1)]);
				
		
				#! (found,index)
					= CharIndex s (i+1) '\"';
				| found
					= parse_command_line s (skip_spaces s (index+1)) (l ++ [s % (i+1,index-1)]);
					
					= abort "parse_command_line: an error";
	skip_spaces :: String Int -> Int;
	skip_spaces s i
		| (size s) == i
			= size s;
			| s.[i] == ' '
				= skip_spaces s (inc i);	
				= i;
}

// AddAndInit
RemoveStaticClientLibrary :: !*State -> *State;
RemoveStaticClientLibrary state=:{n_libraries,library_list}
	#! (n_libraries,library_list)
		= remove_static_client_library library_list n_libraries;
	= { state &
		n_libraries = n_libraries,
		library_list = library_list
	};
where {
	remove_static_client_library EmptyLibraryList n_libraries
		= (n_libraries,EmptyLibraryList);
	remove_static_client_library (Library library_name i0 i1 i2 librarylists) n_libraries
		| library_name == "StaticClientChannel.dll"
			= remove_static_client_library librarylists (dec n_libraries);
			#! (n_libraries,librarylists)
				= remove_static_client_library librarylists n_libraries;
			= (n_libraries,Library library_name i0 i1 i2 librarylists);
}

// Close
CloseClient :: !*DLClientState -> *DLClientState;
CloseClient dl_client_state
	= dl_client_state;