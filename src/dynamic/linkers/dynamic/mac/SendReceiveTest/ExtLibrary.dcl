definition module ExtLibrary;

from StdString import String;
import mac_types;
import ioState;
import ProcessSerialNumber;

// messages
AddClientID			:== "adcl";				// lazily linked client (by clicking on its projectfile); register application and run application stub on PC
AddLabelID			:== "adla";				// link a specified symbol
InitID				:== "init";				// lazily linked client; link & load application 
QuitID				:== "quit";				// quit the linker
CloseID				:== "clos";				// close client application
AddAndInitID		:== "adai";				// eagerly linked client
AddDescriptorsID	:== "ades";				// link descriptors by passing stringtable produced by the conversion functions
ConfirmID			:== "conf";				// confirmation request

// eventMask constants
HighLevelEventMask	:==	1024;

// General utilities
fourCharsToInt :: !String -> !Int;
		
// extended macOS interface
// Apple Events; descriptor types
TypeProcessSerialNumber		:== 0x70736e20;				// 'psn '

// postingOptions
receiverIDisSessionID	:==	0x00006000;
receiverIDisSignature	:== 0x00007000;

// Result codes
NoErr						:== 0;
BufferIsSmall				:== -607;
NoOutstandingHLE			:== -608;
ConnectionInvalid			:== (-609);
NoUserInteractionAllowed	:== (-610);
SessionClosedErr			:== (-917);

// OS Functions
PostHighLevelEvent :: !(!Int,!Int,!Int,!Int,!Int) !Int !Int !Int !Int !Int !*Toolbox -> (!Int,!*Toolbox);
AcceptHighLevelEvent :: !Int !Int !Int !Int !*Toolbox -> (!Int,!*Toolbox);
LaunchApplication2 :: !Int !*Toolbox -> (!Int,!*Toolbox);

// OS Datastructures


// Auxillary functions; used by dynamic linker and its clients
/*
class ToRecvID a
where {
	ToRecvID :: !a -> !Int
};
*/
class ToRecvID a
where {
	PostHLEvent :: !(!Int,!Int,!Int,!Int,!Int) !a !Int !Int !Int !Int !*Toolbox -> !(!Int,!*Toolbox)
	
//	ToRecvID :: !a -> !Int
};


instance ToRecvID !{#Char};
instance ToRecvID Int;
instance ToRecvID !ProcessSerialNumber;


// Auxillary functions; used by dynamic linker and its clients
ASyncSend :: .String {#.Char} a .Int *Toolbox -> (Int,.Toolbox) | ToRecvID a;

class ToolboxAccess a
where {
	GetToolBox :: !*a -> (!*Toolbox,!*a);
	PutToolBox :: !*Toolbox !*a -> !*a
};

instance ToolboxAccess Int;
instance ToolboxAccess (IOState s);
GetHighLevelEventData :: *a -> *(.Bool,{#Char},Int,!ProcessSerialNumber,*a) | ToolboxAccess a;

wait_for_high_level_event :: !*Toolbox -> (!String,!*Toolbox);	
