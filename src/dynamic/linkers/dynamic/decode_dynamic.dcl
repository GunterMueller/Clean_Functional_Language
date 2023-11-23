definition module decode_dynamic;

from StdFile import class FileEnv, class FileSystem;
from DLState import :: DLClientState, :: DLServerState;
from ProcessSerialNumber import :: ProcessSerialNumber;
from StdDynamicTypes import :: LibRef, :: LibraryInstanceTypeReference;
from StdDynamicLowLevelInterface import class BinaryDynamicIO, :: DynamicHeader;

// should be moved to Request.icl
ComputeDescAddressTable2_n_args					:== 4;
ComputeDescAddressTable2_n_copy_request_args	:== 6;

init_lazy_dynamic :: !.Int !*DLClientState !*f -> *(Int,*DLClientState,!*f) | FileEnv f;

// physically reads in file and initializes the administration for the dynamic by init_dynamic2
init_dynamic :: {#.Char} !Bool !Int !Int !{#String} !*DLClientState !*f -> *(!Int,!*DLClientState,!*f) | FileEnv f & FileSystem f;

//read_from_dynamic :: !Int !String !*f !*DLClientState !.a !.DynamicHeader -> *(!*f,!Int,!*DLClientState,!.a) | BinaryDynamicIO f;

// computing address descriptor table by using the descriptor usage set table
LinkPartition :: !ProcessSerialNumber [String] !*DLServerState !*f -> (!Bool,!ProcessSerialNumber,!*DLServerState, !*f) | FileSystem f & FileEnv f;

// register a lazy dynamic
HandleRegisterLazyDynamicMessage :: !ProcessSerialNumber [String] !*DLServerState !*f -> (!Bool,!ProcessSerialNumber,!*DLServerState, !*f) | FileEnv f;

class convert_encoded_type_reference_to_rt_type_reference a :: !Int !a !(!*DLClientState,*f) -> *(!a,!(!*DLClientState,!*f)) | FileEnv f;

instance convert_encoded_type_reference_to_rt_type_reference LibRef;
convert_encoded_type_reference_to_rt_type_reference_LibRef :: !.Int !.LibRef !*(!*DLClientState,*a) -> *(.LibRef,*(*DLClientState,*a))| FileEnv a;

instance convert_encoded_type_reference_to_rt_type_reference LibraryInstanceTypeReference;
convert_encoded_type_reference_to_rt_type_reference_LibraryInstanceTypeReference :: !.Int !.LibraryInstanceTypeReference !*(!*DLClientState,*a) -> *(.LibraryInstanceTypeReference,*(!*DLClientState,!*a)) | FileEnv a;
