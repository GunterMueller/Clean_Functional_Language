module Sender;

// client 
import StdEnv;

import deltaEventIO, deltaPicture, deltaIOState;

from ioState import IOStateChangeToolbox, IOStateAccessToolbox;
from events import kHighLevelEvent;

import mac_types;

import ExtLibrary;

Start world
	# (s,world)
		= StartIO iosystem state initial_io world;
	= world;
where {
	iosystem
		= 	[	
				MenuSystem	[file_menu]
			,	HighLevelEventSystem []
		];
		
	file_menu 
		=	PullDownMenu 1 "File" Able [
				MenuItem 14 "AddClient" NoKey Able (\s io -> (s,io))
			,	MenuI#tem 13 "Quit"	(Key 'Q') Able (\s io -> (s,QuitIO io))
			];
			
	initial_io
		= [ StartServerApplication ];
		
	state 
		= 1;
};

from files import LaunchApplication;
import ioState;

/*
	 first experiment: a lazy linked application
	 
// known messages:
AddClient		:== "adcl";				// lazily linked client (by clicking on its projectfile); register application and run application stub on PC
AddLabel		:== "adla";				// link a specified symbol
Init			:== "init";				// lazily linked client; link & load application 
Quit			:== "quit";				// quit the linker
Close			:== "clos";				// close client application
AddAndInit		:== "adai";				// eagerly linked client
AddDescriptors	:== "ades";				// link descriptors by passing stringtable produced by the conversion functions

The MAC dynamic linker can be used in the following two ways:
1) dropping of a project on the linker
   The linker reacts by creating a dummy process

2) eager linked application does an AddAndInit
*/

import DebugUtilities;

// ensure the server is running
StartServerApplication :: .s *(IOState *b) -> *(.s,*IOState *b);
StartServerApplication s io
	#! (oserr,io)
		= IOStateAccessToolbox (PostHighLevelEvent event_record myRecvID 0 0 0 myOpts) io;
	#! (os_err,io)
		= case oserr of { 
			ConnectionInvalid
				// no connection e.g. the server is not running
				#! (t,io)
					= IOStateGetToolbox io;
				#! (launch_error,t)
					= LaunchApplication "www:Linkers:dynamic:mac:SendReceiveTest:Receiver" 0xCA000000 t;
				#! io
					= IOStateSetToolbox t io;
				| launch_error >= 0
					// no error e.g. server started
					-> IOStateAccessToolbox (PostHighLevelEvent event_record myRecvID 0 0 0 myOpts) io;
		
					// error
					-> abort "TestPostHighLevelEvent: could not connect to server";

			NoUserInteractionAllowed
					-> abort "noUserInteractionAllowed";
			SessionClosedErr
					-> abort "sessionClosedErr";
			NoErr
					-> (oserr,io);
		};
	= (s,io);
where {
	event_record 
		= (event_what,event_class,10,event_where,30);
	where {
		event_what
			= kHighLevelEvent;
		event_class
			= fourCharsToInt "boff";
		event_where
			= fourCharsToInt "cmd1";
	}
	
	myRecvID
		= fourCharsToInt "boff";
	myOpts
		= receiverIDisSignature;
}