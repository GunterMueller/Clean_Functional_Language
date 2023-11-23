implementation module elf_relocations;

import StdInt,StdChar,StdArray,StdBool,StdClass,StdFile,StdMisc;
import elf_linker_types;

TEXT_SECTION:==1;

(BYTE) string i :== toInt (string.[i]);

(WORD) :: !{#Char} !Int -> Int;
(WORD) string i = (string BYTE i<<8) bitor (string BYTE (i+1));
                                                                                                                        
(LONG) :: !{#Char} !Int -> Int;
(LONG) string i = (string BYTE i<<24) bitor (string BYTE (i+1)<<16) bitor (string BYTE (i+2)<<8) bitor (string BYTE (i+3));

(POINTER) :: !{#Char} !Int -> Int;
(POINTER) string i = (string BYTE i<<24) bitor (string BYTE (i+1)<<16) bitor (string BYTE (i+2)<<8) bitor (string BYTE (i+3));

(TBYTE) :: !{#Char} !Int -> Int;
(TBYTE) string i = (string BYTE i<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE (i+2));

(FWI) infixl;
(FWI) f i :== fwritei i f;

(FWP) infixl;
(FWP) f i :== fwritei i f;

(FWS) infixl;
(FWS) f s :== fwrites s f;

write_elf_header :: !*File -> *File;
write_elf_header file
	= file
			FWI 0x7f454c46
			FWI 0x01020100
			FWI 0
			FWI 0
			FWI 0x00010002
			FWI 1
			FWI 0
			FWI 0
			FWI 0x34
			FWI 0
			FWI 0x00340000
			FWI 0x00000028
			FWI 0x00090001;

write_shstrtab_end :: !*File -> *File;
write_shstrtab_end file
	= file
            FWS ".rela.text\000"
            FWS ".rela.data\000"
            FWS ".symtab\000"
            FWS ".strtab\000"
            FWS "\000\000"
            ;

write_symbol :: !Int !Int !Int !Int !*File -> *File;
write_symbol string_offset info_other_shndx value size file
	= file FWI string_offset FWI value FWI size FWI info_other_shndx;

count_text_relocations :: !Int !{#Char} !{!Symbol} !XcoffArray -> Int;
count_text_relocations old_n_module_relocations relocations symbol_array xcoff_a
	= count_relocations old_n_module_relocations relocations symbol_array xcoff_a;

count_data_relocations :: !Int !{#Char} !{!Symbol} !XcoffArray -> Int;
count_data_relocations old_n_module_relocations relocations symbol_array xcoff_a
	= count_relocations old_n_module_relocations relocations symbol_array xcoff_a;

count_relocations :: !Int !{#Char} !{!Symbol} !XcoffArray -> Int;
count_relocations old_n_module_relocations relocations symbol_array xcoff_a
	= count_relocations 0 0;
{
		count_relocations relocation_n n_module_relocations
			| relocation_n==old_n_module_relocations
				= n_module_relocations;
			# relocation_index=relocation_n * SIZE_OF_RELOCATION;
			  relocation_type=relocations BYTE (relocation_index+RELOCATION_TYPE_OFFSET);
			| relocation_type==R_SPARC_WDISP22 || relocation_type==R_SPARC_WDISP30
				# relocation_symbol_n=relocations TBYTE (relocation_index+RELOCATION_SYMBOL_N_OFFSET);
				= case symbol_array.[relocation_symbol_n] of {
					UndefinedLabel symbol_n
						= count_relocations (relocation_n+1) (n_module_relocations+1);
					_
						= count_relocations (relocation_n+1) n_module_relocations;
			  	};
			| relocation_type<>R_SPARC_NONE
				= count_relocations (relocation_n+1) (n_module_relocations+1);
				= count_relocations (relocation_n+1) n_module_relocations;
}

write_text_module_relocations :: !Symbol !Int !Int !SSymbolArray !XcoffArray !{#Int} !{#Int} !*File -> *File;
write_text_module_relocations symbol module_offset first_symbol_n symbol_array xcoff_a module_offset_a offset_a pe_file
	= write_module_relocations symbol module_offset first_symbol_n symbol_array xcoff_a module_offset_a offset_a pe_file;

write_data_module_relocations :: !Symbol !Int !Int !SSymbolArray !XcoffArray !{#Int} !{#Int} !*File -> *File;
write_data_module_relocations symbol module_offset first_symbol_n symbol_array xcoff_a module_offset_a offset_a pe_file
	= write_module_relocations symbol module_offset first_symbol_n symbol_array xcoff_a module_offset_a offset_a pe_file;

write_module_relocations :: !Symbol !Int !Int !SSymbolArray !XcoffArray !{#Int} !{#Int} !*File -> *File;
write_module_relocations (Module _ _ _ _ _ n_module_relocations relocations _) module_offset first_symbol_n symbol_array xcoff_a module_offset_a offset_a pe_file
	= write_relocations 0 n_module_relocations relocations pe_file;
{
	write_relocations relocation_n n_relocations relocations pe_file
		| relocation_n==n_relocations
			= pe_file;
			#	relocation_index=relocation_n * SIZE_OF_RELOCATION;
				relocation_type=relocations BYTE (relocation_index+RELOCATION_TYPE_OFFSET);
				relocation_symbol_n=relocations TBYTE (relocation_index+RELOCATION_SYMBOL_N_OFFSET);
				relocation_offset=relocations LONG relocation_index;
				relocation_addend=relocations LONG (relocation_index+8);
			= case symbol_array.[relocation_symbol_n] of {
				Module section_n _ _ _ _ _ _ _
					| relocation_type==R_SPARC_WDISP22 || relocation_type==R_SPARC_WDISP30 || relocation_type==R_SPARC_NONE
						= write_relocations_none relocation_offset section_n relocation_n n_relocations relocations pe_file;
						# real_label_offset=module_offset_a.[first_symbol_n+relocation_symbol_n];
						# relocation_addend=relocation_addend+real_label_offset;
						= write_relocations2 relocation_offset relocation_type section_n relocation_addend relocation_n n_relocations relocations pe_file;
				Label section_n label_offset section_symbol_n
					# (Module section_n virtual_label_offset _ _ _ _ _ _) = symbol_array.[section_symbol_n];
					| relocation_type==R_SPARC_WDISP22 || relocation_type==R_SPARC_WDISP30 || relocation_type==R_SPARC_NONE
						= write_relocations_none relocation_offset section_n relocation_n n_relocations relocations pe_file;
						# real_label_offset=module_offset_a.[first_symbol_n+section_symbol_n];
						# relocation_addend=relocation_addend+real_label_offset+label_offset-virtual_label_offset;
						= write_relocations2 relocation_offset relocation_type section_n relocation_addend relocation_n n_relocations relocations pe_file;
				ImportedLabelPlusOffset file_n symbol_n label_offset
					# (Module section_n _ _ _ _ _ _ _) = xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
					| relocation_type==R_SPARC_WDISP22 || relocation_type==R_SPARC_WDISP30 || relocation_type==R_SPARC_NONE
						= write_relocations_none relocation_offset section_n relocation_n n_relocations relocations pe_file;
						# real_label_offset = module_offset_a.[offset_a.[file_n]+symbol_n];
						# relocation_addend=relocation_addend+real_label_offset+label_offset;
						= write_relocations2 relocation_offset relocation_type section_n relocation_addend relocation_n n_relocations relocations pe_file;
				UndefinedLabel symbol_n
					= write_relocations2 relocation_offset relocation_type (symbol_n+4) relocation_addend relocation_n n_relocations relocations pe_file;
				ImportedLabel file_n symbol_n // for commons in .bss
					# (Module section_n _ _ _ _ _ _ _) = xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
					| relocation_type==R_SPARC_WDISP22 || relocation_type==R_SPARC_WDISP30 || relocation_type==R_SPARC_NONE
						= write_relocations_none relocation_offset section_n relocation_n n_relocations relocations pe_file;
						# real_label_offset = module_offset_a.[offset_a.[file_n]+symbol_n];
						# relocation_addend=relocation_addend+real_label_offset;
						= write_relocations2 relocation_offset relocation_type section_n relocation_addend relocation_n n_relocations relocations pe_file;
//					_
//						= write_relocations2 relocation_offset relocation_type relocation_symbol_n relocation_addend relocation_n n_relocations relocations pe_file;
			};

	write_relocations2 relocation_offset relocation_type relocation_symbol_n relocation_addend relocation_n n_relocations relocations pe_file
		#	pe_file = pe_file FWI (module_offset+relocation_offset) FWI (relocation_type bitor (relocation_symbol_n<<8)) FWI relocation_addend;
		=	write_relocations (relocation_n+1) n_relocations relocations pe_file;

	write_relocations_none relocation_offset relocation_symbol_n relocation_n n_relocations relocations pe_file
		=	write_relocations (relocation_n+1) n_relocations relocations pe_file;
}

relocate_text :: !.Int Int Int Int Int {#Char} {#SXcoff} {#Int} {#Int} {!Symbol} !*{#.Char} -> .{#Char};
relocate_text n_relocations virtual_address real_module_offset virtual_module_offset first_symbol_n relocations xcoff_a marked_offset_a0 module_offset_a  symbol_a text_a0
	= relocate_text 0 symbol_a text_a0;
	{
			relocate_text relocation_n symbol_a text_a0
				| relocation_n==n_relocations
					= text_a0;
					#	relocation_index=relocation_n * SIZE_OF_RELOCATION;
						relocation_type=relocations BYTE (relocation_index+RELOCATION_TYPE_OFFSET);
						relocation_symbol_n=relocations TBYTE (relocation_index+RELOCATION_SYMBOL_N_OFFSET);
						relocation_offset=relocations LONG relocation_index;
						relocation_addend=relocations LONG (relocation_index+8);
					
						text1 = case relocation_type of {
							R_SPARC_WDISP30
								-> relocate_wdisp30 symbol_a.[relocation_symbol_n] relocation_offset relocation_addend (relocation_offset-virtual_address)
									 virtual_module_offset real_module_offset module_offset_a first_symbol_n relocation_symbol_n symbol_a marked_offset_a0
									 xcoff_a text_a0;
							R_SPARC_WDISP22
								-> relocate_wdisp22 symbol_a.[relocation_symbol_n] relocation_offset relocation_addend (relocation_offset-virtual_address)
									 virtual_module_offset real_module_offset module_offset_a first_symbol_n relocation_symbol_n symbol_a marked_offset_a0
									 xcoff_a text_a0;
							R_SPARC_HI22
								-> text_a0;
							R_SPARC_LO10
								-> text_a0;
							R_SPARC_32
								-> text_a0;
							R_SPARC_UA32
								-> text_a0;
							R_SPARC_NONE
								-> text_a0;
							_
								-> abort "relocate text\n"
						}
					= relocate_text (relocation_n+1) symbol_a text1;
	}

relocate_data :: Int Int Int Int Int String Int {#Int} {#Int} {!Symbol} XcoffArray *{#Char}-> *{#Char};
relocate_data relocation_n n_relocations virtual_module_offset virtual_section_offset real_module_offset data_relocations 
		first_symbol_n module_offset_a marked_offset_a0 symbol_a xcoff_a data0
	| relocation_n==n_relocations
		= data0;
		#	relocation_index=relocation_n * SIZE_OF_RELOCATION;
			relocation_type=data_relocations BYTE (relocation_index+RELOCATION_TYPE_OFFSET);
			relocation_symbol_n=data_relocations TBYTE (relocation_index+RELOCATION_SYMBOL_N_OFFSET);
			relocation_offset=data_relocations LONG relocation_index;
			relocation_addend=data_relocations LONG (relocation_index+8);

			data1 = relocate_symbol relocation_type module_offset_a symbol_a marked_offset_a0 xcoff_a data0;
					with {
						relocate_symbol :: Int {#Int} {!Symbol} {#Int} XcoffArray *{#Char} -> *{#Char};
						relocate_symbol R_SPARC_32 module_offset_a symbol_a marked_offset_a0 xcoff_a data0
							= data0;
						relocate_symbol R_SPARC_UA32 module_offset_a symbol_a marked_offset_a0 xcoff_a data0
							= data0;
						relocate_symbol relocation_type module_offset_a symbol_a marked_offset_a0 xcoff_a data0
							= abort "relocate_symbol";
					}
		= relocate_data (relocation_n+1) n_relocations virtual_module_offset virtual_section_offset real_module_offset data_relocations
						first_symbol_n module_offset_a marked_offset_a0 symbol_a xcoff_a data1;

relocate_wdisp30 :: Symbol Int Int Int Int Int {#Int} Int Int {!Symbol} {#Int} XcoffArray *{#Char} -> *{#Char};
relocate_wdisp30 (Module TEXT_SECTION virtual_label_offset _ _ _ _ _ _) relocation_offset relocation_addend index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 xcoff_a text0
	# real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
	= store_wdisp30_at_offset ((virtual_module_offset-relocation_offset)+(real_label_offset-real_module_offset)+relocation_addend) index text0;
relocate_wdisp30 (Label _ /*TEXT_SECTION*/ offset module_n) relocation_offset relocation_addend index virtual_module_offset 
		real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 xcoff_a text0
	= case symbol_a.[module_n] of {
		Module TEXT_SECTION virtual_label_offset _ _ _ _ _ _
			# real_label_offset = module_offset_a.[first_symbol_n+module_n]+offset;
			-> store_wdisp30_at_offset ((virtual_label_offset-relocation_offset)+(real_label_offset-real_module_offset)+relocation_addend) index text0;
	};
relocate_wdisp30 (ImportedLabel file_n symbol_n) relocation_offset relocation_addend index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 xcoff_a text0
	# first_symbol_n = marked_offset_a0.[file_n];
	  symbol_a=xcoff_a.[file_n].symbol_table.symbols;
	= case symbol_a.[symbol_n] of {
		Module TEXT_SECTION _ _ _ _ _ _ _
			# real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
			-> store_wdisp30_at_offset ((virtual_module_offset-relocation_offset)+(real_label_offset-real_module_offset)+relocation_addend) index text0;
	};
relocate_wdisp30 (ImportedLabelPlusOffset file_n symbol_n label_offset) relocation_offset relocation_addend index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 xcoff_a text0
	# first_symbol_n = marked_offset_a0.[file_n];
	  symbol_a=xcoff_a.[file_n].symbol_table.symbols;
	= case symbol_a.[symbol_n] of {
		Module TEXT_SECTION _ _ _ _ _ _ _
			# real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
			->	store_wdisp30_at_offset ((virtual_module_offset-relocation_offset)+(real_label_offset-real_module_offset)+label_offset+relocation_addend) index text0;
	};
relocate_wdisp30 (UndefinedLabel _) relocation_offset relocation_addend index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 xcoff_a text
	= text;

relocate_wdisp22 :: Symbol Int Int Int Int Int {#Int} Int Int {!Symbol} {#Int} XcoffArray *{#Char} -> *{#Char};
relocate_wdisp22 (Module TEXT_SECTION virtual_label_offset _ _ _ _ _ _) relocation_offset relocation_addend index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 xcoff_a text0
	# real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
	= store_wdisp22_at_offset ((virtual_module_offset-relocation_offset)+(real_label_offset-real_module_offset)+relocation_addend) index text0;
relocate_wdisp22 (Label _ /*TEXT_SECTION*/ offset module_n) relocation_offset relocation_addend index virtual_module_offset 
		real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 xcoff_a text0
	= case symbol_a.[module_n] of {
		Module TEXT_SECTION virtual_label_offset _ _ _ _ _ _
			# real_label_offset = module_offset_a.[first_symbol_n+module_n]+offset;
			-> store_wdisp22_at_offset ((virtual_label_offset-relocation_offset)+(real_label_offset-real_module_offset)+relocation_addend) index text0;
	};
relocate_wdisp22 (ImportedLabel file_n symbol_n) relocation_offset relocation_addend index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 xcoff_a text0
	# first_symbol_n = marked_offset_a0.[file_n];
	  symbol_a=xcoff_a.[file_n].symbol_table.symbols;
	= case symbol_a.[symbol_n] of {
		Module TEXT_SECTION _ _ _ _ _ _ _
			# real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
			-> store_wdisp22_at_offset ((virtual_module_offset-relocation_offset)+(real_label_offset-real_module_offset)+relocation_addend) index text0;
	};
relocate_wdisp22 (ImportedLabelPlusOffset file_n symbol_n label_offset) relocation_offset relocation_addend index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 xcoff_a text0
	# first_symbol_n = marked_offset_a0.[file_n];
	  symbol_a=xcoff_a.[file_n].symbol_table.symbols;
	= case symbol_a.[symbol_n] of {
		Module TEXT_SECTION _ _ _ _ _ _ _
			# real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
			->	store_wdisp22_at_offset ((virtual_module_offset-relocation_offset)+(real_label_offset-real_module_offset)+label_offset+relocation_addend) index text0;
	};
relocate_wdisp22 (UndefinedLabel _) relocation_offset relocation_addend index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 xcoff_a text
	= text;

store_wdisp30_at_offset :: Int Int *{#Char} -> *{#Char};
store_wdisp30_at_offset w index array
	# w=w>>2;
	#! v0=toInt array.[index];
	# v0=(v0 bitand 0xc0) bitor ((w>>24) bitand 0x3f);
	= {array & [index]=toChar v0,[index+1]=toChar (w>>16),[index+2]=toChar (w>>8),[index+3]=toChar w};

store_wdisp22_at_offset :: Int Int *{#Char} -> *{#Char};
store_wdisp22_at_offset w index array
	# w=w>>2;
	#! v1=toInt array.[index+1];
	# v1=(v1 bitand 0xc0) bitor ((w>>16) bitand 0x3f);
	= {array & [index+1]=toChar v1,[index+2]=toChar (w>>8),[index+3]=toChar w};

