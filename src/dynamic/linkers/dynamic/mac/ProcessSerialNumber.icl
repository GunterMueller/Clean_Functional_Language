implementation module ProcessSerialNumber;

import
	StdEnv;
	
import
	process;
	
//import DebugUtilities;
	
from ioState import IOState;
	
:: ProcessSerialNumber = {
		lowLongOfPSN	:: !Int
	,	highLongOfPSN	:: !Int
	};
	
DefaultProcessSerialNumber :: !ProcessSerialNumber;
DefaultProcessSerialNumber 
	= { ProcessSerialNumber |
		lowLongOfPSN	= 2			// current process
	,	highLongOfPSN	= 0
	};
	
CreateProcessSerialNumber :: !Int !Int -> !ProcessSerialNumber;
CreateProcessSerialNumber highLongOfPSN lowLongOfPSN
//	#! s
//		= "high: " +++ toString highLongOfPSN +++ " - low: " +++ toString lowLongOfPSN;
// 	| F s True
	= { ProcessSerialNumber |
		lowLongOfPSN	= lowLongOfPSN
	,	highLongOfPSN	= highLongOfPSN
	};
			 
instance == ProcessSerialNumber
where {
	(==) {lowLongOfPSN=lowLongOfPSN1,highLongOfPSN=highLongOfPSN1} {lowLongOfPSN=lowLongOfPSN2,highLongOfPSN=highLongOfPSN2}
		#! toolbox
			= 0;
		#! (os_err,bool,toolbox)
			= SameProcess (lowLongOfPSN1,highLongOfPSN1) (lowLongOfPSN2,highLongOfPSN2) toolbox; 
		| os_err == toolbox
			= bool;
};

import appleevents;
from ExtLibrary import NoErr, TypeProcessSerialNumber;
from memory import NewPtr, DisposPtr;
from ExtInt import FromIntToString;

/*
	macOS does *not* allow other processes but itself to be killed. An approach
	to approximate this goal is to send an Apple Quit-event. The application is
	friendly asked to terminate itself. How an application reacts to this event
	is application specific.
	To complicate the matter further, not all applications can handle this
	event. They cannot be closed.
*/
KillClient2 :: !ProcessSerialNumber !(IOState s) -> !(IOState s);
KillClient2 psn=:{lowLongOfPSN,highLongOfPSN} io
	| send_quit_event_to_clean_compiler == NoErr
		= io;
		= io;
where {
	// from IDE 1.3
	send_quit_event_to_clean_compiler :: Int;
	send_quit_event_to_clean_compiler
		| error_code1<>0
			= error_code1;
		| error_code2<>0
			= free_memory error_code2;
		| error_code3<>0
			= free_descriptor_and_memory error_code3;
		| error_code4<>0
			= free_apple_event_and_desciptor_and_memory error_code4;
			= free_apple_event_and_desciptor_and_memory error_code4;
		where {
			(memory,error_code1,_) = NewPtr (SizeOfAEDesc+SizeOfAppleEvent+SizeOfAppleEvent) 0;
	
			descriptor=memory;
			apple_event=memory+SizeOfAEDesc;
			result_apple_event=memory+SizeOfAEDesc+SizeOfAppleEvent;
	
//			error_code2 = AECreateDesc TypeApplSignature CleanCompilerSignature descriptor;			
			application_sn
				= FromIntToString highLongOfPSN +++ FromIntToString lowLongOfPSN;
			error_code2 = AECreateDesc TypeProcessSerialNumber application_sn descriptor;

			error_code3 = AECreateAppleEvent KCoreEventClass KAEQuitApplication descriptor KAutoGenerateReturnID KAnyTransactionID apple_event;
			error_code4 = AESend apple_event result_apple_event KAENoReply KAENormalPriority KNoTimeOut 0 0;
	
			free_apple_event_and_desciptor_and_memory error_code
				| error_code==0
					= free_descriptor_and_memory free_error_code;
				| free_error_code==0
					= free_descriptor_and_memory error_code;
					= free_descriptor_and_memory error_code;
				where {
					free_error_code = AEDisposeDesc apple_event;
				}
	
			free_descriptor_and_memory error_code
				| error_code==0
					= free_memory free_error_code;
				| free_error_code==0
					= free_memory error_code;
					= free_memory error_code;
				where {
					free_error_code = AEDisposeDesc descriptor;
				}
	
			free_memory error_code
				| error_code==0
					= if (free_error_code==255) 0 free_error_code;
				| free_error_code==0
					= error_code;
					= error_code;
				where {
					(free_error_code,_)	= DisposPtr memory 0;
				}
		};

} // KillClient2

GetSystemRepresentationOfPSN :: !ProcessSerialNumber -> !(!Int,Int);
GetSystemRepresentationOfPSN psn=:{lowLongOfPSN,highLongOfPSN}
	= (lowLongOfPSN,highLongOfPSN);
