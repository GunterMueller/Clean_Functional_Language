implementation module Clean2AppleEventHandler;

import StdClass,StdBool,StdArray,StdInt,StdString,StdChar,StdFile;
import files,events;

import StdDebug,StdString;

import code from "cae.";

HandleAppleEvent :: !Event ({#Char} *Files -> (!Int,!*Files)) !*Files -> (!Bool,!Bool,!*Files);
HandleAppleEvent (b,what,message,when,p1,p2,modifiers) script_handler files
	| what==HighLevelEvent
		# r1=handle_apple_event2 what message when p1 p2 modifiers;		
		# result_string=createArray r1 ' ';
		  r=get_apple_event_string r1 result_string;
		  
//		| trace_t r1 && trace_t ' ' && trace_t r && trace_t ' ' && trace_t result_string && trace_t '\n' &&
		|
		 r==4 && result_string % (0,3) == "QUIT"
			= (True,True,files);
		| r >= 6 && result_string % (0, 5) == "SCRIPT"
			# (result,files) = script_handler (result_string % (6,r-1)) files
			= (True,False,files);
			= (False,False,files);
	=	(False,False,files);

install_apple_event_handlers :: Int;
install_apple_event_handlers
	= code ()(r=D0){
		call	.install_apple_event_handlers
	}

handle_apple_event :: !Int !Int !Int !Int !Int !Int !String -> Int;
handle_apple_event what message when p1 p2 modifiers string
	= code (modifiers=W,p1=W,p2=W,when=L,message=L,what=W,string=O0D0U)(r=I16D0){
		instruction 0x38970000	|	addi	r4,r23,0
	 	call	.handle_apple_event
 	}

handle_apple_event2 :: !Int !Int !Int !Int !Int !Int -> Int;
handle_apple_event2 what message when p1 p2 modifiers
	= code {
	 	ccall	handle_apple_event2 "GIIIIII:I"
 	}

get_apple_event_string :: !Int !String -> Int;
get_apple_event_string length string
	= code {
	 	ccall	get_apple_event_string "IS:I"
 	}
