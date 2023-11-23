definition module Request;

from StdFile import class FileSystem, class FileEnv;
from DLState import :: DLServerState;
from ProcessSerialNumber import :: ProcessSerialNumber;

Quit :: !ProcessSerialNumber [String] !*DLServerState !*f -> (!Bool,!ProcessSerialNumber,!*DLServerState, !*f) | FileSystem f;

Close :: !ProcessSerialNumber [String] !*DLServerState !*f -> (!Bool,!ProcessSerialNumber,!*DLServerState, !*f) | FileSystem f;

MessageFromSecondOrLaterLinker_ :: .(ProcessSerialNumber -> .(*DLServerState -> .(*a -> *(*DLServerState,*a)))) .b ![{#.Char}] !*DLServerState *a -> *(.Bool,ProcessSerialNumber,*DLServerState,*a) | FileSystem a;

// adds a client; (there are not yet any other clients); LIB-implementation
AddClient3 :: .(ProcessSerialNumber -> .(*DLServerState -> .(*a -> *(*DLServerState,*a)))) .b ![{#.Char}] !*DLServerState *a -> *(.Bool,ProcessSerialNumber,*DLServerState,*a) | FileSystem a;

// Loads an application from a library
LoadApplication :: !ProcessSerialNumber [String] !*DLServerState !*f -> (!Bool,!ProcessSerialNumber,!*DLServerState, !*f) | FileEnv, FileSystem f;

// Main application is dumpDynamic
DumpDynamic :: !ProcessSerialNumber [String] !*DLServerState !*f -> (!Bool,!ProcessSerialNumber,!*DLServerState, !*f) | FileSystem f;

// Get directory of linker
GetDynamicLinkerDir :: !ProcessSerialNumber [String] !*DLServerState !*f-> (!Bool,!ProcessSerialNumber,!*DLServerState, !*f) | FileSystem f;

// lookup addresses of some already linked in labels
GetLabelAddresses :: !ProcessSerialNumber [String] !*DLServerState !*f -> (!Bool,!ProcessSerialNumber,!*DLServerState, !*f) | FileEnv f;

// auxillary
AddAndInitPC_ :: ProcessSerialNumber ![{#.Char}] *DLServerState *a -> *({#{#Char}},*(!Bool,!ProcessSerialNumber,!*DLServerState,!*a)) | FileSystem a;

encode_command_line :: ![String] -> {#Char};
