definition module xcoff;

page_size :== 4096;

SIZE_OF_HEADER:==20;
SIZE_OF_SECTION_HEADER:==40;
SIZE_OF_SYMBOL:==18;
SIZE_OF_RELOCATION:==10;
C_EXT:==2;
C_STAT:==3;
C_LABEL:==6;
C_FUNCTION:==101;
C_FILE:==103;

N_UNDEF:==0;
TEXT_SECTION:==1;
DATA_SECTION:==2;
BSS_SECTION:==3;
N_ABS:==0xffff;
 
REL_DIR32:==6;
REL_REL32:==024;
// MS-DOS Stub ----------------------------------------
s_ms_dos_header					:== 64;

// Signature ------------------------------------------
s_pe_header						:== 4;

// COFF Header ----------------------------------------
s_xcoff_header					:== 20;

// Machine Types
IMAGE_FILE_MACHINE_I386			:== 0x014c;

// Characteristics
IMAGE_FILE_RELOCS_STRIPPED		:== 0x0001;
IMAGE_FILE_EXECUTABLE_IMAGE		:== 0x0002;
IMAGE_FILE_LINE_NUMS_STRIPPED	:== 0x0004;
IMAGE_FILE_LOCAL_SYMS_STRIPPED	:== 0x0008;
IMAGE_FILE_32BIT_MACHINE		:== 0x0100;
IMAGE_FILE_DLL					:== 0x2000;

// Optional Header ------------------------------------
s_optional_header				:== 0x00e0;
n_data_directories				:== 16;

// Windows NT Subsystem
IMAGE_SUBSYSTEM_WINDOWS_GUI		:== 2;
IMAGE_SUBSYSTEM_WINDOWS_CUI		:== 3;
	
// Section Table --------------------------------------
// General
s_section_table_entry				:== 40;
s_section_name 						:== 8;

// Section Flags
IMAGE_SCN_CNT_CODE					:== 0x00000020;
IMAGE_SCN_CNT_INITIALIZED_DATA		:== 0x00000040;
IMAGE_SCN_CNT_UNINITIALIZED_DATA 	:== 0x00000080;
IMAGE_SCN_MEM_DISCARDABLE			:== 0x02000000;
IMAGE_SCN_MEM_EXECUTE				:== 0x20000000;
IMAGE_SCN_MEM_READ					:== 0x40000000;
IMAGE_SCN_MEM_WRITE					:== 0x80000000;

// .edata constants
s_export_directory_table		:== 40;
s_export_address_table_entry 	:== 4;
s_export_name_pointer_entry 	:== 4;
s_export_ordinal_entry			:== 2;

// .reloc Section -------------------------------------
s_fixup_header					:== 8;
s_fixup_entry					:== 2;

// block entry
i_reloc_offset					:== 0;
i_reloc_type					:== 12;
					
IMAGE_REL_BASED_HIGHLOW			:== 3;