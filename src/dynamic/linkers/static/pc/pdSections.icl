implementation module pdSections;

import StdClass;
import StdEnv;
from StdMisc import abort;

// Windows dependent part of section header
:: PDSectionHeader = {
		section_name				:: !String
	,	section_rva					:: !Int
	,	section_flags				:: !Int
	};
	
DefaultPDSectionHeader :: PDSectionHeader;
DefaultPDSectionHeader 
	= { PDSectionHeader |
		section_name				= ""
	,	section_rva					= 0
	,	section_flags				= 0
	};
	
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
	
instance == SectionHeadKind
where {
	(==) StartPrefix				StartPrefix 				= True;
	(==) TextSectionHeader			TextSectionHeader			= True;
	(==) DataSectionHeader			DataSectionHeader			= True;
	(==) BssSectionHeader			BssSectionHeader			= True;
	(==) IDataSectionHeader			IDataSectionHeader			= True;
	(==) EDataSectionHeader			EDataSectionHeader			= True;
	(==) PDataSectionHeader			PDataSectionHeader			= True;
	(==) RelocSectionHeader			RelocSectionHeader			= True;
	(==) ResourceSectionHeader		ResourceSectionHeader		= True;
	(==) (UserSectionHeader s1 _ _)	(UserSectionHeader s2 _ _)	= s1 == s2;
	(==) NoSectionHeader			_ 							= abort "(==) SectionHeadKind: internal error";
	(==) _							NoSectionHeader				= abort "(==) SectionHeadKind: internal error";
	(==) _							_							= False;
};

instance toString SectionHeadKind
where {
	toString StartPrefix				= "StartPrefix";
	toString TextSectionHeader			= "TextSectionHeader";
	toString DataSectionHeader			= "DataSectionHeader";
	toString BssSectionHeader			= "BssSectionHeader";
	toString IDataSectionHeader			= "IDataSectionHeader";
	toString EDataSectionHeader			= "EDataSectionHeader";
	toString PDataSectionHeader			= "PDataSectionHeader";
	toString RelocSectionHeader			= "RelocSectionHeader";
	toString ResourceSectionHeader		= "ResourceSectionHeader";
	toString (UserSectionHeader s1 _ _)	= "UserSectionHeader \"" +++ s1 +++ "\"";
	toString NoSectionHeader			= "NoSectionHeader";
};