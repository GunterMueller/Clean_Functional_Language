module DynamicLinker2;

// StdEnv
import StdEnv;

// Dynamic Linker
import DLState;
import Request;

// static Linker
import State;
import LinkerMessages;

// utilities; linkers
import ExtFile;
import ExtString;

// utilities; IDE 1.3
from EdMyIO import GetFullApplicationPath;

// utilities; macOS
import pointer;


// Append
// IO 0.8.1
/*

				(AddClientID,		\s io -> HandleRequestResult (PreprocessRequest AddClient s io))
			,	(AddLabelID,		\s io -> HandleRequestResult (PreprocessRequest AddLabel s io))
			,	(InitID,			\s io -> HandleRequestResult (PreprocessRequest Init s io))
			,	(QuitID,			\s io -> HandleRequestResult (PreprocessRequest Quit s io))
//
//			,	(QuitID				\s io -> HandleRequestResult (PreprocessRequest Close s io))
			,	(CloseID,			\s io -> HandleRequestResult (PreprocessRequest Close s io))
			,	(AddAndInitID,		\s io -> HandleRequestResult (PreprocessRequest AddAndInit s io))
			,	(AddDescriptorsID,	
*/
from ExtLibrary import AddClientID,AddLabelID,InitID,QuitID,CloseID,AddAndInitID,AddDescriptorsID,GetHighLevelEventData,ToolboxAccess;
/*
import deltaDialog, deltaIOSystem, deltaWindow, deltaIOState, StdString, StdChar;
import deltaEventIO, deltaPicture, deltaIOState;
*/

from ioState import IOStateChangeToolbox, IOStateAccessToolbox;
from events import kHighLevelEvent;
import highleveleventDef;

import mac_types;
//import ioState;
import memory, appleevents;

// debug
import DebugUtilities;

from deltaEventIO import StartIO,InitialIO,QuitIO;

/*
	Resources:
	
	add/change the following resources:
	- BNDL
		create a bundle-resource by selecting Resource and then Create New File Type. As its
		signature use boff. Then select Create New File Type and add the TEXT-type
	- SIZE
		set the following flags:
			can background
			32 bit compatible
			highlevel-event aware
			Local and remote highlevents
			Accept app die events
	- From the file-menu select Get info for DynamicLinker2. Fill Creator with boff (you should
	  type bof, go back with the cursor one character and add another f to avoid the needless
	  complaining of ResEdit. In the Finder Flags should Has BNDL be set
*/
from ExtLibrary import fourCharsToInt;

Start world
//	= hex_int (fourCharsToInt "psn ");
	# (s,world)
		= StartIO iosystem start_state initial_io world;
	= world;
where {		
	iosystem 
		= [
			MenuSystem	[file_menu,dynamic_linker_menu]
		,	HighLevelEventSystem [boff_highlevelevent]
		,	system_dependent_device
//		,	timer
		];

	// MenuSystem	
	file_menu 
		=	PullDownMenu 1 "File" Able [
				MenuItem 13 "Quit"	(Key 'Q') Able (\s io -> (s,QuitIO io))
			];
			
	dynamic_linker_menu
		= 	PullDownMenu 2 "DynamicLinker13" Able [];
		
	// HighLevelEventSystem
	boff_highlevelevent
		= HighLevelEvent "boff" 
			[
			// test
				(InitID,			\s io -> HandleRequestResult (PreprocessRequest Init s io))

		/*
				(AddClientID,		\s io -> HandleRequestResult (PreprocessRequest AddClient s io))
			,	(AddLabelID,		\s io -> HandleRequestResult (PreprocessRequest AddLabel s io))
			,	(InitID,			\s io -> HandleRequestResult (PreprocessRequest Init s io))
			,	(QuitID,			\s io -> HandleRequestResult (PreprocessRequest Quit s io))
//
//			,	(QuitID				\s io -> HandleRequestResult (PreprocessRequest Close s io))
			,	(CloseID,			\s io -> HandleRequestResult (PreprocessRequest Close s io))
			,	(AddAndInitID,		\s io -> HandleRequestResult (PreprocessRequest AddAndInit s io))
			,	(AddDescriptorsID,	\s io -> HandleRequestResult (PreprocessRequest AddDescriptors s io))
		*/
			];

	system_dependent_device
		=	AppleEventSystem {openHandler =openHandler, quitHandler = quitHandler, clipboardChangedHandler =clipboardChangedHandler, scriptHandler = scriptHandler, appdiedHandler = appdiedHandler};
	where {
	 	openHandler project_name s io
			// lazy link the dropped project
			#! (s,io)
				= HandleRequestResult (AddClient DefaultProcessSerialNumber [project_name] s io);
			= (s,io);
/*
			#! io
				= wait_for_high_level_event io;
			#! (ok,error,_,io)
				= GetHighLevelEventData io;
			| F (toString ok +++ " error: " +++ error) ok 
				= abort "openHandler: ok";
	
				= abort "openHandler: not ok";
*/			


		quitHandler s io
			= (s,io); //QuitIO io);
			
		scriptHandler _ s io
			= (s,io);
			
		appdiedHandler psn_string s io
//			| F ("(appdiedHandler) s_psn_string: " +++ toString (size psn_string)) True
			// an application has been closed
			#! highLongOfPSN
				= FromStringToInt psn_string 0;
			#! lowLongOfPSN
				= FromStringToInt psn_string 4;
			#! client_id
				= CreateProcessSerialNumber highLongOfPSN lowLongOfPSN;
			
			// a dynamically linked Clean application?
			#! (client_exists,dl_client_state,s)
				= RemoveFromDLServerState client_id s;
			| not client_exists
				= (s,io);
				
			// remove client as active application
			#! s 	
				= AddToDLServerState dl_client_state s;
			#! (s,io)
				= HandleRequestResult (Close client_id [] s io);
			= (s,io);


/*
Close client_id _ s=:{application_path} io

			,	(CloseID,			\s io -> HandleRequestResult (PreprocessRequest Close s io))
*/				
				
/*
			#! (client_exists,dl_client_state,s)
				= RemoveFromDLServerState client_id s;
			| not client_exists
			= abort ("DynamicLinker2: appdiedHandler; not existent" +++ toString lowLongOfPSN +++ " - high: " +++ toString highLongOfPSN);

			= abort "DynamicLinker2: appdiedHandler; exists";
*/
			
		clipboardChangedHandler s io
			= (s,io);
	} // system_dependent_device
	
	
/*
	timer
		= TimerSystem [Timer timer_id Able 1000 (\q s io -> /*any_clients_left (t2 q s io)*/ any_clients_left (s,io))];
	where {	
		
		any_clients_left (s=:{quit_server,global_client_window={visible_window_ids}},io)
			// update window
			#! (no_more_clients,s)
				= acc_dl_client_states is_empty s;
			#! (static_application_as_client,s)
				= s!static_application_as_client;
			| (not no_more_clients /*|| static_application_as_client*/ || (not (isEmpty visible_window_ids))) //&& (not quit_server)
				=(s,io);
				
		//		= (s,io);
				
				= (s,QuitIO io);	
		where {
			is_empty []
				= (True,[]);
			is_empty l
				= (False,l);
		
		}	
	} // timer
*/
		
	start_state 
		= DefaultDLServerState;
		
	initial_io
		= [
			init_io
//		,	system_dependent_initial_io
		];
	where {
		init_io s io
			// read environment
			#! (application_path,io)
				= accFiles GetFullApplicationPath io;
				
// DISABLED environments
//			#! (ok,targets,io)
//				= openTargets (application_path +++ (toString path_separator) +++ "IDEEnvs") io;
//			| not ok
//				= abort "could not read IDEEnvs";
				
			#! s
				= { s &
					application_path				= application_path
//				,	targets							= targets
				};
			= F "initial_io: environments disabled" (s,io);	

	} // intial_io	



} // Start

/*
PreprocessRequestInit f s io
	#! (ok,error,_,psn,io)
		= GetHighLevelEventData io;
	| size error <> 0
		= abort "PreprocessRequest: request with arguments are not yet implemented";
	= f psn [] s io;
*/

// format: n_args offset1 ... offsetN data1 ... dataN
PreprocessRequest f s io
	#! (ok,data,_,psn,io)
		= GetHighLevelEventData io;
	| size data <> 0
		#! n_args
			= FromStringToInt data 0;
		#! args
			= extract_args 0 n_args data ;
		= f psn /*[]*/ args s io;

	//	= abort ("PreprocessRequest: request with arguments are not yet implemented" +++ (toString (size data)));
	= f psn []  s io;
where {
//	test
//		= (FromIntToString 2) +++ (FromIntToString 12) +++ (FromIntToString 20) +++ (FromIntToString 1) +++ (FromIntToString 1) +++ (FromIntToString 1);
	// i loopt 1 achter 
	extract_args i n_args data 
		| i == n_args
			= [];
			
			#! i_start
				= FromStringToInt data ((i + 1) << 2); //(data.[i+1]);
			#! i_end
				= dec (if (i + 2 > n_args) (size data) (FromStringToInt data ((i + 2) << 2))); //(data.[i + 2])));
			= [ data % (i_start,i_end) : extract_args (inc i) n_args data ];
	
/*	
			| F (toString i_start +++ " - " +++ toString i_end) True
				= extract_args (inc i) n_args data;
*/			
			
			
} // PreprocessRequest
		
// AddClient :: !ProcessSerialNumber ![!String] !*DLServerState !(IOState !*DLServerState) -> !(!Bool,!ProcessSerialNumber,!*DLServerState, !(IOState !*DLServerState));
