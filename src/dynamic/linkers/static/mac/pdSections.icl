implementation module pdSections;

import StdClass;
from StdString import String;
from StdMisc import abort;

// Mac dependent part of section header
:: PDSectionHeader = {
		exec_size				:: !Int
	,	init_size				:: !Int
	,	region_kind				:: !Int
	,	sharing_kind			:: !Int
	,	memory_alignment		:: !Int			// in memory
	};
	
DefaultPDSectionHeader :: !PDSectionHeader;
DefaultPDSectionHeader
	= { PDSectionHeader |
		exec_size				= 0
	,	init_size				= 0
	,	region_kind				= 0
	,	sharing_kind			= 0
	,	memory_alignment		= 0
	};
	
:: SectionHeadKind
	= StartPrefix
	| TextSectionHeader
	| DataSectionHeader
	| LoaderSectionHeader
	| NoSectionHeader
	;

instance == SectionHeadKind
where {
	(==) StartPrefix			StartPrefix 		= True;
	(==) TextSectionHeader		TextSectionHeader	= True;
	(==) DataSectionHeader		DataSectionHeader	= True;
	(==) LoaderSectionHeader	LoaderSectionHeader	= True;
	(==) NoSectionHeader		_ 					= abort "(==) SectionHeadKind: internal error";
	(==) _						NoSectionHeader		= abort "(==) SectionHeadKind: internal error";
	(==) _						_					= False;
};	

instance toString SectionHeadKind
where {
	toString StartPrefix			= "StartPrefix";
	toString TextSectionHeader		= "TextSectionHeader";
	toString DataSectionHeader		= "DataSectionHeader";
	toString LoaderSectionHeader	= "LoaderSectionHeader";
	toString NoSectionHeader		= "NoSectionHeader";
};