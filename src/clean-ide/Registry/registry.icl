implementation module registry;

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
