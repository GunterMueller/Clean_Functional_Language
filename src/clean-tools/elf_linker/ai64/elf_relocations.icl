implementation module elf_relocations;

import StdInt,StdChar,StdClass,StdArray,StdFile,StdBool,StdString,StdMisc;
import elf_linker_types;

R_X86_64_NONE:==0;
R_X86_64_64:==1;
R_X86_64_PC32:==2;
R_X86_64_PLT32:==4;
R_X86_64_32:==10;
R_X86_64_32S:==11;

TEXT_SECTION:==1;
DATA_SECTION:==2;

(BYTE) string i :== toInt (string.[i]);
                                                                                                                        
(WORD) :: !{#Char} !Int -> Int;
(WORD) string i = (string BYTE (i+1)<<8) bitor (string BYTE i);
                                                                                                                        
(LONG) :: !{#Char} !Int -> Int;
(LONG) string i
    = (string BYTE (i+3)<<24) bitor (string BYTE (i+2)<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE i);

(POINTER) :: !{#Char} !Int -> Int;
(POINTER) string i
	= (string BYTE (i+7)<<56) bitor (string BYTE (i+6)<<48) bitor (string BYTE (i+5)<<40) bitor (string BYTE (i+4)<<32) bitor
	  (string BYTE (i+3)<<24) bitor (string BYTE (i+2)<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE i);

(TBYTE) :: !{#Char} !Int -> Int;
(TBYTE) string i = (string BYTE (i+2)<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE i);

(FWI) infixl;
(FWI) f i :== fwritei i f;

(FWL) infixl;
(FWL) f i :== fwritei (i>>32) (fwritei i f);

(FWP) infixl;
(FWP) f i :== fwritei (i>>32) (fwritei i f);

(FWS) infixl;
(FWS) f s :== fwrites s f;

write_elf_header :: !*File -> *File;
write_elf_header file
	= file
			FWI 0x464c457f
			FWI 0x00010102
			FWI 0
			FWI 0
			FWI 0x003e0001
			FWI 1
			FWL 0
			FWL 0
			FWL 0x40
			FWI 0
			FWI 0x00000040
			FWI 0x00400000
			FWI 0x00010009;

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
	= file FWI string_offset FWI info_other_shndx FWL value FWL size;

count_text_relocations :: !Int !{#Char} !{!Symbol} !XcoffArray -> Int;
count_text_relocations old_n_module_relocations relocations symbol_array xcoff_a
	= count_relocations 0 0;
{
	count_relocations :: !Int !Int -> Int;
	count_relocations relocation_n n_module_relocations
		| relocation_n==old_n_module_relocations
			= n_module_relocations;
		# relocation_index=relocation_n * SIZE_OF_RELOCATION;
		  relocation_type=get_relocation_type relocations relocation_index;
		| relocation_type<>R_X86_64_PC32
			| relocation_type==R_X86_64_NONE
				= count_relocations (relocation_n+1) n_module_relocations;
				= count_relocations (relocation_n+1) (n_module_relocations+1);
		# relocation_symbol_n=get_relocation_symbol_n relocations relocation_index;
		= case symbol_array.[relocation_symbol_n] of {
			UndefinedLabel symbol_n
				= count_relocations (relocation_n+1) (n_module_relocations+1);
			Module section_n virtual_label_offset _ _ _ _ _ _
				| section_n==TEXT_SECTION
					= count_relocations (relocation_n+1) n_module_relocations;
					= count_relocations (relocation_n+1) (n_module_relocations+1);
			Label section_n label_offset section_symbol_n
				# (Module section_n virtual_label_offset _ _ _ _ _ _) = symbol_array.[section_symbol_n];
				| section_n==TEXT_SECTION
					= count_relocations (relocation_n+1) n_module_relocations;
					= count_relocations (relocation_n+1) (n_module_relocations+1);
			ImportedLabel file_n symbol_n
				# (Module section_n _ _ _ _ _ _ _) = xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
				| section_n==TEXT_SECTION
					= count_relocations (relocation_n+1) n_module_relocations;
					= count_relocations (relocation_n+1) (n_module_relocations+1);
			ImportedLabelPlusOffset file_n symbol_n label_offset
				# (Module section_n _ _ _ _ _ _ _) = xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
				| section_n==TEXT_SECTION
					= count_relocations (relocation_n+1) n_module_relocations;
					= count_relocations (relocation_n+1) (n_module_relocations+1);
				= count_relocations (relocation_n+1) n_module_relocations;
		  };
}

count_data_relocations :: !Int !{#Char} !{!Symbol} !XcoffArray -> Int;
count_data_relocations old_n_module_relocations relocations symbol_array xcoff_a
	= count_relocations 0 0;
{
	count_relocations :: !Int !Int -> Int;
	count_relocations relocation_n n_module_relocations
		| relocation_n==old_n_module_relocations
			= n_module_relocations;
		# relocation_index=relocation_n * SIZE_OF_RELOCATION;
		  relocation_type=get_relocation_type relocations relocation_index;
		| relocation_type<>R_X86_64_PC32
			| relocation_type==R_X86_64_NONE
				= count_relocations (relocation_n+1) n_module_relocations;
				= count_relocations (relocation_n+1) (n_module_relocations+1);
		# relocation_symbol_n=get_relocation_symbol_n relocations relocation_index;
		= case symbol_array.[relocation_symbol_n] of {
			UndefinedLabel symbol_n
				= count_relocations (relocation_n+1) (n_module_relocations+1);
			Module section_n virtual_label_offset _ _ _ _ _ _
				| section_n==DATA_SECTION
					= count_relocations (relocation_n+1) n_module_relocations;
					= count_relocations (relocation_n+1) (n_module_relocations+1);
			Label section_n label_offset section_symbol_n
				# (Module section_n virtual_label_offset _ _ _ _ _ _) = symbol_array.[section_symbol_n];
				| section_n==DATA_SECTION
					= count_relocations (relocation_n+1) n_module_relocations;
					= count_relocations (relocation_n+1) (n_module_relocations+1);
			ImportedLabel file_n symbol_n
				# (Module section_n _ _ _ _ _ _ _) = xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
				| section_n==DATA_SECTION
					= count_relocations (relocation_n+1) n_module_relocations;
					= count_relocations (relocation_n+1) (n_module_relocations+1);
			ImportedLabelPlusOffset file_n symbol_n label_offset
				# (Module section_n _ _ _ _ _ _ _) = xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
				| section_n==DATA_SECTION
					= count_relocations (relocation_n+1) n_module_relocations;
					= count_relocations (relocation_n+1) (n_module_relocations+1);
				= count_relocations (relocation_n+1) n_module_relocations;
		  };
}

write_text_module_relocations :: !Symbol !Int !Int !SSymbolArray !XcoffArray !{#Int} !{#Int} !*File -> *File;
write_text_module_relocations (Module _ _ _ _ _ n_module_relocations relocations _) module_offset first_symbol_n symbol_array xcoff_a module_offset_a offset_a pe_file
	= write_relocations 0 n_module_relocations relocations pe_file;
{
	write_relocations relocation_n n_relocations relocations pe_file
		| relocation_n==n_relocations
			= pe_file;
			#	relocation_index=relocation_n * SIZE_OF_RELOCATION;
				relocation_type=get_relocation_type relocations relocation_index;
			| relocation_type==R_X86_64_NONE
				= write_relocations_none relocation_n n_relocations relocations pe_file;
			#	relocation_symbol_n=get_relocation_symbol_n relocations relocation_index;
				relocation_offset=relocations LONG relocation_index;
				relocation_addend=relocations POINTER (relocation_index+16);
			= case symbol_array.[relocation_symbol_n] of {
				Module section_n _ _ _ _ _ _ _
					| relocation_type==R_X86_64_PC32 && section_n==TEXT_SECTION
						= write_relocations_none relocation_n n_relocations relocations pe_file;						
						# real_label_offset=module_offset_a.[first_symbol_n+relocation_symbol_n];
						# relocation_addend=relocation_addend+real_label_offset;
						= write_relocations2 relocation_offset relocation_type section_n relocation_addend relocation_n n_relocations relocations pe_file;
				Label section_n label_offset section_symbol_n
					# (Module section_n virtual_label_offset _ _ _ _ _ _) = symbol_array.[section_symbol_n];
					| relocation_type==R_X86_64_PC32 && section_n==TEXT_SECTION
						= write_relocations_none relocation_n n_relocations relocations pe_file;
						# real_label_offset=module_offset_a.[first_symbol_n+section_symbol_n];
						# relocation_addend=relocation_addend+real_label_offset+label_offset-virtual_label_offset;
						= write_relocations2 relocation_offset relocation_type section_n relocation_addend relocation_n n_relocations relocations pe_file;
				ImportedLabelPlusOffset file_n symbol_n label_offset
					# (Module section_n _ _ _ _ _ _ _) = xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
					| relocation_type==R_X86_64_PC32 && section_n==TEXT_SECTION
						= write_relocations_none relocation_n n_relocations relocations pe_file;
						# real_label_offset = module_offset_a.[offset_a.[file_n]+symbol_n];
						# relocation_addend=relocation_addend+real_label_offset+label_offset;
						= write_relocations2 relocation_offset relocation_type section_n relocation_addend relocation_n n_relocations relocations pe_file;
				UndefinedLabel symbol_n
					# relocation_symbol_n=symbol_n+4;
					= write_relocations2 relocation_offset relocation_type relocation_symbol_n relocation_addend relocation_n n_relocations relocations pe_file;
				ImportedLabel file_n symbol_n // for commons in .bss
					# (Module section_n _ _ _ _ _ _ _) = xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
					| relocation_type==R_X86_64_PC32 && section_n==TEXT_SECTION
						= write_relocations_none relocation_n n_relocations relocations pe_file;
						# real_label_offset = module_offset_a.[offset_a.[file_n]+symbol_n];
						# relocation_addend=relocation_addend+real_label_offset;
						= write_relocations2 relocation_offset relocation_type section_n relocation_addend relocation_n n_relocations relocations pe_file;
//				_
//					= write_relocations2 relocation_offset relocation_type relocation_symbol_n relocation_addend relocation_n n_relocations relocations pe_file;
			};

	write_relocations2 relocation_offset relocation_type relocation_symbol_n relocation_addend relocation_n n_relocations relocations pe_file
		#	pe_file = pe_file FWL (module_offset+relocation_offset) FWL (relocation_type bitor (relocation_symbol_n<<32)) FWL relocation_addend;
		=	write_relocations (relocation_n+1) n_relocations relocations pe_file;

	write_relocations_none relocation_n n_relocations relocations pe_file
		=	write_relocations (relocation_n+1) n_relocations relocations pe_file;
}

write_data_module_relocations :: !Symbol !Int !Int !SSymbolArray !XcoffArray !{#Int} !{#Int} !*File -> *File;
write_data_module_relocations (Module _ _ _ _ _ n_module_relocations relocations _) module_offset first_symbol_n symbol_array xcoff_a module_offset_a offset_a pe_file
	= write_relocations 0 n_module_relocations relocations pe_file;
{
	write_relocations relocation_n n_relocations relocations pe_file
		| relocation_n==n_relocations
			= pe_file;
			#	relocation_index=relocation_n * SIZE_OF_RELOCATION;
				relocation_type=get_relocation_type relocations relocation_index;
			| relocation_type==R_X86_64_NONE
				= write_relocations_none relocation_n n_relocations relocations pe_file;
			#	relocation_symbol_n=get_relocation_symbol_n relocations relocation_index;
				relocation_offset=relocations LONG relocation_index;
				relocation_addend=relocations POINTER (relocation_index+16);
			= case symbol_array.[relocation_symbol_n] of {
				Module section_n _ _ _ _ _ _ _
					| relocation_type==R_X86_64_PC32 && section_n==DATA_SECTION
						= write_relocations_none relocation_n n_relocations relocations pe_file;						
						# real_label_offset=module_offset_a.[first_symbol_n+relocation_symbol_n];
						# relocation_addend=relocation_addend+real_label_offset;
						= write_relocations2 relocation_offset relocation_type section_n relocation_addend relocation_n n_relocations relocations pe_file;
				Label section_n label_offset section_symbol_n
					# (Module section_n virtual_label_offset _ _ _ _ _ _) = symbol_array.[section_symbol_n];
					| relocation_type==R_X86_64_PC32 && section_n==DATA_SECTION
						= write_relocations_none relocation_n n_relocations relocations pe_file;
						# real_label_offset=module_offset_a.[first_symbol_n+section_symbol_n];
						# relocation_addend=relocation_addend+real_label_offset+label_offset-virtual_label_offset;
						= write_relocations2 relocation_offset relocation_type section_n relocation_addend relocation_n n_relocations relocations pe_file;
				ImportedLabelPlusOffset file_n symbol_n label_offset
					# (Module section_n _ _ _ _ _ _ _) = xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
					| relocation_type==R_X86_64_PC32 && section_n==DATA_SECTION
						= write_relocations_none relocation_n n_relocations relocations pe_file;
						# real_label_offset = module_offset_a.[offset_a.[file_n]+symbol_n];
						# relocation_addend=relocation_addend+real_label_offset+label_offset;
						= write_relocations2 relocation_offset relocation_type section_n relocation_addend relocation_n n_relocations relocations pe_file;
				UndefinedLabel symbol_n
					# relocation_symbol_n=symbol_n+4;
					= write_relocations2 relocation_offset relocation_type relocation_symbol_n relocation_addend relocation_n n_relocations relocations pe_file;
				ImportedLabel file_n symbol_n // for commons in .bss
					# (Module section_n _ _ _ _ _ _ _) = xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
					| relocation_type==R_X86_64_PC32 && section_n==DATA_SECTION
						= write_relocations_none relocation_n n_relocations relocations pe_file;
						# real_label_offset = module_offset_a.[offset_a.[file_n]+symbol_n];
						# relocation_addend=relocation_addend+real_label_offset;
						= write_relocations2 relocation_offset relocation_type section_n relocation_addend relocation_n n_relocations relocations pe_file;
//				_
//					= write_relocations2 relocation_offset relocation_type relocation_symbol_n relocation_addend relocation_n n_relocations relocations pe_file;
			};

	write_relocations2 relocation_offset relocation_type relocation_symbol_n relocation_addend relocation_n n_relocations relocations pe_file
		#	pe_file = pe_file FWL (module_offset+relocation_offset) FWL (relocation_type bitor (relocation_symbol_n<<32)) FWL relocation_addend;
		=	write_relocations (relocation_n+1) n_relocations relocations pe_file;

	write_relocations_none relocation_n n_relocations relocations pe_file
		=	write_relocations (relocation_n+1) n_relocations relocations pe_file;
}

relocate_text :: !Int Int Int Int Int !{#Char} {#SXcoff} {#Int} {#Int} {!Symbol} !*{#Char} -> *{#Char};
relocate_text n_relocations virtual_address real_module_offset virtual_module_offset first_symbol_n relocations xcoff_a marked_offset_a0 module_offset_a symbol_a text_a0
	= relocate_text 0 symbol_a text_a0;
	{
		relocate_text :: !Int !{!Symbol} !*{#Char} -> *{#Char};
		relocate_text relocation_n symbol_a text
			| relocation_n==n_relocations
				= text;
			# relocation_index=relocation_n * SIZE_OF_RELOCATION;
			  relocation_type=get_relocation_type relocations relocation_index;
			| relocation_type==R_X86_64_PC32
				# relocation_symbol_n=get_relocation_symbol_n relocations relocation_index;
				  relocation_offset=relocations LONG relocation_index;
				  relocation_addend=relocations POINTER (relocation_index+16);
				# text = relocate_branch symbol_a.[relocation_symbol_n] relocation_offset relocation_addend
							(relocation_offset-virtual_address) virtual_module_offset
							real_module_offset module_offset_a first_symbol_n relocation_symbol_n symbol_a marked_offset_a0 xcoff_a text;
				= relocate_text (relocation_n+1) symbol_a text;
			| relocation_type==R_X86_64_32S || relocation_type==R_X86_64_32 || relocation_type==R_X86_64_PLT32 || relocation_type==R_X86_64_NONE
				= relocate_text (relocation_n+1) symbol_a text;
				= abort ("relocation "+++toString relocation_type+++" in text section not supported")
	}

relocate_data :: !Int !Int Int Int Int !{#Char} Int {#Int} {#Int} {!Symbol} XcoffArray !*{#Char}-> *{#Char};
relocate_data relocation_n n_relocations virtual_module_offset virtual_section_offset real_module_offset data_relocations 
		first_symbol_n module_offset_a marked_offset_a0 symbol_a xcoff_a data
	| relocation_n==n_relocations
		= data;
	# relocation_index=relocation_n * SIZE_OF_RELOCATION;
	  relocation_type=get_relocation_type data_relocations relocation_index;
	| relocation_type==R_X86_64_32S || relocation_type==R_X86_64_32 || relocation_type==R_X86_64_64
		= relocate_data (relocation_n+1) n_relocations virtual_module_offset virtual_section_offset real_module_offset data_relocations
						first_symbol_n module_offset_a marked_offset_a0 symbol_a xcoff_a data;
	| relocation_type==R_X86_64_PC32
		# relocation_symbol_n=get_relocation_symbol_n data_relocations relocation_index;
		# relocation_offset=data_relocations LONG relocation_index;
		# relocation_addend=data_relocations POINTER (relocation_index+16);
		# data = relocate_relative_data_offset symbol_a.[relocation_symbol_n] relocation_offset relocation_addend
					(relocation_offset-virtual_section_offset) virtual_module_offset
					real_module_offset module_offset_a first_symbol_n relocation_symbol_n symbol_a marked_offset_a0 xcoff_a data;
		= relocate_data (relocation_n+1) n_relocations virtual_module_offset virtual_section_offset real_module_offset data_relocations
						first_symbol_n module_offset_a marked_offset_a0 symbol_a xcoff_a data;
		= abort ("relocation "+++toString relocation_type+++" in data section not supported");

relocate_branch :: Symbol Int Int Int Int Int {#Int} Int Int {!Symbol} {#Int} XcoffArray *{#Char} -> *{#Char};
relocate_branch (Module section_n virtual_label_offset _ _ _ _ _ _) relocation_offset relocation_addend index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 xcoff_a text0
	| section_n==TEXT_SECTION
		# real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
		= store_long_at_offset ((virtual_module_offset-relocation_offset)+(real_label_offset-real_module_offset)+relocation_addend) index text0;
		= text0;
relocate_branch (Label _ offset module_n) relocation_offset relocation_addend index virtual_module_offset 
		real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 xcoff_a text0
	= case symbol_a.[module_n] of {
		Module section_n virtual_label_offset _ _ _ _ _ _
			| section_n==TEXT_SECTION
				# real_label_offset = module_offset_a.[first_symbol_n+ /*symbol_n*/ module_n]+offset;
				-> store_long_at_offset ((virtual_label_offset-relocation_offset)+(real_label_offset-real_module_offset)+relocation_addend) index text0;
				-> text0;
	};
relocate_branch (ImportedLabel file_n symbol_n) relocation_offset relocation_addend index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 xcoff_a text0
	| file_n<0
		# real_label_offset = module_offset_a.[marked_offset_a0.[file_n + size marked_offset_a0]+symbol_n];
		= store_long_at_offset ((virtual_module_offset-relocation_offset)+(real_label_offset-real_module_offset)+relocation_addend) index text0;
		# first_symbol_n = marked_offset_a0.[file_n];
		  symbol_a=xcoff_a.[file_n].symbol_table.symbols;
		= case (symbol_a.[symbol_n]) of {
			Module section_n _ _ _ _ _ _ _
				| section_n==TEXT_SECTION
					# real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
					-> store_long_at_offset ((virtual_module_offset-relocation_offset)+(real_label_offset-real_module_offset)+relocation_addend) index text0;
					-> text0;
//			_ -> abort ("relocate_branch "+++file_name+++" "+++toString file_n+++" "+++toString symbol_n);
			};
relocate_branch (ImportedLabelPlusOffset file_n symbol_n label_offset) relocation_offset relocation_addend index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 xcoff_a text0
	# first_symbol_n = marked_offset_a0.[file_n];
	  symbol_a=xcoff_a.[file_n].symbol_table.symbols;
	=	case (symbol_a.[symbol_n]) of {
			Module section_n _ _ _ _ _ _ _
				| section_n==TEXT_SECTION
					# real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
					->	store_long_at_offset ((virtual_module_offset-relocation_offset)+(real_label_offset-real_module_offset)+label_offset+relocation_addend) index text0;
					-> text0;
		};
relocate_branch (UndefinedLabel _) relocation_offset relocation_addend index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 xcoff_a text
		= text;

// same as relocate_branch, but for the data section
relocate_relative_data_offset :: Symbol Int Int Int Int Int {#Int} Int Int {!Symbol} {#Int} XcoffArray *{#Char} -> *{#Char};
relocate_relative_data_offset (Module section_n virtual_label_offset _ _ _ _ _ _) relocation_offset relocation_addend index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 xcoff_a data
	| section_n==DATA_SECTION
		# real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
		= store_long_at_offset ((virtual_module_offset-relocation_offset)+(real_label_offset-real_module_offset)+relocation_addend) index data;
		= data;
relocate_relative_data_offset (Label _ offset module_n) relocation_offset relocation_addend index virtual_module_offset 
		real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 xcoff_a data
	= case symbol_a.[module_n] of {
		Module section_n virtual_label_offset _ _ _ _ _ _
			| section_n==DATA_SECTION
				# real_label_offset = module_offset_a.[first_symbol_n+ /*symbol_n*/ module_n]+offset;
				-> store_long_at_offset ((virtual_label_offset-relocation_offset)+(real_label_offset-real_module_offset)+relocation_addend) index data;
				-> data;
	};
relocate_relative_data_offset (ImportedLabel file_n symbol_n) relocation_offset relocation_addend index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 xcoff_a data
	| file_n<0
		# real_label_offset = module_offset_a.[marked_offset_a0.[file_n + size marked_offset_a0]+symbol_n];
		= store_long_at_offset ((virtual_module_offset-relocation_offset)+(real_label_offset-real_module_offset)+relocation_addend) index data;
		# first_symbol_n = marked_offset_a0.[file_n];
		  symbol_a=xcoff_a.[file_n].symbol_table.symbols;
		= case (symbol_a.[symbol_n]) of {
			Module section_n _ _ _ _ _ _ _
				| section_n==DATA_SECTION
					# real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
					-> store_long_at_offset ((virtual_module_offset-relocation_offset)+(real_label_offset-real_module_offset)+relocation_addend) index data;
					-> data;
//			_ -> abort ("relocate_relative_data_offset "+++file_name+++" "+++toString file_n+++" "+++toString symbol_n);
			};
relocate_relative_data_offset (ImportedLabelPlusOffset file_n symbol_n label_offset) relocation_offset relocation_addend index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 xcoff_a data
	# first_symbol_n = marked_offset_a0.[file_n];
	  symbol_a=xcoff_a.[file_n].symbol_table.symbols;
	=	case (symbol_a.[symbol_n]) of {
			Module section_n _ _ _ _ _ _ _
				| section_n==DATA_SECTION
					# real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
					->	store_long_at_offset ((virtual_module_offset-relocation_offset)+(real_label_offset-real_module_offset)+label_offset+relocation_addend) index data;
					-> data;
		};
relocate_relative_data_offset (UndefinedLabel _) relocation_offset relocation_addend index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 xcoff_a data
		= data;

store_long_at_offset :: !Int !Int !*{#Char} -> *{#Char};
store_long_at_offset v index array
	= {array & [index]=toChar v,[index+1]=toChar (v>>8),[index+2]=toChar (v>>16),[index+3]=toChar (v>>24)};
