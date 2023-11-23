definition module files;

import mac_types;

GetVInfo :: !{#Char} !*Toolbox -> (!Int,!Int,!*Toolbox);
GetCatInfo1 :: !Int !{#Char} !*Toolbox -> (!Int,!Int,!*Toolbox);
GetCatInfo2 :: !Int !Int !{#Char} !*Toolbox -> (!Int,!{#Char},!Int,!*Toolbox);
GetCatInfo3 :: !Int !Int !{#Char} !*Toolbox -> (!Int,!Int,!Int,!*Toolbox);
//GetWDInfo :: !Int !*Toolbox -> (!Int,!Int,!Int,!*Toolbox);
HGetVol :: !*Toolbox -> (!Int,!Int,!Int,!*Toolbox);
//OpenWD :: !Int !Int !*Toolbox -> Int;
GetFInfo :: !{#Char} !*Toolbox -> (!Int,!Int,!*Toolbox);
SetFileType :: !{#Char} !{#Char} !*Toolbox -> (!Int,!*Toolbox);
SetFileTypeAndCreator :: !{#Char} !{#Char} !{#Char} !*Toolbox -> (!Int,!*Toolbox);
FSMakeFSSpec :: !{#Char} !*Toolbox -> (!Int,!{#Char},!*Toolbox);
//LaunchApplication :: !{#Char} !Int !*Toolbox -> (!Int,!*Toolbox);
LaunchApplicationFSSpec :: !{#Char} !Int !*Toolbox -> (!Int,!*Toolbox);
