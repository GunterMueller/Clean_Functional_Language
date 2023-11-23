implementation module elf_relocations;

import StdInt,StdChar,StdClass,StdArray,StdFile;
import elf_linker_types;

TEXT_SECTION:==1;

(BYTE) string i :== toInt (string.[i]);
                                                                                                                        
(WORD) :: !{#Char} !Int -> Int;
(WORD) string i = (string BYTE (i+1)<<8) bitor (string BYTE i);
                                                                                                                        
(LONG) :: !{#Char} !Int -> Int;
(LONG) string i
    = (string BYTE (i+3)<<24) bitor (string BYTE (i+2)<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE i);

(POINTER) :: !{#Char} !Int -> Int;
(POINTER) string i
    = (string BYTE (i+3)<<24) bitor (string BYTE (i+2)<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE i);

(TBYTE) :: !{#Char} !Int -> Int;
(TBYTE) string i = (string BYTE (i+2)<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE i);

(FWI) infixl;
(FWI) f i :== fwritei i f;

(FWP) infixl;
(FWP) f i :== fwritei i f;

(FWS) infixl;
(FWS) f s :== fwrites s f;

write_elf_header :: !*File -> *File;
write_elf_header file
	= file
			FWI 0x464c457f
			FWI 0x00010101
			FWI 0
			FWI 0
			FWI 0x00030001
			FWI 1
			FWI 0
			FWI 0
			FWI 0x34
			FWI 0
			FWI 0x00000034
			FWI 0x00280000
			FWI 0x00010009;

write_shstrtab_end :: !*File -> *File;
write_shstrtab_end file
	= file
            FWS ".rel.text\000"
            FWS ".rel.data\000"
            FWS ".symtab\000"
            FWS ".strtab\000";

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
			| relocation_type<>R_386_PC32
				= count_relocations (relocation_n+1) (n_module_relocations+1);
			# relocation_symbol_n=relocations TBYTE (relocation_index+RELOCATION_SYMBOL_N_OFFSET);
			= case symbol_array.[relocation_symbol_n] of {
				UndefinedLabel symbol_n
					= count_relocations (relocation_n+1) (n_module_relocations+1);
				_
					= count_relocations (relocation_n+1) n_module_relocations;
			  };
}

write_text_module_relocations :: !Symbol !Int !Int !SSymbolArray !XcoffArray !{#Int} !{#Int} !*File -> *File;
write_text_module_relocations symbol module_offset file_symbol_index symbol_array xcoff_a module_offset_a offset_a pe_file
	= write_module_relocations symbol module_offset file_symbol_index symbol_array xcoff_a module_offset_a offset_a pe_file;

write_data_module_relocations :: !Symbol !Int !Int !SSymbolArray !XcoffArray !{#Int} !{#Int} !*File -> *File;
write_data_module_relocations symbol module_offset file_symbol_index symbol_array xcoff_a module_offset_a offset_a pe_file
	= write_module_relocations symbol module_offset file_symbol_index symbol_array xcoff_a module_offset_a offset_a pe_file;

write_module_relocations :: !Symbol !Int !Int !SSymbolArray !XcoffArray !{#Int} !{#Int} !*File -> *File;
write_module_relocations (Module _ _ _ _ _ n_module_relocations relocations _) module_offset file_symbol_index symbol_array xcoff_a module_offset_a offset_a pe_file
	= write_relocations 0 n_module_relocations relocations pe_file;
{
	write_relocations relocation_n n_relocations relocations pe_file
		| relocation_n==n_relocations
			= pe_file;
			#	relocation_index=relocation_n * SIZE_OF_RELOCATION;
				relocation_type=relocations BYTE (relocation_index+RELOCATION_TYPE_OFFSET);
				relocation_symbol_n=relocations TBYTE (relocation_index+RELOCATION_SYMBOL_N_OFFSET);
				relocation_offset=relocations LONG relocation_index;
			= case symbol_array.[relocation_symbol_n] of {
				Module section_n _ _ _ _ _ _ _
					# relocation_symbol_n=section_n;
					| relocation_type==R_386_PC32
						= write_relocations_none relocation_offset relocation_symbol_n relocation_n n_relocations relocations pe_file;
						= write_relocations2 relocation_offset relocation_type relocation_symbol_n relocation_n n_relocations relocations pe_file;
				Label section_n label_offset section_symbol_n
					# (Module section_n _ _ _ _ _ _ _) = symbol_array.[section_symbol_n];
					# relocation_symbol_n=section_n;
					| relocation_type==R_386_PC32
						= write_relocations_none relocation_offset relocation_symbol_n relocation_n n_relocations relocations pe_file;
						= write_relocations2 relocation_offset relocation_type relocation_symbol_n relocation_n n_relocations relocations pe_file;
				ImportedLabelPlusOffset file_n symbol_n label_offset
					# (Module section_n _ _ _ _ _ _ _) = xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
					# relocation_symbol_n=section_n;
					| relocation_type==R_386_PC32
						= write_relocations_none relocation_offset relocation_symbol_n relocation_n n_relocations relocations pe_file;
						= write_relocations2 relocation_offset relocation_type relocation_symbol_n relocation_n n_relocations relocations pe_file;
				UndefinedLabel symbol_n
					# relocation_symbol_n=symbol_n+4;
					= write_relocations2 relocation_offset relocation_type relocation_symbol_n relocation_n n_relocations relocations pe_file;
				ImportedLabel file_n symbol_n // for commons in .bss
					# (Module section_n _ _ _ _ _ _ _) = xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
					# relocation_symbol_n=section_n;
					| relocation_type==R_386_PC32
						= write_relocations_none relocation_offset relocation_symbol_n relocation_n n_relocations relocations pe_file;
						= write_relocations2 relocation_offset relocation_type relocation_symbol_n relocation_n n_relocations relocations pe_file;
				_
					= write_relocations2 relocation_offset relocation_type relocation_symbol_n relocation_n n_relocations relocations pe_file;
			};

	write_relocations2 relocation_offset relocation_type relocation_symbol_n relocation_n n_relocations relocations pe_file
		#	pe_file = pe_file FWI (module_offset+relocation_offset) FWI (relocation_type bitor (relocation_symbol_n<<8));
		=	write_relocations (relocation_n+1) n_relocations relocations pe_file;

	write_relocations_none relocation_offset relocation_symbol_n relocation_n n_relocations relocations pe_file
//			#	pe_file = pe_file FWI (module_offset+relocation_offset) FWI (R_386_NONE bitor (relocation_symbol_n<<8));
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
				
					text1 = case relocation_type of {
						R_386_PC32
							-> relocate_branch symbol_a.[relocation_symbol_n] relocation_offset (relocation_offset-virtual_address) virtual_module_offset
								real_module_offset module_offset_a first_symbol_n relocation_symbol_n symbol_a marked_offset_a0 xcoff_a text_a0;
						R_386_32
							-> relocate_long_pos symbol_a.[relocation_symbol_n] (relocation_offset-virtual_address) module_offset_a 
								first_symbol_n relocation_symbol_n symbol_a marked_offset_a0 xcoff_a text_a0;
						R_386_PLT32
							-> text_a0;
						R_386_NONE
							-> text_a0;
					}
				= relocate_text (relocation_n+1) symbol_a text1;
	}

relocate_data :: Int Int Int Int Int String Int {#Int} {#Int} {!Symbol} XcoffArray *{#Char}-> *{#Char};
relocate_data relocation_n n_relocations virtual_module_offset virtual_section_offset real_module_offset text_relocations 
		first_symbol_n module_offset_a marked_offset_a0 symbol_a xcoff_a data0
	| relocation_n==n_relocations
		= data0;
		#	relocation_index=relocation_n * SIZE_OF_RELOCATION;
			relocation_type=text_relocations BYTE (relocation_index+4);
			relocation_symbol_n=text_relocations TBYTE (relocation_index+RELOCATION_SYMBOL_N_OFFSET);
			relocation_offset=text_relocations LONG relocation_index;

			data1 = relocate_symbol relocation_type module_offset_a symbol_a marked_offset_a0 xcoff_a data0;
					with {
						relocate_symbol :: Int {#Int} {!Symbol} {#Int} XcoffArray *{#Char} -> *{#Char};
						relocate_symbol R_386_32 module_offset_a symbol_a marked_offset_a0 xcoff_a data0
							= relocate_long_pos symbol_a.[relocation_symbol_n] (relocation_offset-virtual_section_offset) module_offset_a 
															first_symbol_n relocation_symbol_n symbol_a marked_offset_a0 xcoff_a data0;
					}
		= relocate_data (relocation_n+1) n_relocations virtual_module_offset virtual_section_offset real_module_offset text_relocations
						first_symbol_n module_offset_a marked_offset_a0 symbol_a xcoff_a data1;

relocate_branch :: Symbol Int Int Int Int {#Int} Int Int {!Symbol} {#Int} XcoffArray *{#Char} -> *{#Char};
relocate_branch (Module TEXT_SECTION virtual_label_offset _ _ _ _ _ _) relocation_offset index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 xcoff_a text0
	# real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
	= add_to_long_at_offset ((virtual_module_offset-relocation_offset)+(real_label_offset-real_module_offset)) index text0;
relocate_branch (Label _ /*TEXT_SECTION*/ offset module_n) relocation_offset index virtual_module_offset 
		real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 xcoff_a text0
	= case symbol_a.[module_n] of {
		Module TEXT_SECTION virtual_label_offset _ _ _ _ _ _
			# real_label_offset = module_offset_a.[first_symbol_n+ /*symbol_n*/ module_n]+offset;
			-> add_to_long_at_offset ((virtual_label_offset-relocation_offset)+(real_label_offset-real_module_offset)) index text0;
	};
relocate_branch (ImportedLabel file_n symbol_n) relocation_offset index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 xcoff_a text0
	| file_n<0
		# real_label_offset = module_offset_a.[marked_offset_a0.[file_n + size marked_offset_a0]+symbol_n];
		= add_to_long_at_offset ((virtual_module_offset-relocation_offset)+(real_label_offset-real_module_offset)) index text0;
		# first_symbol_n = marked_offset_a0.[file_n];
		  symbol_a=xcoff_a.[file_n].symbol_table.symbols;
		= case (symbol_a.[symbol_n]) of {
			Module TEXT_SECTION _ _ _ _ _ _ _
				# real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
				-> add_to_long_at_offset ((virtual_module_offset-relocation_offset)+(real_label_offset-real_module_offset)) index text0;
//			_ -> abort ("relocate_branch "+++file_name+++" "+++toString file_n+++" "+++toString symbol_n);
			};
relocate_branch (ImportedLabelPlusOffset file_n symbol_n label_offset) relocation_offset index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 xcoff_a text0
	# first_symbol_n = marked_offset_a0.[file_n];
	  symbol_a=xcoff_a.[file_n].symbol_table.symbols;
	=	case (symbol_a.[symbol_n]) of {
			Module TEXT_SECTION _ _ _ _ _ _ _
				# real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
				->	add_to_long_at_offset ((virtual_module_offset-relocation_offset)+(real_label_offset-real_module_offset)+label_offset) index text0;
		};
relocate_branch (UndefinedLabel _) relocation_offset index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 xcoff_a text
		= text;

relocate_long_pos :: Symbol Int {#Int} Int Int {!Symbol} {#Int} XcoffArray *{#Char} -> *{#Char};
relocate_long_pos (Module section_n virtual_label_offset _ _ _ _ _ _) index module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 xcoff_a data0
	# real_label_offset=module_offset_a.[first_symbol_n+symbol_n];
	= add_to_long_at_offset real_label_offset index data0;
relocate_long_pos (Label _ offset module_n) index module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 xcoff_a data0
	= case symbol_a.[module_n] of {
		Module _ virtual_label_offset _ _ _ _ _ _
			# real_label_offset=module_offset_a.[first_symbol_n+module_n];
			-> add_to_long_at_offset (real_label_offset+offset-virtual_label_offset) index data0;
	  };
relocate_long_pos (ImportedLabel file_n symbol_n) index module_offset_a first_symbol_n _ symbol_a marked_offset_a0 xcoff_a data0
	| file_n<0
		# real_label_offset = module_offset_a.[marked_offset_a0.[file_n + size marked_offset_a0]+symbol_n];
		=	add_to_long_at_offset real_label_offset index data0;
		# first_symbol_n = marked_offset_a0.[file_n];
		  symbol_a=xcoff_a.[file_n].symbol_table.symbols;		
		=	case symbol_a.[symbol_n] of {
				Module section_n _ _ _ _ _ _ _
					# real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
					-> add_to_long_at_offset real_label_offset index data0;
			};
relocate_long_pos (ImportedLabelPlusOffset file_n symbol_n label_offset) index module_offset_a first_symbol_n _ symbol_a marked_offset_a0 xcoff_a data0
		# first_symbol_n = marked_offset_a0.[file_n];
		  symbol_a=xcoff_a.[file_n].symbol_table.symbols;		
		=	case (symbol_a.[symbol_n]) of {
				Module section_n _ _ _ _ _ _ _
					# real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
					-> add_to_long_at_offset (real_label_offset+label_offset) index data0;
			};
relocate_long_pos (UndefinedLabel _) index module_offset_a first_symbol_n _ symbol_a marked_offset_a0 xcoff_a data
	= data;

add_to_long_at_offset :: Int Int *{#Char} -> *{#Char};
add_to_long_at_offset w index array
	#	index1 = index+1;
		index2 = index+2;
		index3 = index+3;
		(v0,array)=array![index];
		(v1,array)=array![index1];
		(v2,array)=array![index2];
		(v3,array)=array![index3];
	#!	array=array;
	#	v = (toInt v0)+(toInt v1<<8)+(toInt v2<<16)+(toInt v3<<24);
		new_v=v+w;
	= {array & [index]=toChar new_v,[index1]=toChar (new_v>>8),[index2]=toChar (new_v>>16),[index3]=toChar (new_v>>24)};

