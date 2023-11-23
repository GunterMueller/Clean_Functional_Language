definition module Platform

PlatformDependant win_linux_macosx mac :== win_linux_macosx

IF_MACOSX macosx not_macosx :== not_macosx
IF_WINDOWS windows not_windows :== not_windows

IF_ARM arm other :== other

DirSeparator:=='/'
DirSeparatorString:=="/"

EnvsDirName:==""

TempDir :== "/tmp"

application_path :: !{#Char} -> {#Char}
