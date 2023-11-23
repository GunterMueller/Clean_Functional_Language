definition module registry;

:: RegistryState :== Int;

KEY_READ:==0x20019;
KEY_SET_VALUE:==2;
KEY_ALL_ACCESS:==0xF002f;

REG_OPTION_NON_VOLATILE:==0;

REG_SZ:==1;
REG_BINARY:==3;

ERROR_SUCCESS:==0;

HKEY_CURRENT_USER	:== 0x80000001;
HKEY_LOCAL_MACHINE	:== 0x80000002;

RegOpenKeyEx :: !Int !{#Char} !Int !Int !RegistryState -> (!Int,!Int,!RegistryState);
RegDeleteKey :: !Int !{#Char} !RegistryState-> (!Int,!RegistryState);
RegCloseKey :: !Int !RegistryState -> (!Int,!RegistryState);
RegCreateKeyEx :: !Int !{#Char} !Int !{#Char} !Int !Int !Int !RegistryState -> (!Int,!Int,!Int,!RegistryState);
RegSetValueEx ::
	!Int
	!{#Char}
	!Int
	!Int
	!{#Char}
	!Int
	!RegistryState -> (!Int,!RegistryState);
RegQueryValueEx ::
	!Int
	!{#Char}
	!Int
	!Int
	!{#Char}
	!{#Char}
	!RegistryState -> (!Int,!RegistryState);
RegEnumValue :: !Int !Int !Int !Int !Int !RegistryState -> (!Int,!{#Char},!Int,!{#Char},!RegistryState);

//==> the following don't really belong here...
GetFileAttributes :: !{#Char} -> Int;

:: CStringP :== Int;

GetCommandLine :: CStringP;
read_char :: !CStringP -> Char;
