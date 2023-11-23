definition module PlatformLinkOptions;

import StdFile;
import SymbolTable;
//import macState;
import State;

// mac specific
:: *PlatformLinkOptions;

// Accessors; set's
plo_set_end_rva :: !Int !*PlatformLinkOptions -> !*PlatformLinkOptions;
plo_set_end_fp  :: !Int !*PlatformLinkOptions -> !*PlatformLinkOptions;
plo_set_s_raw_data :: !Int !Int !*PlatformLinkOptions -> !*PlatformLinkOptions;
plo_set_fp_section :: !Int !Int !*PlatformLinkOptions -> !*PlatformLinkOptions;
plo_set_sections :: Sections !*PlatformLinkOptions  -> !*PlatformLinkOptions;
plo_set_main_file_n_and_symbol_n :: !Int !Int !*PlatformLinkOptions -> !*PlatformLinkOptions;
	
// Accessors; get's
plo_get_start_fp :: !*PlatformLinkOptions -> !(!Int,!*PlatformLinkOptions);
plo_get_start_rva :: !*PlatformLinkOptions -> !(!Int,!*PlatformLinkOptions);
plo_get_sections :: !*PlatformLinkOptions -> !(!*Sections,!*PlatformLinkOptions);
plo_get_section_fp :: !Int !*PlatformLinkOptions -> !(!Int,!*PlatformLinkOptions);
// get's platform dependent
plo_get_pef_bss_section_end1 ::  !*PlatformLinkOptions -> !(!Int,!*PlatformLinkOptions);

// Required, platform dependent functions (interface)
DefaultPlatformLinkOptions :: !PlatformLinkOptions;
find_root_symbols :: *{!NamesTableElement} !*PlatformLinkOptions -> *(.Bool,Int,Int,.Bool,[(.Bool,{#Char},Int,Int)],*{!NamesTableElement},*PlatformLinkOptions);
create_section_header_kinds :: !*PlatformLinkOptions -> (!Int,!*PlatformLinkOptions);	
post_process :: !*State !*PlatformLinkOptions !*Files -> (!Bool,![!String],!*State,!*PlatformLinkOptions,!*Files);

// Required; platform INdependent functions
apply_generate_section :: !Int *File !*PlatformLinkOptions !*State !*Files -> (!Bool,!Int,!Int,!*File,!*PlatformLinkOptions,!*State,!*Files);
apply_compute_section :: !Int !Int !Int !*PlatformLinkOptions !*State !*Files -> (!Bool,!Int,!Int,!Int,!Int,!*State,!*PlatformLinkOptions,!*Files);
