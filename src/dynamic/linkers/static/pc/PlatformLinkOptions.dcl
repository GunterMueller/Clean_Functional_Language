definition module PlatformLinkOptions;

from StdFile import :: Files;
from State import :: State;
from NamesTable import :: NamesTableElement;
from pdSymbolTable import :: Sections;

// pc specific
:: *PlatformLinkOptions;

// Accessors; set's
plo_set_end_rva :: !Int !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_end_fp  :: !Int !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_get_base_va :: !*PlatformLinkOptions -> (!Int,!*PlatformLinkOptions);
plo_get_text_data_bss_va :: !*PlatformLinkOptions -> (!Int,!Int,!Int,!*PlatformLinkOptions);
plo_set_s_raw_data :: !Int !Int !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_fp_section :: !Int !Int !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_sections :: Sections !*PlatformLinkOptions  -> *PlatformLinkOptions;
plo_set_main_file_n_and_symbol_n :: !Int !Int !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_any_extra_sections :: !Bool !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_n_buffers :: !Int !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_c_stack_size :: !Int !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_image_symbol_table_info :: !Int /*n_symbols*/ !Int /*string_table_size*/ !Int /*symbol_table_offset*/
									!*PlatformLinkOptions -> *PlatformLinkOptions;

// Accessors; get's
plo_get_start_fp :: !*PlatformLinkOptions -> (!Int,!*PlatformLinkOptions);
plo_get_start_rva :: !*PlatformLinkOptions -> (!Int,!*PlatformLinkOptions);
//plo_get_sections :: !*PlatformLinkOptions -> (!*Sections,!*PlatformLinkOptions);
plo_get_section_fp :: !Int !*PlatformLinkOptions -> (!Int,!*PlatformLinkOptions);
plo_get_n_buffers :: !*PlatformLinkOptions -> (!Int,!*PlatformLinkOptions);

// Required, platform dependent functions (interface)
DefaultPlatformLinkOptions :: PlatformLinkOptions;
find_root_symbols :: *{!NamesTableElement} !*PlatformLinkOptions -> *(.Bool,Int,Int,.Bool,[(.Bool,{#Char},Int,Int)],*{!NamesTableElement},*PlatformLinkOptions);
create_section_header_kinds :: !*State !*PlatformLinkOptions -> (!Int,!*State,!*PlatformLinkOptions);
post_process :: !*State !*PlatformLinkOptions !*Files -> (!Bool,[String],!*State,!*PlatformLinkOptions,!*Files);

// Required; platform INdependent functions
apply_compute_section :: !Int !Int !Int !*PlatformLinkOptions !*State !*Files -> (!Bool,!Int,!Int,!Int,!Int,!*State,!*PlatformLinkOptions,!*Files);
apply_generate_section :: !Int *File !*PlatformLinkOptions !*State !*Files -> (!Bool,!Int,!Int,!*File,!*PlatformLinkOptions,!*State,!*Files);

// WAT HIERMEE TE DOEN? accessor; platform dependent
plo_set_console_window :: !Bool !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_gen_relocs :: !Bool !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_generate_symbol_table :: !Bool !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_gen_linkmap :: !Bool !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_gen_resource :: !Bool !String !*PlatformLinkOptions -> *PlatformLinkOptions;	
plo_set_base_va :: !Int !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_make_dll :: !Bool !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_exported_symbols :: [(String,String)] !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_main_entry :: !String !*PlatformLinkOptions -> *PlatformLinkOptions;

create_buffers :: !*PlatformLinkOptions -> ({*{#Char}},!*{#Int},*PlatformLinkOptions);

// Accessors; get's
plo_get_console_window :: !*PlatformLinkOptions -> (!Bool,!*PlatformLinkOptions);
plo_get_generate_symbol_table :: !*PlatformLinkOptions -> (!Bool,!*PlatformLinkOptions);
