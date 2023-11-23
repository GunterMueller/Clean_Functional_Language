definition module pdSections;

from StdClass import class toString, class ==;

// Windows dependent part of section header
:: PDSectionHeader = {
		section_name				:: !String
	,	section_rva					:: !Int
	,	section_flags				:: !Int
	};
	
DefaultPDSectionHeader :: PDSectionHeader;

:: SectionHeadKind = 
	  StartPrefix
	| TextSectionHeader
	| DataSectionHeader 
	| BssSectionHeader
	| IDataSectionHeader
	| PDataSectionHeader
	| EDataSectionHeader
	| RelocSectionHeader
	| ResourceSectionHeader
	| UserSectionHeader !String !Int !Int 
	| NoSectionHeader
	;
		
instance == SectionHeadKind;
instance toString SectionHeadKind;
