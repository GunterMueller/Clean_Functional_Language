definition module pdObjectToMem;

import DLState;
from LibraryInstance import ::Libraries;

// Client <-> Server communication
class SendAddressToClient a
where {
	SendAddressToClient :: !ProcessSerialNumber a !*f -> *f
};

instance SendAddressToClient Int;
instance SendAddressToClient {#Char};
instance SendAddressToClient [Int];
instance SendAddressToClient (Int,[Int]);
instance SendAddressToClient ({#Char},Int,[Int]);
instance SendAddressToClient ({#Char},{#Char},Int,[Int]);
instance SendAddressToClient ({#Char},{#Char},Int,[Int],{#Char});

class EncodeClientMessage a
where {
	EncodeClientMessage :: a -> String
};

instance EncodeClientMessage [Int];

:: WriteImageInfo
	= {
		wii_code_start	:: !Int
	,	wii_code_end	:: !Int
	,	wii_data_start	:: !Int
	,	wii_data_end	:: !Int
	};
default_write_image_info :: WriteImageInfo;

write_image :: !Libraries !*State *f -> *(!Int,!WriteImageInfo,*State,*f) | FileEnv f;
