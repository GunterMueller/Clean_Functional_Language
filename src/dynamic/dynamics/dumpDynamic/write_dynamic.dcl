definition module write_dynamic;

from StdFile import :: Files;
from read_dynamic import :: BinaryDynamic;
from compute_graph import :: DescriptorAddressTable, :: Nodes, :: NodeKind;
from ddState import :: DDState;
from StdDynamicLowLevelInterface import :: DynamicInfo;

WriteDescriptorAddressTable :: !Int !Int !BinaryDynamic !DescriptorAddressTable !*File -> (!*File,!DescriptorAddressTable);
	
WriteHeader :: !BinaryDynamic !*File -> *File;
	
WriteStringTable :: !BinaryDynamic !*File -> *File;

WriteGraph :: !*DescriptorAddressTable !BinaryDynamic *(Nodes NodeKind) !*File !*DDState -> *(*Nodes NodeKind,!*File,!*DescriptorAddressTable,!*DDState);

WriteBlockTable :: !BinaryDynamic !*File -> *File;

WriteDynamicInfo :: !.DynamicInfo !*File !*Files -> (!*File,!*Files);