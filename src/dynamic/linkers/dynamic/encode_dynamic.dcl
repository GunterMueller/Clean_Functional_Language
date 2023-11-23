definition module encode_dynamic;

from StdFile import class FileEnv, class FileSystem;
from ProcessSerialNumber import :: ProcessSerialNumber;
from DLState import :: DLServerState;

// encoding of a dynamic by exchanged messages:
//
// 1. HandleGetGraphToStringMessage
//
// get address of the graph to string function
HandleGetGraphToStringMessage :: !ProcessSerialNumber [String] !*DLServerState !*f -> (!Bool,!ProcessSerialNumber,!*DLServerState, !*f) | FileSystem, FileEnv f;

// send to get extra dynamic rts information
HandleGetDynamicRTSInfoMessage :: !ProcessSerialNumber [String] !*DLServerState !*f -> (!Bool,!ProcessSerialNumber,!*DLServerState, !*f) | FileSystem, FileEnv f;

