definition module Platform

import StdString

PlatformDependant win_linux_macosx mac :== win_linux_macosx

IF_MACOSX macosx not_macosx :== not_macosx
IF_WINDOWS windows not_windows :== windows

DirSeparator:=='\\'
DirSeparatorString:=="\\"

EnvsDirName:=="Config\\"

TempDir		:: String
EnvsDir		:: String
PrefsDir	:: String

batchOptions :: !*World -> (!Bool,Bool,String,*File,!*World)
wAbort :: !String !*World -> *World

onOSX	:: Bool

application_path :: !String -> String // same as applicationpath in StdSystem

get_module_file_name :: !*state -> (!{#Char},!Int,!*state)
expand_8_3_names_in_path :: !{#Char} -> {#Char}
find_first_file_and_close :: !{#Char} -> (!Bool,!{#Char})
