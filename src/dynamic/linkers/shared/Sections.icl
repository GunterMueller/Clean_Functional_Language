implementation module Sections;

import StdArray, StdClass, StdInt;
from StdMisc import undef, abort;
import State;
import PlatformLinkOptions;
import pdSections;

:: ComputeSectionType
	:== Int -> Int -> Int -> SectionHeader -> *(*State -> *(*PlatformLinkOptions -> *(*Files -> *(!Int,!SectionHeader,!*State,!*PlatformLinkOptions,!*Files))));

:: GenerateSectionType
	:== SectionHeader -> (*File -> *(*PlatformLinkOptions -> *(*State -> *(*Files -> *(!*File,!*PlatformLinkOptions,!*State,!*Files)))));
			
:: SectionHeader = {
	// fields should be initialized 
		kind				:: !SectionHeadKind
	,	index				:: !Int							// obsolete
	,	alignment			:: !Int
	,	compute_section 	:: ComputeSectionType
	,	generate_section	:: GenerateSectionType
	, 	is_virtual_section 	:: !Bool
	,	s_virtual_data		:: !Int

	// automatically initialized
	,	s_raw_data			:: !Int							// only if s_raw_data == 0
	,	fp_section			:: !Int
	
	// platform dependent part of section header
	,	pd_header			:: PDSectionHeader
};

sh_get_kind :: !SectionHeader -> SectionHeadKind;
sh_get_kind {kind}
	= kind;
	
sh_get_alignment :: !SectionHeader -> Int;
sh_get_alignment {alignment} 
	= alignment;
	
sh_get_is_virtual_section :: !SectionHeader -> Bool;
sh_get_is_virtual_section {is_virtual_section}
	= is_virtual_section;

sh_get_s_virtual_data :: !SectionHeader -> Int;
sh_get_s_virtual_data section_header=:{s_virtual_data}
	= s_virtual_data;
	
sh_get_compute_section :: !SectionHeader -> ComputeSectionType;
sh_get_compute_section {compute_section}
	= compute_section;
	
sh_get_generate_section :: !SectionHeader -> GenerateSectionType;
sh_get_generate_section {generate_section}
	= generate_section;
	
sh_get_s_raw_data :: !SectionHeader -> Int;
sh_get_s_raw_data section_header=:{s_raw_data}
	= s_raw_data;
	
sh_get_fp_section :: !SectionHeader -> Int;
sh_get_fp_section section_header=:{fp_section}
	= fp_section;
	
sh_get_pd_section_header :: !SectionHeader -> PDSectionHeader;
sh_get_pd_section_header {pd_header}
	= pd_header;
	
DefaultSectionHeader :: SectionHeader;
DefaultSectionHeader 
	= { SectionHeader |
		kind				= NoSectionHeader
	,	index				= 0
	,	alignment			= 512
	,	compute_section		= undef
	,	generate_section	= undef
	, 	is_virtual_section	= False
	,	s_virtual_data		= 0
	
	// automatically initialized
	,	s_raw_data			= 0
	,	fp_section			= 0
	
	// platform dependent part of section header
	,	pd_header			= DefaultPDSectionHeader
};		

(DSH) infixl;
(DSH) dsh f :== f dsh;
 
// Accessors; set
sh_set_kind :: !SectionHeadKind !SectionHeader -> SectionHeader;
sh_set_kind kind section_header
	= { section_header & kind = kind};

sh_set_index :: !Int !SectionHeader -> SectionHeader;
sh_set_index index section_header
	= { section_header & index = index };
	
sh_set_alignment :: !Int !SectionHeader -> SectionHeader;
sh_set_alignment alignment section_header
	= { section_header & alignment = alignment };
	
sh_set_is_virtual_section :: !Bool !SectionHeader -> SectionHeader;
sh_set_is_virtual_section is_virtual_section section_header
	= { section_header & is_virtual_section = is_virtual_section};
	
sh_set_virtual_data :: !Int !SectionHeader -> SectionHeader;
sh_set_virtual_data s_virtual_data section_header
	= { section_header & s_virtual_data = s_virtual_data };

sh_set_s_raw_data :: !Int !SectionHeader -> SectionHeader;
sh_set_s_raw_data s_raw_data section_header
	= { section_header & s_raw_data = s_raw_data };
	
sh_set_fp_section :: !Int !SectionHeader -> SectionHeader;
sh_set_fp_section fp_section section_header
	= { section_header & fp_section = fp_section };
	
sh_set_compute_section :: ComputeSectionType !SectionHeader -> SectionHeader;
sh_set_compute_section compute_section section_header
	= { section_header & compute_section = compute_section };
	
sh_set_generate_section :: GenerateSectionType !SectionHeader -> SectionHeader;
sh_set_generate_section generate_section section_header
	= { section_header & generate_section = generate_section };

sh_set_pd_section_header :: !PDSectionHeader !SectionHeader -> SectionHeader;
sh_set_pd_section_header pd_section_header section_header
	= { section_header &
		pd_header			= pd_section_header
	};
	
appSectionHeader_a f section_header_a
	# (x,section_header_a)
		= f section_header_a;
	= (x,section_header_a);
	

get_section_index :: !Int SectionHeadKind !*{!SectionHeader} -> (!Bool,!Int,!SectionHeader,!*{!SectionHeader});
get_section_index start_i demanded_section_head_kind section_header_a 
	= get_section_index2 (==) start_i demanded_section_head_kind section_header_a;
	
get_section_index2 :: (SectionHeadKind SectionHeadKind -> Bool) !Int SectionHeadKind !*{!SectionHeader} -> (!Bool,!Int,!SectionHeader,!*{!SectionHeader});
get_section_index2 p start_i demanded_section_head_kind section_header_a 
	# (s_section_header_a,section_header_a)
		= usize section_header_a;
	= loop_get_section_index start_i s_section_header_a section_header_a
where {
	loop_get_section_index i limit section_header_a
		| i >= limit
			= (False,0,DefaultSectionHeader,section_header_a);
			
			# (section_header,section_header_a)
				= section_header_a![i];
			| p section_header.kind demanded_section_head_kind
				= (True,i,section_header,section_header_a);
				= loop_get_section_index (inc i) limit section_header_a;
}

