implementation module registry;

import StdArray,StdInt,StdClass,StdString,StdBool,StdChar;

import code from library "registry_advapi32_library";

:: RegistryState :== Int;

KEY_READ:==0x20019;
KEY_SET_VALUE:==2;
KEY_ALL_ACCESS:==0xF002f;

REG_OPTION_NON_VOLATILE:==0;

REG_SZ:==1;
REG_BINARY:==3;

ERROR_SUCCESS:==0;

HKEY_LOCAL_MACHINE:==0x80000002;

RegOpenKeyEx :: !Int !{#Char} !Int !Int !RegistryState -> (!Int,!Int,!RegistryState);
RegOpenKeyEx hkey path n f rs = code {
	ccall RegOpenKeyExA@20 "PIsII:II"
};

RegDeleteKey :: !Int !{#Char} !RegistryState-> (!Int,!RegistryState);
RegDeleteKey hkey path rs = code {
	ccall RegDeleteKeyA@8 "PIs:I"
};

RegCloseKey :: !Int !RegistryState -> (!Int,!RegistryState);
RegCloseKey hkey rs = code {
	ccall RegCloseKey@4 "PI:I"
};

RegCreateKeyEx :: !Int !{#Char} !Int !{#Char} !Int !Int !Int !RegistryState -> (!Int,!Int,!Int,!RegistryState);
RegCreateKeyEx hkey path i s i1 i2 i3 rs = code {
	ccall RegCreateKeyExA@36 "PIsIsIII:III"
};

RegSetValueEx :: !Int !{#Char} !Int !Int !{#Char} !Int !RegistryState -> (!Int,!RegistryState);
RegSetValueEx hkey s1 i1 i2 s2 i3 rs = code {
	ccall RegSetValueExA@24 "PIsIIsI:I"
};

RegQueryValueEx :: !Int !{#Char} !Int !Int !{#Char} !{#Char} !RegistryState -> (!Int,!RegistryState);
RegQueryValueEx hkey s1 i1 i2 s2 i3 rs = code {
	ccall RegQueryValueExA@24 "PIsIIss:I:I"
};

/*
RegEnumValue :: !Int !Int !Int !Int !Int !RegistryState -> (!Int,!{#Char},!Int,!{#Char},!RegistryState);
RegEnumValue key index max_value_name_size reserved max_data_size rs
	# value_name = createArray max_value_name_size '0';
	# data = createArray max_data_size '0';
	# type_s = createArray 4 '\0';
	# value_name_size_s = {	toChar max_value_name_size,
							toChar (max_value_name_size>>8),
							toChar (max_value_name_size>>16),
							toChar (max_value_name_size>>24) };
	# data_size_s = {	toChar max_data_size,
						toChar (max_data_size>>8),
						toChar (max_data_size>>16),
						toChar (max_data_size>>24) };
	# (r,rs) = RegEnumValue_ key index value_name value_name_size_s reserved type_s data data_size_s rs;
	| r<>0
		= (r,"",0,"",rs);
	# data_size = string4_to_int data_size_s;
	# value_name_size = string4_to_int value_name_size_s;
	# type = string4_to_int type_s;
	| type==REG_SZ && data_size<>0
		= (r,value_name % (0,value_name_size-1),type,data % (0,data_size-2),rs);
		= (r,value_name % (0,value_name_size-1),type,data % (0,data_size-1),rs);

string4_to_int :: !{#Char} -> Int;
string4_to_int s
	= toInt s.[0] + (toInt s.[1]<<8) + (toInt s.[2]<<16) + (toInt s.[3]<<24);

RegEnumValue_ :: !Int !Int !{#Char} !{#Char} !Int !{#Char} !{#Char} !{#Char} !RegistryState -> (!Int,!RegistryState);
RegEnumValue_ key index value_name value_name_size reserved type data data_size rs
	= code {
		ccall RegEnumValueA@32 "PIIssIsss:I:I"
	} 
*/
RegEnumValue :: !Int !Int !Int !Int !Int !RegistryState -> (!Int,!{#Char},!Int,!{#Char},!RegistryState);
RegEnumValue key index max_value_name_size reserved max_data_size rs
	# value_name = createArray max_value_name_size '0';
	# data = createArray max_data_size '0';
	# type_s = { 0 };
	# value_name_size_s = { max_value_name_size };
	# data_size_s = { max_data_size };
	# (r,rs) = RegEnumValue_ key index value_name value_name_size_s reserved type_s data data_size_s rs;
	| r<>0
		= (r,"",0,"",rs);
	# data_size = data_size_s.[0];
	# value_name_size = value_name_size_s.[0];
	# type = type_s.[0];
	| type==REG_SZ && data_size<>0
		= (r,value_name % (0,value_name_size-1),type,data % (0,data_size-2),rs);
		= (r,value_name % (0,value_name_size-1),type,data % (0,data_size-1),rs);

RegEnumValue_ :: !Int !Int !{#Char} !{#Int} !Int !{#Int} !{#Char} !{#Int} !RegistryState -> (!Int,!RegistryState);
RegEnumValue_ key index value_name value_name_size reserved type data data_size rs
	= code {
		ccall RegEnumValueA@32 "PIIsAIAsA:I:I"
	}

GetFileAttributes :: !{#Char} -> Int;
GetFileAttributes file_name = code {
	ccall GetFileAttributesA@4 "Ps:I"
};

:: CStringP :== Int;

GetCommandLine :: CStringP;
GetCommandLine = code {
	ccall GetCommandLineA@0 "P:I"
};

read_char :: !CStringP -> Char;
read_char p = code {
	instruction 15
	instruction 182
	instruction 0 | movzx   eax,byte ptr [eax]
};
