definition module Sections;

from StdFile import :: Files;

from State import :: State;
from PlatformLinkOptions import :: PlatformLinkOptions;
from pdSections import :: PDSectionHeader, :: SectionHeadKind;

:: ComputeSectionType
	:== Int -> Int -> Int -> SectionHeader -> *(*State -> *(*PlatformLinkOptions -> *(*Files -> *(!Int,!SectionHeader,!*State,!*PlatformLinkOptions,!*Files))));

:: GenerateSectionType
	:== SectionHeader -> (*File -> *(*PlatformLinkOptions -> *(*State -> *(*Files -> *(!*File,!*PlatformLinkOptions,!*State,!*Files)))));
	
:: SectionHeader;

DefaultSectionHeader :: SectionHeader;

(DSH) infixl;
(DSH) dsh f :== f dsh;
 
// Accessors; set
sh_set_kind :: !SectionHeadKind !SectionHeader -> SectionHeader;
sh_set_index :: !Int !SectionHeader -> SectionHeader;
sh_set_alignment :: !Int !SectionHeader -> SectionHeader;
sh_set_compute_section :: ComputeSectionType !SectionHeader -> SectionHeader;
sh_set_generate_section :: GenerateSectionType !SectionHeader -> SectionHeader;
sh_set_virtual_data :: !Int !SectionHeader -> SectionHeader;
sh_set_is_virtual_section :: !Bool !SectionHeader -> SectionHeader;
sh_set_s_raw_data :: !Int !SectionHeader -> SectionHeader;

sh_set_fp_section :: !Int !SectionHeader -> SectionHeader;
sh_set_pd_section_header :: !PDSectionHeader !SectionHeader -> SectionHeader;

// get
sh_get_kind :: !SectionHeader -> SectionHeadKind;
sh_get_alignment :: !SectionHeader -> Int;
sh_get_is_virtual_section :: !SectionHeader -> Bool;
sh_get_s_virtual_data :: !SectionHeader -> Int;
sh_get_s_raw_data :: !SectionHeader -> Int;
sh_get_fp_section :: !SectionHeader -> Int;
sh_get_compute_section :: !SectionHeader -> ComputeSectionType;
sh_get_generate_section :: !SectionHeader -> GenerateSectionType;
sh_get_pd_section_header :: !SectionHeader -> PDSectionHeader;

// {SectionHeader}
get_section_index :: !Int SectionHeadKind !*{!SectionHeader} -> (!Bool,!Int,!SectionHeader,!*{!SectionHeader});
get_section_index2 :: (SectionHeadKind SectionHeadKind -> Bool) !Int SectionHeadKind !*{!SectionHeader} -> (!Bool,!Int,!SectionHeader,!*{!SectionHeader});



