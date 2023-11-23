definition module read_dynamic;

from StdFile import :: Files;
from DefaultElem import class DefaultElem;

from StdDynamicLowLevelInterface import :: DynamicHeader,
		:: BlockTable, :: Block,
		:: DescriptorUsageTable, :: DescriptorUsageEntry, :: DynamicInfo;

:: BinaryDynamic = {
		header					:: !DynamicHeader
	,	graph					:: !String

	// string version (obsolete)
	,	stringtable				:: !String
	,	descriptortable			:: !String
	
	//  using StdDynamicLowLevelInterface
	,	block_table				:: !BlockTable
	,	block_table_as_string	:: !String
	,	descriptor_usage_table	:: !DescriptorUsageTable
	,	bd_dynamic_info			:: !DynamicInfo
	};

instance DefaultElem BinaryDynamic;
	
read_dynamic :: !String !String !*Files -> ((!Bool,!BinaryDynamic),!*Files);
