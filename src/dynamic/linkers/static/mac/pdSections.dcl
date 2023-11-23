definition module pdSections;

import StdClass;

// Mac dependent part of section header
:: PDSectionHeader = {
		exec_size				:: !Int
	,	init_size				:: !Int
	,	region_kind				:: !Int
	,	sharing_kind			:: !Int
	,	memory_alignment		:: !Int			// in memory
	};	
	
DefaultPDSectionHeader :: !PDSectionHeader;

:: SectionHeadKind
	= StartPrefix
	| TextSectionHeader
	| DataSectionHeader
	| LoaderSectionHeader
	| NoSectionHeader
	;

instance == SectionHeadKind;
instance toString SectionHeadKind;
