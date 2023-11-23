implementation module CallCg;

import StdEnv;

import memory, appleevents;
from files import LaunchApplication; 

CodeGen :: !String !String -> (!String,!Bool);
CodeGen path_without_suffix cgpath
 	#! command
		= "cg " +++ quoted_string path_without_suffix +++ " > out errors";
	#! (error_code,error_n,output_string)
		= send_command_to_clean_compiler command cgpath;
	| size output_string == 0
		= (path_without_suffix +++ ".o", error_n == 0);
		= abort ("CodeGen: " +++ output_string);
		
quoted_string string = "\'" +++ double_quotes 0 string +++ "\'";
{
	double_quotes i string
		| i>=size string
			= string;
		| string.[i]=='\''
			= double_quotes (i+2) (string % (0,i)+++"\'"+++string % (i+1,dec (size string)));
			= double_quotes (inc i) string;
}
		
send_command_to_clean_compiler :: !String !String -> (!Int,!Int,!String);
send_command_to_clean_compiler command cgpath
	| error_n<>(-2)
		= (os_error_code,error_n,output_string);
	| launch_error_n>=0	
		= send_command_to_clean_compiler0 command;
		= (os_error_code,-1,output_string);
	{}{
		(os_error_code,error_n,output_string)=send_command_to_clean_compiler0 command;
		(launch_error_n,t2) = launch_application /*"Clean Compiler"*/ cgpath 0xCA000000;
	}
	
send_command_to_clean_compiler0 :: !String -> (!Int,!Int,!String);
send_command_to_clean_compiler0 command
	| error_code1<>0
		= (error_code1,-1,"");
	#	// error_code2 = AECreateDesc TypeApplSignature "MPSX" descriptor; // Tool Server
		error_code2 = AECreateDesc TypeApplSignature "ClCo" descriptor;
	| error_code2<>0
		= (free_memory error_code2,-1,"");
	# error_code3 = AECreateAppleEvent KAEMiscStandards KAEDoScript descriptor KAutoGenerateReturnID KAnyTransactionID apple_event;
	| error_code3<>0
		= (free_descriptor_and_memory error_code3,-1,"");
	# error_code4 = AEPutParamPtr apple_event KeyDirectObject TypeChar command;
	| error_code4<>0
		= (free_apple_event_and_desciptor_and_memory error_code4,-1,"");
	# error_code5 = AESend apple_event result_apple_event KAEWaitReply KAENormalPriority KNoTimeOut 0 0;
	| error_code5==(-609)
		= (free_apple_event_and_desciptor_and_memory error_code5,-2,"");
	| error_code5<>0
		= (free_apple_event_and_desciptor_and_memory error_code5,-1,"");
		= (free_result_apple_event_and_apple_event_and_desciptor_and_memory error_code6 error_code7,
			if (error_code6<0) 0 v1,
			if (error_code7<>0) "" (string8 % (0,s2-1)));
	where {
		(memory,error_code1,_) = NewPtr (SizeOfAEDesc+SizeOfAppleEvent+SizeOfAppleEvent) 0;

		descriptor=memory;
		apple_event=memory+SizeOfAEDesc;
		result_apple_event=memory+SizeOfAEDesc+SizeOfAppleEvent;

		(error_code6,t1,v1,s1) = AEGetIntParamPtr result_apple_event KeyErrorNumber TypeLongInteger;
		(error_code7,t2,s2) = AEGetStringParamPtr result_apple_event KeyErrorString TypeChar string8;

			string0 = "0123456789" +++ "0123456789";
			string1 = string0 +++ string0;
			string2 = string1 +++ string1;
			string3 = string2 +++ string2;
			string4 = string3 +++ string3;
			string5 = string4 +++ string4;
			string6 = string5 +++ string5;
			string7 = string6 +++ string6;
			string8 = string7 +++ string7;

		free_result_apple_event_and_apple_event_and_desciptor_and_memory error_code6 error_code7
			| error_code6==error_code6 && error_code7==error_code7
				= free_apple_event_and_desciptor_and_memory free_error_code;
			{}{
				free_error_code = AEDisposeDesc result_apple_event;
			}

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

launch_application :: !{#Char} !Int -> (!Int,!*Toolbox);
launch_application path flags
	= LaunchApplication path flags NewToolbox;
	