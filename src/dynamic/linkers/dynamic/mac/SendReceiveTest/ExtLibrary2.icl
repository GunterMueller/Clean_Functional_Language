implementation module ExtLibrary;

import StdArray;
from StdString import String;
from StdClass import <>, ==;
from StdInt import toInt, <<, bitor;
from StdBool import not;
from StdMisc import abort;
import StdEnv;

import mac_types;
import memory,pointer;
import events;

import ProcessSerialNumber;

import DebugUtilities;
import process;

from deltaEventIO import highlevelEventMask;

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
fourCharsToInt s
	| size s <> 4
		= abort "fourCharsToInt";
		= ((toInt s.[0]) << 24) bitor ((toInt s.[1]) << 16) bitor ((toInt s.[2]) << 8) bitor (toInt s.[3]);
		
// extended macOS interface

// Application signatures
SignatureAppl				:== 0x4150504c;				// 'APPL'

// Apple Events; descriptor types
TypeProcessSerialNumber		:== 0x70736e20;				// 'psn '

// postingOptions
receiverIDisSessionID	:==	0x00006000;
receiverIDisSignature	:== 0x00007000;
receiverIDisPSN			:== 0x00008000;

// Result codes
NoErr						:== 0;
BufferIsSmall				:== -607;
NoOutstandingHLE			:== -608;
ConnectionInvalid			:== (-609);
NoUserInteractionAllowed	:== (-610);
SessionClosedErr			:== (-917);

// OS Functions
PostHighLevelEvent :: !(!Int,!Int,!Int,!Int,!Int) !Int !Int !Int !Int !Int !*Toolbox -> (!Int,!*Toolbox);
PostHighLevelEvent (what,message,when,position,modifiers) receiverID msgRefcon msgBuff msgLen postingOptions t
	= code (modifiers=W,position=L,when=L,message=L,what=W,
	receiverID=O0D0D1,msgRefcon=D2,msgBuff=D3,msgLen=D4,postingOptions=D5,t=U)(r=I16D0,z=Z) {
		call .PostHighLevelEvent
	};


PostHighLevelEventPSN :: !(!Int,!Int,!Int,!Int,!Int) !(!Int,!Int) !Int !Int !Int !Int !*Toolbox -> (!Int,!*Toolbox);
PostHighLevelEventPSN (what,message,when,position,modifiers) (lowLongOfPSN,highLongOfPSN) msgRefcon msgBuff msgLen postingOptions t
	= code (modifiers=W,position=L,when=L,message=L,what=W,
			lowLongOfPSN=O0D0L,highLongOfPSN=L,
			msgRefcon=O0D1D2,msgBuff=D3,msgLen=D4,postingOptions=D5,t=U)(r=I24D0,z=Z) {
		call .PostHighLevelEvent
	};
	

	
AcceptHighLevelEvent :: !Int !Int !Int !Int !*Toolbox -> (!Int,!*Toolbox);
AcceptHighLevelEvent sender msgRefCon msgBuff msgLen t
	= code (sender=D0,msgRefCon=D1,msgBuff=D2,msgLen=D3,t=U)(r=D0,z=Z) {
		call .AcceptHighLevelEvent
	};
	
// LaunchApplication
LaunchApplication2 :: !Int !*Toolbox -> (!Int,!*Toolbox);
LaunchApplication2 launch_pb_ptr t
	= code (launch_pb_ptr=D0,t=U)(r=D0,z=Z) {
		call .LaunchApplication 
	};
		
// OS Datastructures
/*
	myRecvID
		= fourCharsToInt "boff";
	myOpts

*/
// (event_what,event_class,10,event_where,30);

class ToRecvID a
where {
	PostHLEvent :: !(!Int,!Int,!Int,!Int,!Int) !a !Int !Int !Int !Int !*Toolbox -> !(!Int,!*Toolbox)
	
//	ToRecvID :: !a -> !Int
};

instance ToRecvID !{#Char}
where {
	PostHLEvent event_record myRecvID msg_ref_con msgBuff msgLen myOpts toolbox
		= PostHighLevelEvent event_record (ToRecvID myRecvID) 0 msgBuff msgLen myOpts toolbox;
	where {
		ToRecvID :: !{#Char} -> !Int;
		ToRecvID s 
			| size s == 4
				= fourCharsToInt s;
	}
};

instance ToRecvID Int
where {
	PostHLEvent event_record myRecvID msg_ref_con msgBuff msgLen myOpts toolbox
		= PostHighLevelEvent event_record myRecvID 0 msgBuff msgLen myOpts toolbox;
};


instance ToRecvID !ProcessSerialNumber
where {
	PostHLEvent event_record psn msg_ref_con msgBuff msgLen myOpts toolbox
		#! system_psn
			= GetSystemRepresentationOfPSN psn;
		#! (os_err,toolbox)
			=  PostHighLevelEventPSN event_record system_psn 0 msgBuff msgLen (myOpts bitor receiverIDisPSN) toolbox;
		= F "sent" (os_err,toolbox);
};

/*
instance ToRecvID !{#Char}
where {
	ToRecvID :: !{#Char} -> !Int;
	ToRecvID s 
		| size s == 4
			= fourCharsToInt s;
};

instance ToRecvID Int
where { 
	= P
/*
	ToRecvID :: !Int -> Int;
	ToRecvID i
		= i;
*/
};
*/

/*
/*
	#! (oserr,toolbox)
		= PostHighLevelEvent event_record (ToRecvID myRecvID) 0 msgBuff msgLen myOpts toolbox;
*/
	#! (oserr,toolbox)
		= PostHLEvent event_record myRecvID 0 msgBuff msgLen myOpts toolbox;
	
*/


// Auxillary functions; used by dynamic linker and its clients
/*
	To be done:
	
	- deallocate buffer

*/
ASyncSend :: .String {#.Char} a .Int *Toolbox -> (Int,.Toolbox) | ToRecvID a;
ASyncSend event_where2 data myRecvID myOpts toolbox
	// allocate and fill buffer with data, if necessary
	#! s_data
		= size data;
	#! (msgBuff,msgLen,toolbox)
		= case s_data of {
			0
				-> (0,0,toolbox);
				
			// test
			_
				// allocate buffer for data
				#! msgLen
					= 4 + s_data;
				#! (msgBuff_ptr,oserr,toolbox)
					= NewPtr msgLen toolbox;
				| oserr <> 0
					-> abort "SyncSend (fatal error): could not allocate memory";
					
				// fill buffer
				#! toolbox
					= StoreLong msgBuff_ptr s_data toolbox;
				#! (_,toolbox)
					= copy_string_slice_to_memory data 0 s_data (msgBuff_ptr + 4) toolbox;
				-> (msgBuff_ptr + 4,s_data,toolbox);
		};
	
			
	// post event 
/*
	#! (oserr,toolbox)
		= PostHighLevelEvent event_record (ToRecvID myRecvID) 0 msgBuff msgLen myOpts toolbox;
*/
	#! (oserr,toolbox)
		= PostHLEvent event_record myRecvID 0 msgBuff msgLen myOpts toolbox;
		
	#! (os_err,toolbox)
		= case oserr of { 
			ConnectionInvalid
				-> abort "ASyncSend: could not connect to server";
			NoUserInteractionAllowed
				-> abort "noUserInteractionAllowed";
			SessionClosedErr
				-> abort "sessionClosedErr";
			NoErr
				-> (oserr,toolbox);
			i
				-> abort ("error: " +++ toString i);
		};
	
/*	
	// deallocate buffer
	#! (os_err,toolbox)
		= case s_data of {
			0
				-> (NoErr,toolbox);
			_
				-> DisposPtr msgBuff toolbox;
		};
*/
	= (os_err,toolbox);
where {
	event_record 
		= (event_what,event_class,10,event_where,30);
	where {
		event_what
			= kHighLevelEvent;
		event_class
			= fourCharsToInt "boff";
		event_where
			= fourCharsToInt event_where2;
	}
}		

class ToolboxAccess a
where {
	GetToolBox :: !*a -> (!*Toolbox,!*a);
	PutToolBox :: !*Toolbox !*a -> !*a
};

instance ToolboxAccess Int
where {
//	GetToolBox :: !*Int -> *(!*Int,!*Int);
	GetToolBox toolbox
		= (toolbox,0);
		
	PutToolBox toolbox _
		= toolbox;
};
import ioState;

instance ToolboxAccess (IOState s)
where {
	GetToolBox io
		= IOStateGetToolbox io;
		
	PutToolBox toolbox io
		= IOStateSetToolbox toolbox io;
};

GetHighLevelEventData :: *a -> *(.Bool,{#Char},Int,!ProcessSerialNumber,*a) | ToolboxAccess a;
GetHighLevelEventData s //toolbox
	#! (toolbox,s)
		= GetToolBox s;
	#! (allocated_ptrs,ok,error,session_reference_number,psn,toolbox)
		= GetHighLevelEventData2 toolbox;
	#! s
		= PutToolBox toolbox s;
		
	// deallocate pointers
//	#! (all_ptrs_deallocated,toolbox)
//		= foldl dispose_ptr (True,toolbox) allocated_ptrs;
	| not ok 
		= (ok,error,session_reference_number,psn,s);
//	| not all_ptrs_deallocated
//		= (False,"GetHighLevelEvent: not all pointers deallocated",session_reference_number,s);
		
		= (ok,error,session_reference_number,psn,s);
where {
	dispose_ptr (False,toolbox) ptr
		= (False,toolbox);
	dispose_ptr (_,toolbox)  ptr 
		#! (oserr,toolbox)
			= DisposPtr ptr toolbox;
		| oserr == 0
			= (True,toolbox);
			= (False,toolbox); 
}

GetProcessSerialNumberFromPortName :: !Int !*Toolbox -> (!Int,!Int,!Int,!*Toolbox);
GetProcessSerialNumberFromPortName ppc_port_ptr t
	= code (ppc_port_ptr=D0,t=R8O0D1U)(result=D0,highLongOfPSN=L,lowLongOfPSN=L,z=Z) {
		call .GetProcessSerialNumberFromPortName
	};


// TargetID structure:
TargetID_sessionID	:== 0;
TargetID_name		:== 4;
TargetID_location	:== 72;
TargetID_recvrName	:== 106;
		
GetHighLevelEventData2 toolbox
	#! allocated_ptrs
		= [];
		
	// allocate memory for TargetID-record
	#! s_target_id
		= 1000; //174;
	#! (ptr,oserr,toolbox)
		= NewPtr s_target_id toolbox;
	| oserr <> 0
		= (allocated_ptrs,False,"could not allocate memory for targetId",0,DefaultProcessSerialNumber,toolbox);
//	#! allocated_ptrs
//		= [ptr:allocated_ptrs];
		
	#! msgRefCon_ptr
		= ptr;
	// store zero length because buffer size is unknown
	#! msgLen_ptr
		= msgRefCon_ptr + 4;
	#! toolbox
		= StoreLong msgLen_ptr 0 toolbox;
	#! target_id_ptr 
		= msgLen_ptr + 4;
		
	// get buffer size 
	#! (oserr,toolbox)
		= AcceptHighLevelEvent target_id_ptr msgRefCon_ptr 0 msgLen_ptr toolbox;
//	| oserr <> NoErr
//		= abort ("?GetHighLevelEventData2: internal error (AcceptHighLevelEvent) " +++ toString oserr);

	// get session reference number
	#! (myRecvID,toolbox)
		= LoadLong target_id_ptr toolbox;
	
	// get process serial number
	#! (os_err,highLongOfPSN,lowLongOfPSN,toolbox)
		= GetProcessSerialNumberFromPortName (target_id_ptr + TargetID_name) toolbox;

	| os_err <> NoErr
		= abort ("!GetHighLevelEventData2: internal error" +++ (toString os_err) );
		
	#! psn 
		= CreateProcessSerialNumber highLongOfPSN lowLongOfPSN;


	#! (ok,error,toolbox)
		= case oserr of {
			NoErr
				// buffer of size 0
				-> (True,"",toolbox);
				//-> (False,"NoErr: cannot occur",toolbox);
			BufferIsSmall
				-> (True,"BufferIsSmall",toolbox);
			NoOutstandingHLE
				-> (False,"NoOutstandingHLE",toolbox);
		};
	| not ok || oserr == NoErr
		//
		= (allocated_ptrs,ok,error,myRecvID,psn,toolbox);
		
		
	// allocate & copy memory for data
	#! (s_buffer,toolbox)
		= LoadLong msgLen_ptr toolbox;
	#! (buffer_ptr,oserr,toolbox)
		= NewPtr s_buffer toolbox;
	| oserr <> 0
		= (allocated_ptrs,False,"could not allocate memory for buffer",0,psn,toolbox);	

//	#! allocated_ptrs
//		= [buffer_ptr:allocated_ptrs];
	#! (oserr,toolbox)
		= AcceptHighLevelEvent target_id_ptr msgRefCon_ptr buffer_ptr msgLen_ptr toolbox;
	| oserr <> NoErr
		= (allocated_ptrs,False,"BufferIsSmall or NoOutstandingHLE",0,psn,toolbox);
	
	// fill memory	
	#! (data,toolbox)
		= copy_memory_to_string buffer_ptr s_buffer (createArray s_buffer ' ') 0 toolbox;
		
	// deallocate 
	= (allocated_ptrs,True,data,myRecvID,psn,toolbox);
	
copy_memory_to_string buffer_ptr s_buffer dest index toolbox
	| s_buffer == index
		= (dest,toolbox);
		
		#! (byte,toolbox)
			= LoadByte buffer_ptr toolbox;
		= copy_memory_to_string (inc buffer_ptr) s_buffer {dest & [index] = (toChar byte)} (inc index) toolbox;
		
FindAProcess signature toolbox
	// allocate psi
	#! (p_psi,error,toolbox)
		= NewPtr (/*S_psi + */1000) toolbox;
	| error <> NoErr
		= abort ("FindAProcess (ExtLibrary): could not allocate psi" +++ toString error);
		
	// intialize psi
	#! toolbox
		= StoreLong (p_psi + ProcessInfoLength) S_psi toolbox;
	#! toolbox
		= StoreLong (p_psi + ProcessName) 0 toolbox;
	#! toolbox
		= StoreLong (p_psi + ProcessAppSpec) 0 toolbox;
		
	// search
	#! (found,toolbox)
		= find_a_process (KNoProcess,0) p_psi toolbox;
		
	// deallocate memory
	#! (_,toolbox)
		= DisposPtr p_psi toolbox;
// 	| error <> NoErr
// 		= abort ("FindAProcess (ExtLibrary): could not deallocate psi" +++ toString error);
 	= (found,toolbox)
where {
	find_a_process psn=:(lowLongOfPSN,highLongOfPSN) p_psi toolbox
		#! (os_err,psn2=:(next_highLongOfPSN,next_lowLongOfPSN),toolbox)
			= GetNextProcess psn toolbox;
		| os_err <> NoErr
			= (False,toolbox);
			
		// found; retrieve info in psi
		#! (os_err,toolbox)
			= GetProcessInformation (next_lowLongOfPSN,next_highLongOfPSN) p_psi toolbox;
		| os_err <> NoErr
			// internal error
			= abort "find_a_process (ExtLibrary): internal error; error during process informatial retrieval";
				
		// is this the searched process?
		#! (next_processType,toolbox)
			= LoadLong (p_psi + ProcessType) toolbox;
		#! (next_processSignature,toolbox)
			= LoadLong (p_psi + ProcessSignature) toolbox;
		| next_processType == SignatureAppl && next_processSignature == signature
			= (True,toolbox);
		= find_a_process (next_lowLongOfPSN,next_highLongOfPSN) p_psi toolbox;
} // FindAProcess


/*
GetSpecificHighLevelEvent :: !Int !Int !*Toolbox -> !(!Int,!Int,!*Toolbox);
GetSpecificHighLevelEvent a_filter data_ptr t
	= code (a_filter=D0,data_ptr=D1,t=R4O0D2U)(bool=D0,err=L,t2=Z) {
		call .GetSpecificHighLevelEvent
	}
	
MyHighLevelEventFilter :: 
*/

import code from "highlevelevents.obj";
import ExtInt;

AnyDynamicLinkerRequest :: !Int !*Toolbox -> !(!Bool,!String,!*Toolbox);
AnyDynamicLinkerRequest signature toolbox
	#! (quit_client,ok,os_err,buffer_p,buffer_len)
		= search_dynamic_linker_event signature;
	| quit_client
		= (False,"",ExitToShell toolbox);
		
	| os_err <> NoErr
		= abort ("AnyDynamicLinkerRequest 1; os_err: " +++ toString os_err);
		
	// no dynamic linker event found
	| not ok || buffer_len == 0
		= (ok,"",toolbox);
		
	// event found; get buffer contents	
	#! (data,toolbox)
		= copy_memory_to_string buffer_p buffer_len (createArray buffer_len ' ') 0 toolbox;
	#! (_,toolbox)
		= DisposPtr buffer_p toolbox;
	= (ok,data,toolbox);
//	= abort ("AnyDynamicLinkerRequest: meerdere bytes ontvangen:" +++ toString (size data) +++ " <" +++ data +++ ">"); //(ok,toolbox)

/*
/*
	= abort ("AnyDynamicLinkerRequest: " +++ toString ok);
	
*/	
//	| i <> 1
//		= abort ("meerdere hle's" +++ toString i);
	| F ("i=" +++ /* FromIntToString*/ toString  i) ok
		= (True,t); //abort "hebbes" (True,t);
		= (False,t);
*/
where {
	search_dynamic_linker_event :: !Int -> !(!Bool,!Bool,!Int,!Int,!Int);
	search_dynamic_linker_event signature
		= code {
			ccall search_dynamic_linker_event "I-IIIII"
		};

}

from desk import SystemTask;

wait_for_high_level_event :: !*Toolbox -> (!String,!*Toolbox);	
wait_for_high_level_event toolbox
	#! (found,toolbox)
		= FindAProcess dynamic_linker_signature toolbox;
	| not found
		// dynamic linker is killed; kill also this client application
		= ({},ExitToShell toolbox);
		
	// dynamic linker is present; intercept its events
	#! (event,toolbox)
		= GetEvent 0 toolbox;

	#! (is_a_dynamic_linker_request,data,toolbox)
		= AnyDynamicLinkerRequest dynamic_linker_signature toolbox;
	| is_a_dynamic_linker_request 
		= (data,toolbox);
	= wait_for_high_level_event toolbox;		
where {
	dynamic_linker_signature
		= fourCharsToInt "boff";
} // wait_for_high_level_event

