module Receiver;
import StdClass,StdArray,StdBool,StdInt, StdList;
import deltaDialog, deltaIOSystem, deltaWindow, deltaIOState, StdString, StdChar;

import memory, appleevents;

// Server; dynamic linker
import StdEnv;

import deltaEventIO, deltaPicture, deltaIOState;

from ioState import IOStateChangeToolbox, IOStateAccessToolbox;
from events import kHighLevelEvent;
import highleveleventDef;

import mac_types;
import ioState;

import ExtLibrary;
import pointer;
import DebugUtilities;

import ExtString;
import LinkerMessages;

import State;
//import PmDynamic;
//import states;
import DLState;

// IOState

from files import LaunchApplication;

//import PmProject;

//import main;

Start world
	# (s,world)
		= StartIO iosystem state initial_io world;
	= world;
where {
	iosystem
		= 	[	// WindowSystem
				MenuSystem	[file_menu,receiver_menu]
			,	HighLevelEventSystem [boff_highlevelevent]
			,	SystemDependentDevices
		];
		
	// MenuSystem	
	file_menu 
		=	PullDownMenu 1 "File" Able [
				MenuItem 13 "Quit"	(Key 'Q') Able (\s io -> (s,QuitIO io))
			];
			
	receiver_menu
		= 	PullDownMenu 2 "Receiver" Able [];
		

	// HighLevelEventSystem
	boff_highlevelevent
		= HighLevelEvent "boff" 
			[
				(AddClient,AddClientRequest)
			,	(AddLabel,AddLabelRequest)
			,	(Init,InitRequest)
			,	(Quit,QuitRequest)
			,	(Close,CloseRequest)
			,	(AddAndInit,AddAndInitRequest)
			,	(AddDescriptors,AddDescriptorsRequest)
			,	("cmd1",dummy_request)
			];

error msg s io
	#! (_,s,io)
		= OpenNotice (Notice ["Receiver (fatal error): cmd1-event has been received", msg] (NoticeButton 0 "Ok") []) s io;
	= (s,QuitIO io);

// used to test for dynamic linker presence
dummy_request s io
	= (s,io);	
	
// eagerly linked application
AddAndInitRequest s io
	#! (ok,error2,session_ref_number,io)
		= GetHighLevelEventData io;
	| not ok
		= error error2 s io;
		
	#! (oserr,io)
		= IOStateAccessToolbox (ASyncSend "boff" "" session_ref_number receiverIDisSessionID) io;
	
	#! (_,s,io)
		= OpenNotice (Notice ["Receiver: AddAndInitRequest-event has been received", error2] (NoticeButton 0 "Ok") []) s io;		
	= (s,io);
			
initial_io
	= [];
		
	state 
		= DefaultDLServerState;
};

AddClientRequest s io
	#! (_,s,io)
		= OpenNotice (Notice ["Receiver: AddClientRequest-event sent by another application cannot yet be process", 
		   					  "Drop instead the project file on the dynamic linker"] (NoticeButton 0 "Ok") []) s io;		
	= (s,io);
	
AddLabelRequest s io
	= abort "AddLabelRequest";
	
InitRequest s io
	= abort "InitRequest";

QuitRequest s io
	= abort "QuitRequest";
	
CloseRequest s io
	= abort "CloseRequest";

// argument is stringtable produced by the conversion functions
AddDescriptorsRequest s io
	= abort "AddDescriptorsRequest";
	
	SystemDependentDevices
		=	AppleEventSystem {openHandler =openHandler, quitHandler = quitHandler, clipboardChangedHandler =clipboardChangedHandler, scriptHandler = scriptHandler};
	where {
	 	openHandler n s io
	 		# (s,io)
	 			= report_error (add_client_request n) s io;
	 		= (s,io);
	 		
		quitHandler s io
			= (s,io); //QuitIO io);
			
		scriptHandler _ s io
			= (s,io);
			
		clipboardChangedHandler s io
			= (s,io);
		
			
	
	/*
			openHandler :: (String -> s -> *(io -> (s,io))),
		quitHandler :: (s -> *(io -> (s,io))),
		scriptHandler :: (String -> s -> *(io -> (s,io))),
		clipboardChangedHandler :: (s -> *(io -> (s,io)))
	*/
	} // SystemDependentDevices

report_error request_function dl_state io
	#! (dl_state,io)
		= request_function dl_state io;
	#! (states,dl_state)
		= accStates (\states -> (states,DefaultStates)) dl_state;
		
	// check for errors
	#! (_,state,states)
		= RemoveState client_id states;
	# (messages,state)
		= st_getLinkerMessages state;
		
	#! (_,dl_state,io)
		= case messages of {
			[]
				-> (0,dl_state,io);
			_
				-> OpenNotice (Notice messages (NoticeButton 0 "Ok") []) dl_state io;
		};
	#! (ok,state)
		= st_isLinkerErrorOccured state;
	| not ok
		= abort "DynamicLinker(PROCESS): stopped because of error";
		
	// remove state if necessary
	#! states
		= case dl_state.remove_state of {
			True
				-> states;
			False
				-> AddState client_id state states;
		};
		
	#! dl_state
		= { dl_state &
			states 	= states
		};
	= (dl_state,io);

	
client_id
	= 1;	
	
add_client_request project_name dl_state io
	#! (world,io)
		= IOStateGetWorld io;
	#! ((dl_state,io),world)
		= accFiles (add_client_request2 project_name dl_state io) world;
	#! io
		= IOStateSetWorld world io;
	= (dl_state,io);
			
add_client_request2 project_name dl_state io files
	// temporary
//	#! (_,dl_state,io)
//		= OpenNotice (Notice ["Receiver: AddClientRequest" +++ project_name] (NoticeButton 0 "Ok") []) dl_state io;
		
	// mac specific
	#! server_state
		= EmptyServerState;
	#! state
		= EmptyState;
	#! states
		= [];
	#! application_path
		= "";
				
	// read projectfile to start client
	| not ((ends project_name ".prj") ||  (ends project_name ".PRJ"))
		#! message
			= "The file " +++ project_name +++ " is not a valid project";
		#! dl_state
			= { dl_state &
				remove_state	= True
			,	server_state	= server_state
			,	states			= AddState client_id (st_addLinkerMessage (LinkerError message) state) states
			};
		= ((dl_state,io),files);
		
/*
	// IDE 2.0
	#! ((project,ok,error),files)
		= ReadProjectFile project_name application_path files;
	#! (project_static_info,project)
		= getStaticInfo project;
	#! projectdir
		= project_static_info.stat_prj_path;
	#! dynamic_linker_node 
		= { EmptyDynamicLinkerNode &
			project	= project,
			project_name = project_name
		};
	#! (_,dl_state,io)
		= OpenNotice (Notice ["Receiver: AddClientRequest" +++ projectdir] (NoticeButton 0 "Ok") []) dl_state io;
*/

	// IDE 1.3.3
	#! dynamic_linker_node 
		= EmptyDynamicLinkerNode;

	// general
	#! state
		= { EmptyState &
			dynamic_linker_node = dynamic_linker_node
		};
		
	// start client
	#! (toolbox,io)
		= IOStateGetToolbox io;
	// launch client foreground application
	#! (launch_error,toolbox)
		= LaunchApplication "www:Linkers:dynamic:mac:SendReceiveTest:client:client" 0xC8000000 toolbox;

	#! io
		= IOStateSetToolbox toolbox io;
	| launch_error >= 0
		// no error e.g. server started
		#! (_,dl_state,io)
			= OpenNotice (Notice ["Receiver: AddClientRequest; client started"] (NoticeButton 0 "Ok") []) dl_state io;
		= ((dl_state,io),files);
		
		#! (_,dl_state,io)
			= OpenNotice (Notice ["Receiver: AddClientRequest; client *not* started"] (NoticeButton 0 "Ok") []) dl_state io;
		= ((dl_state,io),files);
		
//		= abort "client started";
//		= abort "client not started";
		
	/*
	instance ToolboxAccess (IOState s)
where {
	GetToolBox io
		= IOStateGetToolbox io;
		
	PutToolBox toolbox io
		= IOStateSetToolbox toolbox io;
};

	*/
		
		
//	= ((dl_state,io),files);

/*	
// Dynamic Linker State
:: *DLState 
	= { 
		server_state	:: !ServerState
	,	states			:: !*States
	,	remove_state	:: !Bool
	};
	
DefaultDLState
	= { DLState |
		server_state	= EmptyServerState
	,	states			= []
	,	remove_state	= False	
	};
	
accStates f dl_state=:{states}
	#! (x,states)
		= f states
	= (x,{dl_state & states = states});
*/
	