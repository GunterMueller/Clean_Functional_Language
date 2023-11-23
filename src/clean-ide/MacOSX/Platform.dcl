definition module Platform

PlatformDependant win_linux_macosx mac :== win_linux_macosx

IF_MACOSX macosx not_macosx :== macosx
IF_WINDOWS windows not_windows :== not_windows

DirSeparator:=='/'
DirSeparatorString:=="/"

EnvsDirName:==""

TempDir :== "/tmp"

application_path :: !{#Char} -> {#Char}
