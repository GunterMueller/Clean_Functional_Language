implementation module pdRequest;

import StdEnv;

// utilities; linkers
import ExtFile;
from ExtLibrary import NoErr;

// utilities; power mac interface
//import ioState;
//import files; 
from files import LaunchApplicationFSSpec2, FSMakeFSSpec, Toolbox;
from deltaEventIO import IOState;
// linkers
import DLState;
//IsEmptyList

from ioState import IOStateGetToolbox, IOStateSetToolbox;

import DebugUtilities;

// AddClient
ExtractProjectPathName :: !String -> !String;
ExtractProjectPathName prjname
	= fst (ExtractPathFileAndExtension prjname);
	
GetShortPathName2 :: !String -> !(!Bool,!String);
GetShortPathName2 s 
	= (True,s);
	
StartClientApplication :: !*DLClientState !*DLServerState !*(IOState !*DLServerState) -> *(!.Bool,!ProcessSerialNumber,{#Char},!*DLClientState,!*DLServerState,!*(IOState !*DLServerState));
StartClientApplication dl_client_state s io
	// client file name
	#! file_name
	//	= "Clean:Linkers:C source:mac:LazyClientConsole:ANSI C Console PPC";
		= "Clean:Linkers:C source:mac:LazyClientConsole:Dumm:ToolboxPPC";
				
	// start client
	#! (toolbox,io)
		= IOStateGetToolbox io;
	#! (os_err,fs_spec,toolbox)
		= FSMakeFSSpec file_name toolbox;
	| os_err <> NoErr
		#! io
			= IOStateSetToolbox toolbox io;
		= abort ("not ok" +++ toString os_err);

	#! (launch_error,highLongOfPSN,lowLongOfPSN,toolbox)
		= LaunchApplicationFSSpec2 fs_spec /*0xC8000000*/ 0x00004880 toolbox;
	#! io
		= IOStateSetToolbox toolbox io;
	| F ("high: " +++ toString highLongOfPSN +++ " low: " +++ toString lowLongOfPSN ) launch_error < 0
		// error
		= abort "not ok";
		
		#! process_serial_number
			= CreateProcessSerialNumber highLongOfPSN lowLongOfPSN;
		= (True,process_serial_number,file_name,dl_client_state,s,io);

from memory import DisposPtr, Ptr;		
CloseClient :: !*DLClientState !*(IOState !*DLServerState) -> (!*DLClientState,!*(IOState !*DLServerState));
CloseClient dl_client_state io
	#! (pointers,dl_client_state)
		= acc_pd_state (\pd_state=:{pointers} -> (pointers,pd_state)) dl_client_state;
		
	#! (toolbox,io)
		= IOStateGetToolbox io;
	#! toolbox
		= foldl (\toolbox pointer -> snd (DisposPtr pointer toolbox) ) toolbox pointers;
	#! io
		= IOStateSetToolbox toolbox io;
	= (dl_client_state,io);
