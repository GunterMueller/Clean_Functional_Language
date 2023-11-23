implementation module DynamicLink;

import ProcessSerialNumber;

import code from library "DynamicLink_symbols";
import code from "sharing.obj";

GetDynamicLinkerPath :: String;
GetDynamicLinkerPath
	= code {
		ccall GetDynamicLinkerPath "-S"
	};

// cmd_line must be zeroterminated
StartProcess :: !String !String !String -> (!Bool,!Int);
StartProcess  current_directory file_name cmd_line
	= code {
		ccall StartProcess "SSS-II"
	};

KillClient :: !Int -> Bool;
KillClient _ =
	code {
		ccall KillClient "I-I"
	}

ReceiveReqWithTimeOut :: !Bool -> (!Bool,!Int,!String);
ReceiveReqWithTimeOut _ = 
	code {
		ccall ReceiveReqWithTimeOut "I-IIS"
	}

ReceiveReqWithTimeOutE :: !Bool -> (!Bool,!ProcessSerialNumber,!String);
ReceiveReqWithTimeOutE static_application_as_client
	#! (ok,client_id,s)
		= ReceiveReqWithTimeOut static_application_as_client;
	= (ok,CreateProcessSerialNumber client_id,s);
	
ReplyReq :: !Int -> Bool;
ReplyReq q =
	code {
		ccall ReplyReq "I-I"
	}

ReplyReqS :: !String -> Bool;
ReplyReqS _ = 
	code {
		ccall ReplyReqS "S-I"
	}
	
ReceiveCodeDataAdr :: !Int !Int -> (!Bool,!*Int,!*Int);
ReceiveCodeDataAdr _ _ =
	code {
		ccall ReceiveCodeDataAdr "II-III"
	}

GenerateObjectFileOld :: !String !String -> Bool;
GenerateObjectFileOld cgpath commandline =
	code {
		ccall GenerateObjectFileOld "SS-I"
	}


FirstInstanceOfServer2 :: !Bool -> Bool;
FirstInstanceOfServer2 _ =
	code {
		ccall FirstInstanceOfServer2 "I-I"
	}
	
is_first_instance :: Bool;
is_first_instance 
	= code {
		ccall is_first_instance ":I"
	};


StoreLong :: !String !Int !Int -> Bool;
StoreLong s adr int
	= storelong adr int
where
{
	storelong :: !Int !Int -> Bool;
	storelong _ _ =
		code {
			ccall StoreLong "II-I"
		}
}		

SetCurrentLibrary :: !String -> (!Bool,!*Int);
SetCurrentLibrary lib_name =
	code {
		ccall SetCurrentLibrary "S-II"
	}
	
GetFuncAddress :: !String !Int !*Int -> (!Int, !*Int);
GetFuncAddress _ _ _ =
	code {
		ccall GetFuncAddress "SII-II"
	}
	
mwrites :: !Int !Int !{#Char} !*Int -> *Int;
mwrites kind offset text mem_ptr =
	code {
		ccall mwrites "IISI-I"
	}

MakeNonUnique :: !*Int -> (!*Int, !Int);
MakeNonUnique _ = 
	code {
		push_b 0
	}

FlushBuffers :: !Int -> Int;
FlushBuffers _ =
	code {
		ccall FlushBuffers "I-I"
	}
	
PassCommandLine :: !String -> Bool;
PassCommandLine _ =
	code {
		ccall PassCommandLine "S-I"
	}
	