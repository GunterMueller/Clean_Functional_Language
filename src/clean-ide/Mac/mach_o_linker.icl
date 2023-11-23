implementation module mach_o_linker;

import StdFile,StdArray,StdClass,StdEnum,StdInt,StdBool,StdChar;
from StdMisc import abort;
from StdList import ++,instance length [],reverse;
from StdString import instance % {#Char},instance +++ {#Char},+++.,instance toString Int,instance toString Char;

import mach_o_linker2;

swap_bytes i :== i;
//swap_bytes i = ((i>>24) bitand 0xff) bitor ((i>>8) bitand 0xff00) bitor ((i<<8) bitand 0xff0000) bitor (i<<24);

(!=) a b :== a<>b;

is_nil [] = True;
is_nil _ = False;

not_nil [] = False;
not_nil _ = True;

(CHAR) string i :== string.[i];

(BYTE) string i :== toInt (string.[i]);

(IWORD) string i
//little	= (string BYTE (i+1)<<8) bitor (string BYTE i);
	= (string BYTE i<<8) bitor (string BYTE (i+1));

(ILONG) string i
//little	= (string BYTE (i+3)<<24) bitor (string BYTE (i+2)<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE i);
	= (string BYTE i<<24) bitor (string BYTE (i+1)<<16) bitor (string BYTE (i+2)<<8) bitor (string BYTE (i+3));

(ITBYTE) string i
//little	 = (string BYTE (i+2)<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE i);
	 = (string BYTE i<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE (i+2));

:: *Sections = Sections !*String !*String !Sections | EndSections;

read_mach_o_files :: [String] NamesTable Bool Files Int -> (![String],!Sections,!Int,![*Xcoff],!NamesTable,!Files);
read_mach_o_files file_names names_table0 one_pass_link files0 file_n
	= case file_names of {
		[]
			-> ([],EndSections,file_n,[],names_table0,files0);
		[file_name:file_names]
			#	(error,text_section,data_section,xcoff_file0,names_table1,files1)
					= read_mach_o_file file_name names_table0 one_pass_link files0 file_n;
			| is_nil error
				#	(error2,sections,file_n1,xcoff_files,symbol_table2,files2)
						= read_mach_o_files file_names names_table1 one_pass_link files1 (inc file_n);
					xcoff_file1 = sort_modules xcoff_file0;
				-> (error2,Sections text_section data_section sections,file_n1,[xcoff_file1:xcoff_files],symbol_table2,files2);
				-> (error,EndSections,file_n,[],names_table1,files1);
	};

import_symbols_in_xcoff_files :: [String] !Int ![*Xcoff] !NamesTable -> ([String],!Int,![*Xcoff],!NamesTable);
import_symbols_in_xcoff_files undefined_symbols n_undefined_symbols [] names_table0
	=	(undefined_symbols,n_undefined_symbols,[],names_table0);
import_symbols_in_xcoff_files undefined_symbols0 n_undefined_symbols [xcoff0=:{symbol_table=symbol_table=:{imported_symbols,symbols}}:xcoff_list0] names_table0
	#	(undefined_symbols1,n_undefined_symbols,symbols1,names_table1)
			= import_symbols imported_symbols undefined_symbols0 n_undefined_symbols symbols names_table0;
	# xcoff1 = {xcoff0 & symbol_table = {symbol_table & symbols=symbols1,imported_symbols=EmptySymbolIndex}};
	# (undefined_symbols2,n_undefined_symbols,xcoff_list1,names_table2)
			= import_symbols_in_xcoff_files undefined_symbols1 n_undefined_symbols xcoff_list0 names_table1;
	=	(undefined_symbols2,n_undefined_symbols,[xcoff1:xcoff_list1],names_table2);

	import_symbols :: SymbolIndexList [String] Int SymbolArray NamesTable -> ([String],!Int,!SymbolArray,!NamesTable);
	import_symbols EmptySymbolIndex undefined_symbols n_undefined_symbols symbol_table0 names_table0
		= (undefined_symbols,n_undefined_symbols,symbol_table0,names_table0);
	import_symbols (SymbolIndex index symbol_index_list) undefined_symbols n_undefined_symbols symbol_table0=:{[index]=symbol} names_table0
		= case symbol of {
			ImportLabel label_name
				# (names_table_element,names_table1) = find_symbol_in_symbol_table label_name names_table0;
				->	case names_table_element of {
						NamesTableElement symbol_name symbol_n file_n symbol_list
							| file_n>=0
								# symbol_table1 = { symbol_table0 & [index] = ImportedLabel file_n symbol_n};
								->	import_symbols symbol_index_list undefined_symbols n_undefined_symbols symbol_table1 names_table1;	
								# symbol_table1 = { symbol_table0 & [index] = UndefinedLabel symbol_n};
								->	import_symbols symbol_index_list undefined_symbols n_undefined_symbols symbol_table1 names_table1;	
						EmptyNamesTableElement
							# symbol_table1 = { symbol_table0 & [index] = UndefinedLabel n_undefined_symbols};
							# names_table1 = insert_symbol_in_symbol_table label_name n_undefined_symbols -1 names_table1;
							->	import_symbols symbol_index_list [label_name:undefined_symbols] (n_undefined_symbols+1) symbol_table1 names_table1;
					};
		};

xcoff_array :: Int -> *{#*Xcoff};
xcoff_array n = { empty_xcoff \\ i<-[0..dec n]};

create_xcoff_boolean_array :: Int Int [*Xcoff] -> (!*{#Bool},!*{#Int},!*{#*Xcoff});
create_xcoff_boolean_array n_xcoff_files n_xcoff_symbols list0
	=	(createArray n_xcoff_symbols False,offset_array1,xcoff_a);
	{
		(offset_array1,xcoff_a)=fill_offsets 0 0 list0 (createArray n_xcoff_files 0)
			//	(createArray n_xcoff_files empty_xcoff);
				(xcoff_array n_xcoff_files);
		
		fill_offsets :: Int Int [*Xcoff] *{#Int} *{#*Xcoff} -> (!*{#Int},!*{#*Xcoff});
		fill_offsets file_n offset [] offset_array xcoff_a
			= (offset_array,xcoff_a);
		fill_offsets file_n offset [xcoff=:{n_symbols}:xcoff_list] offset_array xcoff_a
			= fill_offsets (inc file_n) (offset+n_symbols) xcoff_list {offset_array & [file_n]=offset} {xcoff_a & [file_n]=xcoff};
}

:: OffsetArray :== {#Int};

mark_used_modules :: !Int !Int [(String,Int,Int)] !*{#Bool} !OffsetArray !*{#*Xcoff} Files -> (!*{#Bool},!*{#*Xcoff},!Files);
mark_used_modules main_symbol_n main_file_n exception_symbols marked_bool_a0 marked_offset_a xcoff_a files
	# (marked_bool_a,xcoff_a,files) = mark_used_module main_file_n main_symbol_n marked_offset_a xcoff_a marked_bool_a0 files;
	# (marked_bool_a,xcoff_a,files) = mark_used_exception_modules exception_symbols marked_offset_a xcoff_a marked_bool_a files;
	= (marked_bool_a,xcoff_a,files);
{
	mark_used_module :: Int Int OffsetArray *{#*Xcoff} *{#Bool} Files -> (!*{#Bool},!*{#*Xcoff},!Files);
	mark_used_module file_n symbol_n marked_offset_a xcoff_a marked_bool_a0 files
		# bool_offset=marked_offset_a.[file_n]+symbol_n;
		| marked_bool_a0.[bool_offset]
			= (marked_bool_a0,xcoff_a,files);
			# marked_bool_a1 = {marked_bool_a0 & [bool_offset]=True};
			  (symbol,xcoff_a1) = xcoff_a![file_n].symbol_table.symbols.[symbol_n];
			= case symbol of {
				Module section_n _ _ _ indirect_symbol n_relocations relocations
					| section_n==TEXT_SECTION || section_n==DATA_SECTION
						-> mark_relocations_module 0 n_relocations relocations marked_bool_a1 xcoff_a1 files;
					| section_n==STUBS_SECTION || section_n==LAZY_POINTERS_SECTION || section_n==NON_LAZY_POINTERS_SECTION
						# (IndirectSymbol indirect_symbol_n _) = indirect_symbol;
						# (marked_bool_a,xcoff_a,files) = mark_used_module file_n indirect_symbol_n marked_offset_a xcoff_a1 marked_bool_a1 files;
						-> mark_relocations_module 0 n_relocations relocations marked_bool_a xcoff_a files;
					| section_n==BSS_SECTION
						-> (marked_bool_a1,xcoff_a1,files);
				SectionLabel section_n label_offset
					# (section_offsets,xcoff_a2) = xcoff_a![file_n].symbol_table.section_offsets;
					# (section_symbol_n,section_address) = determine_section_symbol_n_and_address label_offset section_offsets;
//					# (section_symbol_n,xcoff_a2) = xcoff_a1![file_n].symbol_table.section_symbol_ns.[section_n];
//					# xcoff_a3 = {xcoff_a2 & [file_n].symbol_table.symbols.[symbol_n]=Label section_n label_offset section_symbol_n};
//					-> mark_used_module file_n section_symbol_n marked_offset_a xcoff_a3 marked_bool_a1 files;
					# xcoff_a3 = {xcoff_a2 & [file_n].symbol_table.symbols.[symbol_n]=Label section_n label_offset section_symbol_n};
					-> mark_used_module file_n section_symbol_n marked_offset_a xcoff_a3 marked_bool_a1 files;
				ImportedLabel symbol_file_n imported_symbol_n
					# xcoff_a2=replace_imported_label_symbol xcoff_a1 file_n symbol_n symbol_file_n imported_symbol_n;
					-> mark_used_module symbol_file_n imported_symbol_n marked_offset_a xcoff_a2 marked_bool_a1 files;
				ImportedLabelPlusOffset symbol_file_n imported_symbol_n _
					-> mark_used_module symbol_file_n imported_symbol_n marked_offset_a xcoff_a1 marked_bool_a1 files;
				UndefinedLabel _
					-> (marked_bool_a0,xcoff_a,files);
				_
					-> abort ("file "+++toString file_n+++" symbol "+++toString symbol_n);
			};
		{}{
			replace_imported_label_symbol :: *{#*Xcoff} Int Int Int Int -> *{#*Xcoff};
			replace_imported_label_symbol xcoff_a0 file_n symbol_n symbol_file_n imported_symbol_n
				# (label_symbol,xcoff_a1) = xcoff_a0![symbol_file_n].symbol_table.symbols.[imported_symbol_n];	
				= case label_symbol of {
					SectionLabel section_n v_label_offset
						#	(section_symbol_n,xcoff_a2) = xcoff_a1![symbol_file_n].symbol_table.section_symbol_ns.[section_n];
							(module_symbol,xcoff_a3) = xcoff_a2![symbol_file_n].symbol_table.symbols.[section_symbol_n];
						-> case module_symbol of {
							Module _ _ virtual_address _ _ _ _
//								-> {xcoff_a3 & [file_n].symbol_table.symbols.[symbol_n] = ImportedLabelPlusOffset symbol_file_n section_symbol_n v_label_offset};
								# (section_offsets,xcoff_a3) = xcoff_a3![symbol_file_n].symbol_table.section_offsets;
								# (section_symbol_n,section_address) = determine_section_symbol_n_and_address v_label_offset section_offsets;
								-> {xcoff_a3 & [file_n].symbol_table.symbols.[symbol_n] = ImportedLabelPlusOffset symbol_file_n section_symbol_n (v_label_offset-section_address)};
//								-> {xcoff_a3 & [file_n].symbol_table.symbols.[symbol_n] = ImportedLabelPlusOffset symbol_file_n section_symbol_n (v_label_offset-virtual_address)};
							_
								-> xcoff_a3
						   };
					Label _ v_label_offset module_n
						#	(module_symbol,xcoff_a2) = xcoff_a1![symbol_file_n].symbol_table.symbols.[module_n];
						-> case module_symbol of {
							Module _ _ virtual_address _ _ _ _								
//								-> {xcoff_a2 & [file_n].symbol_table.symbols.[symbol_n] = ImportedLabelPlusOffset symbol_file_n module_n v_label_offset};
								-> {xcoff_a2 & [file_n].symbol_table.symbols.[symbol_n] = ImportedLabelPlusOffset symbol_file_n module_n (v_label_offset-virtual_address)};
							_
								-> xcoff_a2;
						   };
					_
						-> xcoff_a1;
				  };

			mark_used_branch_module :: Int Int OffsetArray *{#*Xcoff} *{#Bool} Files -> (!*{#Bool},!*{#*Xcoff},!Files);
			mark_used_branch_module file_n symbol_n marked_offset_a xcoff_a marked_bool_a files
				# bool_offset=marked_offset_a.[file_n]+symbol_n;
				| marked_bool_a.[bool_offset]
					= (marked_bool_a,xcoff_a,files);
				# (symbol,xcoff_a) = xcoff_a![file_n].symbol_table.symbols.[symbol_n];
				= case symbol of {
					Module STUBS_SECTION _ _ _ (IndirectSymbol indirect_symbol_n indirect_symbol_name) n_relocations relocations
						# (indirect_symbol,xcoff_a) = xcoff_a![file_n].symbol_table.symbols.[indirect_symbol_n];
						-> case indirect_symbol of {
							UndefinedLabel _
								-> mark_used_module file_n symbol_n marked_offset_a xcoff_a marked_bool_a files;
							_
//								| trace_tn (indirect_symbol_name)

								-> mark_used_module file_n indirect_symbol_n marked_offset_a xcoff_a marked_bool_a files;
/*
								# marked_bool_a = {marked_bool_a & [bool_offset]=True};
								# (marked_bool_a,xcoff_a,files) = mark_used_module file_n indirect_symbol_n marked_offset_a xcoff_a marked_bool_a files;
								-> mark_relocations_module 0 n_relocations relocations marked_bool_a xcoff_a files;
*/
						}
					-> mark_used_module file_n symbol_n marked_offset_a xcoff_a marked_bool_a files
				};

			mark_relocations_module relocation_n n_relocations relocation_string marked_bool_a xcoff_a files
				| relocation_n>=n_relocations
					= (marked_bool_a,xcoff_a,files);
					# relocation_index=relocation_n*SIZE_OF_RELOCATION;
					| relocation_string BYTE relocation_index bitand 0x80<>0 // r_scattered
						# r_kind = relocation_string BYTE relocation_index;
						# r_type=r_kind bitand 0xf;
						| r_type==PPC_RELOC_LO16_SECTDIFF || r_type==PPC_RELOC_HA16_SECTDIFF || r_type==PPC_RELOC_SECTDIFF || r_type==PPC_RELOC_LOCAL_SECTDIFF
							# relocation_index2=relocation_index+SIZE_OF_RELOCATION;
							# r_kind2 = relocation_string BYTE relocation_index2;
							| relocation_string BYTE relocation_index2 bitand 0x80==0 || r_kind2 bitand 0xf<>PPC_RELOC_PAIR
								= abort ("mark_relocations_module: PPC_RELOC_PAIR expected "+++toString r_type);
							# relocation_value=relocation_string ILONG (relocation_index+4);
							# (section_offsets,xcoff_a) = xcoff_a![file_n].symbol_table.section_offsets;
							# relocation_symbol_n = determine_section_symbol_n relocation_value section_offsets;
							# (marked_bool_a,xcoff_a,files) = mark_used_module file_n relocation_symbol_n marked_offset_a xcoff_a marked_bool_a files;
							# relocation_value2=relocation_string ILONG (relocation_index2+4);
							# relocation_symbol_n2 = determine_section_symbol_n relocation_value2 section_offsets;
							# (marked_bool_a,xcoff_a,files) = mark_used_module file_n relocation_symbol_n2 marked_offset_a xcoff_a marked_bool_a files;
							= mark_relocations_module (relocation_n+2) n_relocations relocation_string marked_bool_a xcoff_a files;
						| r_type==PPC_RELOC_LO16 || r_type==PPC_RELOC_HA16
							# relocation_index2=relocation_index+SIZE_OF_RELOCATION;
							# r_kind2_scattered = relocation_string BYTE relocation_index2;
							# r_kind2_not_scattered = relocation_string BYTE (relocation_index2+7);
							| if (relocation_string BYTE relocation_index2 bitand 0x80<>0)
								 (r_kind2_scattered bitand 0xf<>PPC_RELOC_PAIR)
								 (r_kind2_not_scattered bitand 0xf<>PPC_RELOC_PAIR)
								= abort ("mark_relocations_module: PPC_RELOC_PAIR expected "+++toString r_type);
							# relocation_value=relocation_string ILONG (relocation_index+4);
							# (section_offsets,xcoff_a) = xcoff_a![file_n].symbol_table.section_offsets;
							# relocation_symbol_n = determine_section_symbol_n relocation_value section_offsets;
							# (marked_bool_a,xcoff_a,files) = mark_used_module file_n relocation_symbol_n marked_offset_a xcoff_a marked_bool_a files;
							= mark_relocations_module (relocation_n+2) n_relocations relocation_string marked_bool_a xcoff_a files;
						| r_type==PPC_RELOC_BR24 || r_type==PPC_RELOC_BR14
							# relocation_value=relocation_string ILONG (relocation_index+4);
							# (section_offsets,xcoff_a) = xcoff_a![file_n].symbol_table.section_offsets;
							# (relocation_symbol_n,relocation_symbol_address) = determine_section_symbol_n_and_address relocation_value section_offsets;
							| relocation_value==relocation_symbol_address
								# (marked_bool_a,xcoff_a,files) = mark_used_branch_module file_n relocation_symbol_n marked_offset_a xcoff_a marked_bool_a files;
								= mark_relocations_module (relocation_n+1) n_relocations relocation_string marked_bool_a xcoff_a files;
								# (marked_bool_a,xcoff_a,files) = mark_used_module file_n relocation_symbol_n marked_offset_a xcoff_a marked_bool_a files;
								= mark_relocations_module (relocation_n+1) n_relocations relocation_string marked_bool_a xcoff_a files;
						| r_type==PPC_RELOC_VANILLA && r_kind bitand 0x30==0x20
							# relocation_value=relocation_string ILONG (relocation_index+4);
							# (section_offsets,xcoff_a) = xcoff_a![file_n].symbol_table.section_offsets;
							# relocation_symbol_n = determine_section_symbol_n relocation_value section_offsets;
							# (marked_bool_a,xcoff_a,files) = mark_used_module file_n relocation_symbol_n marked_offset_a xcoff_a marked_bool_a files;
							= mark_relocations_module (relocation_n+1) n_relocations relocation_string marked_bool_a xcoff_a files;
							= abort ("mark_relocations_module: relocation type not supported "+++toString r_type);

						# r_kind = relocation_string BYTE (relocation_index+7);
						# r_type=r_kind bitand 0xf;
						| r_type==PPC_RELOC_BR24
							| r_kind bitand 0x10<>0 // r_extern
								# relocation_symbol_n=relocation_string ITBYTE (relocation_index+4);
								# (marked_bool_a,xcoff_a1,files) = mark_used_module file_n relocation_symbol_n marked_offset_a xcoff_a marked_bool_a files;
								= mark_relocations_module (inc relocation_n) n_relocations relocation_string marked_bool_a xcoff_a1 files;
								# (Module _ _ virtual_address _ _ _ _,xcoff_a) = xcoff_a![file_n].symbol_table.symbols.[symbol_n];
								# (text_section,new_relocation_string,xcoff_a,files) = read_text_section_and_make_PPC_RELOC_BR14_and_24_relocations_scattered xcoff_a file_n symbol_n files;
								# relocation_offset = relocation_string ILONG relocation_index;
								# offset = virtual_address+relocation_offset + ((((text_section ILONG relocation_offset) bitand 0x3fffffc)<<6)>>6);
								# (section_offsets,xcoff_a) = xcoff_a![file_n].symbol_table.section_offsets;
								# relocation_symbol_n = determine_section_symbol_n offset section_offsets;
								# (marked_bool_a,xcoff_a1,files) = mark_used_module file_n relocation_symbol_n marked_offset_a xcoff_a marked_bool_a files;
								= mark_relocations_module (inc relocation_n) n_relocations new_relocation_string marked_bool_a xcoff_a1 files;
						| r_type==PPC_RELOC_BR14
							| r_kind bitand 0x10<>0 // r_extern
								# relocation_symbol_n=relocation_string ITBYTE (relocation_index+4);
								# (marked_bool_a,xcoff_a1,files) = mark_used_module file_n relocation_symbol_n marked_offset_a xcoff_a marked_bool_a files;
								= mark_relocations_module (inc relocation_n) n_relocations relocation_string marked_bool_a xcoff_a1 files;
								# (Module _ _ virtual_address _ _ _ _,xcoff_a) = xcoff_a![file_n].symbol_table.symbols.[symbol_n];
								# (text_section,new_relocation_string,xcoff_a,files) = read_text_section_and_make_PPC_RELOC_BR14_and_24_relocations_scattered xcoff_a file_n symbol_n files;
								# relocation_offset = relocation_string ILONG relocation_index;
								# offset = virtual_address+relocation_offset + ((((text_section IWORD relocation_offset) bitand 0xfffc)<<16)>>16);
								# (section_offsets,xcoff_a) = xcoff_a![file_n].symbol_table.section_offsets;
								# relocation_symbol_n = determine_section_symbol_n offset section_offsets;
								# (marked_bool_a,xcoff_a1,files) = mark_used_module file_n relocation_symbol_n marked_offset_a xcoff_a marked_bool_a files;
								= mark_relocations_module (inc relocation_n) n_relocations new_relocation_string marked_bool_a xcoff_a1 files;
						| r_type==PPC_RELOC_LO16 || r_type==PPC_RELOC_HA16
							# relocation_index2=relocation_index+SIZE_OF_RELOCATION;
							# r_kind2 = relocation_string BYTE (relocation_index2+7);
							| r_kind2 bitand 0xf<>PPC_RELOC_PAIR
								= abort "mark_relocations_module: PPC_RELOC_PAIR expected";
							= mark_vanilla_lo16_or_ha16 r_kind relocation_index (relocation_n+2);								
						| r_type==PPC_RELOC_VANILLA && r_kind bitand 0x60==0x40
							= mark_vanilla_lo16_or_ha16 r_kind relocation_index (relocation_n+1);
							= abort ("mark_relocations_module: relocation type not supported "+++toString (r_kind bitand 0xf));
						{}{
							mark_vanilla_lo16_or_ha16 r_kind relocation_index relocation_n
								| r_kind bitand 0x10<>0 // r_extern
									# relocation_symbol_n=relocation_string ITBYTE (relocation_index+4);
									# (marked_bool_a,xcoff_a1,files) = mark_used_module file_n relocation_symbol_n marked_offset_a xcoff_a marked_bool_a files;
									= mark_relocations_module relocation_n n_relocations relocation_string marked_bool_a xcoff_a1 files;
									# relocation_section_n=relocation_string ITBYTE (relocation_index+4);
									# (relocation_symbol_n,xcoff_a) = xcoff_a![file_n].symbol_table.section_symbol_ns.[relocation_section_n];
									# (marked_bool_a,xcoff_a1,files) = mark_used_module file_n relocation_symbol_n marked_offset_a xcoff_a marked_bool_a files;
									= mark_relocations_module relocation_n n_relocations relocation_string marked_bool_a xcoff_a1 files;
						}
		}

	mark_used_exception_modules [(_,file_n,symbol_n):exception_symbols] marked_offset_a xcoff_a marked_bool_a files
		# (marked_bool_a,xcoff_a,files) = mark_used_module file_n symbol_n marked_offset_a xcoff_a marked_bool_a files;
		= mark_used_exception_modules exception_symbols marked_offset_a xcoff_a marked_bool_a files;
	mark_used_exception_modules [] marked_offset_a xcoff_a marked_bool_a files
		= (marked_bool_a,xcoff_a,files);
}

read_text_section_and_make_PPC_RELOC_BR14_and_24_relocations_scattered xcoff_a file_n symbol_n files
	# (Module section_n length virtual_address file_offset indirect_symbol_n n_relocations relocations,xcoff_a) = xcoff_a![file_n].symbol_table.symbols.[symbol_n];
	# (file_name,xcoff_a) = xcoff_a![file_n].file_name;

//	| not (trace_tn file_name)
//		= abort "";

	# (ok,object_file,files) = fopen file_name FReadData files;
	| not ok
		= abort ("Cannot open file \""+++file_name+++"\"");
	# (ok,object_file) = fseek object_file file_offset FSeekSet;
	| not ok
		= abort ("Read error");
	# (section_data_string,object_file) = freads object_file length;
	| size section_data_string<>length
		= abort ("Read error");
	# (ok,files) = fclose object_file files;
	| not ok
		= abort ("Error while reading file: "+++file_name);

	# new_relocations = make_PPC_RELOC_BR14_and_24_relocations_scattered 0 n_relocations (relocations +++. "");
		with {
			make_PPC_RELOC_BR14_and_24_relocations_scattered relocation_n n_relocations new_relocations
				| relocation_n==n_relocations
					= new_relocations;
					# relocation_index=relocation_n*SIZE_OF_RELOCATION;
					# r_kind = relocations BYTE (relocation_index+7);
					# r_type=r_kind bitand 0xf;
					| relocations BYTE relocation_index bitand 0x80==0 // r_scattered
						&& r_kind bitand 0x10==0 // r_extern
						| r_type==PPC_RELOC_BR24
							# relocation_offset = relocations ILONG relocation_index;
							# offset = virtual_address+relocation_offset + ((((section_data_string ILONG relocation_offset) bitand 0x3fffffc)<<6)>>6);
							# new_relocations = {new_relocations &	[relocation_index]=toChar (0xc0 bitor PPC_RELOC_BR24),
																	[relocation_index+1]=toChar (relocation_offset>>16),
																	[relocation_index+2]=toChar (relocation_offset>>8),
																	[relocation_index+3]=toChar relocation_offset,
																	[relocation_index+4]=toChar (offset>>24),
																	[relocation_index+5]=toChar (offset>>16),
																	[relocation_index+6]=toChar (offset>>8),
																	[relocation_index+7]=toChar offset
											};
							= make_PPC_RELOC_BR14_and_24_relocations_scattered (relocation_n+1) n_relocations new_relocations;
						| r_type==PPC_RELOC_BR14
							# relocation_offset = relocations ILONG relocation_index;
							# offset = virtual_address+relocation_offset + ((((section_data_string IWORD (relocation_offset+2)) bitand 0xfffc)<<16)>>16);
							# new_relocations = {new_relocations &	[relocation_index]=toChar (0xc0 bitor PPC_RELOC_BR14),
																	[relocation_index+1]=toChar (relocation_offset>>16),
																	[relocation_index+2]=toChar (relocation_offset>>8),
																	[relocation_index+3]=toChar relocation_offset,
																	[relocation_index+4]=toChar (offset>>24),
																	[relocation_index+5]=toChar (offset>>16),
																	[relocation_index+6]=toChar (offset>>8),
																	[relocation_index+7]=toChar offset
											};
							= make_PPC_RELOC_BR14_and_24_relocations_scattered (relocation_n+1) n_relocations new_relocations;
							= make_PPC_RELOC_BR14_and_24_relocations_scattered (relocation_n+1) n_relocations new_relocations;
						= make_PPC_RELOC_BR14_and_24_relocations_scattered (relocation_n+1) n_relocations new_relocations;
		}
	# xcoff_a = {xcoff_a & [file_n].symbol_table.symbols.[symbol_n]=Module section_n length virtual_address file_offset indirect_symbol_n n_relocations new_relocations};
	= (section_data_string,new_relocations,xcoff_a,files);

determine_new_branch_address :: Int Int {#SectionAddressAndSymbolN} {!Symbol} {#Int} {#Int} {#Int} {#SXcoff} -> (!Int,!Int);
determine_new_branch_address r_value first_symbol_n section_offsets symbol_a module_offset_a section_addresses offset_a xcoff_a
	# section_n = determine_section_n 0 (size section_offsets) r_value section_offsets;
	# {section_symbol_n,section_address} = section_offsets.[section_n];
	# offset_in_section=r_value-section_address;
	= case symbol_a.[section_symbol_n] of {	
		Module section_n _ _ _ (IndirectSymbol indirect_symbol_n indirect_symbol_name) _ _
			| offset_in_section==0
				-> case symbol_a.[indirect_symbol_n] of {
					UndefinedLabel _
						# new_module_offset = module_offset_a.[first_symbol_n+section_symbol_n];
						-> (section_addresses.[section_n]+new_module_offset+offset_in_section,section_n);
					ImportedLabelPlusOffset symbol_file_n module_symbol_n label_offset
						# (Module section_n _ _ _ _ _ _) = xcoff_a.[symbol_file_n].symbol_table.symbols.[module_symbol_n];
						-> (section_addresses.[section_n]+module_offset_a.[offset_a.[symbol_file_n]+module_symbol_n]+label_offset,section_n);
					Label section_n label_offset section_symbol_n
						#  (Module _ _ virtual_address _ _ _ _) = symbol_a.[section_symbol_n];
						-> (section_addresses.[section_n]+module_offset_a.[first_symbol_n+section_symbol_n]+(label_offset-virtual_address),section_n);
					ImportedLabel _ _
						-> abort ("determine_new_branch_address ImportedLabel "+++indirect_symbol_name);
					Module _ _ _ _ _ _ _
						-> abort ("determine_new_branch_address Module "+++indirect_symbol_name);
					_
						-> abort ("determine_new_branch_address _ "+++indirect_symbol_name);
				  };
		Module section_n _ _ _ _ _ _
			# new_module_offset = module_offset_a.[first_symbol_n+section_symbol_n];
			-> (section_addresses.[section_n]+new_module_offset+offset_in_section,section_n);
	  };

determine_new_branch_section_n :: Int {#SectionAddressAndSymbolN} {!Symbol} {#SXcoff} -> Int;
determine_new_branch_section_n r_value section_offsets symbol_a xcoff_a
	# section_n = determine_section_n 0 (size section_offsets) r_value section_offsets;
	# {section_symbol_n,section_address} = section_offsets.[section_n];
	# offset_in_section=r_value-section_address;
	= case symbol_a.[section_symbol_n] of {	
		Module section_n _ _ _ (IndirectSymbol indirect_symbol_n indirect_symbol_name) _ _
			| offset_in_section==0
				-> case symbol_a.[indirect_symbol_n] of {
					UndefinedLabel _
						-> section_n;
					ImportedLabelPlusOffset symbol_file_n module_symbol_n label_offset
						# (Module section_n _ _ _ _ _ _) = xcoff_a.[symbol_file_n].symbol_table.symbols.[module_symbol_n];
						-> section_n;
					Label section_n label_offset section_symbol_n
						#  (Module _ _ virtual_address _ _ _ _) = symbol_a.[section_symbol_n];
						-> section_n;
					ImportedLabel _ _
						-> abort ("determine_new_branch_section_n ImportedLabel "+++indirect_symbol_name);
					Module _ _ _ _ _ _ _
						-> abort ("determine_new_branch_section_n Module "+++indirect_symbol_name);
					_
						-> abort ("determine_new_branch_section_n _ "+++indirect_symbol_name);
				  };
		Module section_n _ _ _ _ _ _
			-> section_n;
	  };

determine_new_address r_value first_symbol_n section_offsets symbol_a module_offset_a section_addresses
	# section_n = determine_section_n 0 (size section_offsets) r_value section_offsets;
	# {section_symbol_n,section_address} = section_offsets.[section_n];
	# offset_in_section=r_value-section_address;
	# (Module section_n _ _ _ _ _ _) = symbol_a.[section_symbol_n];
	# new_module_offset = module_offset_a.[first_symbol_n+section_symbol_n];
	= section_addresses.[section_n]+new_module_offset+offset_in_section;

determine_section_symbol_n :: Int {#SectionAddressAndSymbolN} -> Int;
determine_section_symbol_n offset section_offsets
	# section_n = determine_section_n 0 (size section_offsets) offset section_offsets;
	= section_offsets.[section_n].section_symbol_n;

determine_section_symbol_n_and_address :: Int {#SectionAddressAndSymbolN} -> (!Int,!Int);
determine_section_symbol_n_and_address offset section_offsets
	# section_n = determine_section_n 0 (size section_offsets) offset section_offsets;
	# {section_symbol_n,section_address} = section_offsets.[section_n];
	= (section_symbol_n,section_address);

:: *ModuleOffsets :== *{#Int};

:: IndirectSymbols :== [(Int,Int,String)];

compute_module_offsets :: Int [SXcoff] {#Bool} {#SXcoff} -> (!Int,!Int,!Int,!Int,!Int,!Int,!Int,!Int,!Int,!Int,!Int,!Int,!Int,!Int,*{#Int},IndirectSymbols);
compute_module_offsets n_symbols xcoff_list4 marked_bool_a xcoff_a
	# module_offset_a = createArray n_symbols 0;
	  (text_section_size,n_code_relocations,module_offset_a)
		= compute_text_module_offsets 0 xcoff_list4 module_offset_a;
	  (data_section_size,n_data_relocations,module_offset_a1)
		= compute_data_module_offsets xcoff_list4 0 0 0 module_offset_a;
	  (bss_section_size,module_offset_a)
		= compute_bss_module_offsets xcoff_list4 0 0 module_offset_a1;
	  (stubs_section_size,n_stub_relocations,first_lazy_pointer_symbol_n,module_offset_a,indirect_symbols)
		= compute_stubs_module_offsets 0 0 xcoff_list4 module_offset_a;
	  (lazy_pointers_section_size,n_lazy_pointers_relocations,first_non_lazy_pointer_symbol_n,module_offset_a,indirect_symbols)
		= compute_lazy_pointer_module_offsets 0 first_lazy_pointer_symbol_n xcoff_list4 module_offset_a indirect_symbols;
	  (non_lazy_pointers_section_size,n_non_lazy_pointers_relocations,n_indirect_symbols,module_offset_a2,indirect_symbols)
		= compute_non_lazy_pointer_module_offsets 0 first_non_lazy_pointer_symbol_n xcoff_list4 module_offset_a indirect_symbols;
	= (	text_section_size,data_section_size,bss_section_size,stubs_section_size,lazy_pointers_section_size,non_lazy_pointers_section_size,
		n_code_relocations,n_data_relocations,n_stub_relocations,n_lazy_pointers_relocations,n_non_lazy_pointers_relocations,
		first_lazy_pointer_symbol_n,first_non_lazy_pointer_symbol_n,n_indirect_symbols,module_offset_a2,indirect_symbols);
{
	compute_text_module_offsets :: Int [SXcoff] ModuleOffsets -> (!Int,!Int,!ModuleOffsets);
	compute_text_module_offsets text_offset xcoff_list module_offsets
		= compute_files_module_offsets xcoff_list text_offset 0 0 module_offsets;
		{
			compute_files_module_offsets :: [SXcoff] Int Int Int ModuleOffsets -> (!Int,!Int,!ModuleOffsets);
			compute_files_module_offsets [] text_offset file_symbol_index n_relocations module_offsets
				= (text_offset,n_relocations,module_offsets);
			compute_files_module_offsets [{n_symbols,symbol_table}:xcoff_list] text_offset file_symbol_index n_relocations module_offsets
				# (text_offset,n_relocations,module_offsets)
					= compute_section_module_offsets file_symbol_index symbol_table.text_symbols symbol_table.symbols symbol_table.section_offsets text_offset n_relocations module_offsets;					
				= compute_files_module_offsets xcoff_list text_offset (file_symbol_index+n_symbols) n_relocations module_offsets;
		}
	
	compute_data_module_offsets :: [SXcoff] Int Int Int ModuleOffsets -> (!Int,!Int,!ModuleOffsets);
	compute_data_module_offsets [] data_offset0 file_symbol_index n_relocations module_offsets0
		= (data_offset0,n_relocations,module_offsets0);
	compute_data_module_offsets [xcoff=:{n_symbols,symbol_table}:xcoff_list] data_offset0 file_symbol_index n_relocations module_offsets0
		# (data_offset1,n_relocations,module_offsets1)
			= compute_data_section_module_offsets file_symbol_index symbol_table.data_symbols symbol_table.symbols data_offset0 n_relocations module_offsets0;
		= compute_data_module_offsets xcoff_list data_offset1 (file_symbol_index+n_symbols) n_relocations module_offsets1;
	{
		section_offsets=symbol_table.section_offsets;
		
		compute_data_section_module_offsets :: Int SymbolIndexList SSymbolArray Int Int ModuleOffsets -> (!Int,!Int,!ModuleOffsets);
		compute_data_section_module_offsets file_symbol_index EmptySymbolIndex symbol_array offset0 n_relocations module_offsets
			= (offset0,n_relocations,module_offsets);
		compute_data_section_module_offsets file_symbol_index (SymbolIndex module_n symbol_list) symbol_array=:{[module_n]=module_symbol} offset0 n_relocations module_offsets
			# (module_offset,offset1,n_relocations)=compute_module_offset_and_count_relocations module_symbol offset0 n_relocations symbol_array section_offsets;
			# module_offsets = {module_offsets & [file_symbol_index+module_n]=module_offset};
			= compute_data_section_module_offsets file_symbol_index symbol_list symbol_array offset1 n_relocations module_offsets;
	}
		
	compute_bss_module_offsets :: [SXcoff] Int Int ModuleOffsets -> (!Int,!ModuleOffsets);
	compute_bss_module_offsets [] bss_offset0 file_symbol_index module_offsets0
		= (bss_offset0,module_offsets0);
	compute_bss_module_offsets [{n_symbols,symbol_table}:xcoff_list] bss_offset0 file_symbol_index module_offsets0
		# (bss_offset1,n_relocations,module_offsets1)
			= compute_section_module_offsets file_symbol_index symbol_table.bss_symbols symbol_table.symbols symbol_table.section_offsets bss_offset0 0 module_offsets0;
		= compute_bss_module_offsets xcoff_list bss_offset1 (file_symbol_index+n_symbols) module_offsets1;
	
	compute_stubs_module_offsets :: Int Int [SXcoff] ModuleOffsets -> (!Int,!Int,!Int,!ModuleOffsets,!IndirectSymbols);
	compute_stubs_module_offsets text_offset indirect_symbol_table_n xcoff_list module_offsets
		= compute_files_module_offsets xcoff_list text_offset 0 0 0 0 module_offsets [];
		{
			compute_files_module_offsets :: [SXcoff] Int Int Int Int Int ModuleOffsets IndirectSymbols -> (!Int,!Int,!Int,!ModuleOffsets,!IndirectSymbols);
			compute_files_module_offsets [] text_offset file_n file_symbol_index n_relocations indirect_symbol_table_n module_offsets indirect_symbols
				= (text_offset,n_relocations,indirect_symbol_table_n,module_offsets,indirect_symbols);
			compute_files_module_offsets [{n_symbols,symbol_table}:xcoff_list] text_offset file_n file_symbol_index n_relocations indirect_symbol_table_n module_offsets indirect_symbols
				# (text_offset,n_relocations,indirect_symbol_table_n,module_offsets,indirect_symbols)
					= compute_stubs_section_module_with_indirect_symbols_offsets symbol_table.stub_symbols file_n file_symbol_index symbol_table.symbols symbol_table.section_offsets text_offset n_relocations indirect_symbol_table_n module_offsets indirect_symbols;
				= compute_files_module_offsets xcoff_list text_offset (file_n+1) (file_symbol_index+n_symbols) n_relocations indirect_symbol_table_n module_offsets indirect_symbols;
		}
	
	compute_lazy_pointer_module_offsets :: Int Int [SXcoff] ModuleOffsets IndirectSymbols -> (!Int,!Int,!Int,!ModuleOffsets,!IndirectSymbols);
	compute_lazy_pointer_module_offsets text_offset indirect_symbol_table_n xcoff_list module_offsets indirect_symbols
		= compute_files_module_offsets xcoff_list text_offset 0 0 0 indirect_symbol_table_n module_offsets indirect_symbols;
		{
			compute_files_module_offsets :: [SXcoff] Int Int Int Int Int ModuleOffsets IndirectSymbols -> (!Int,!Int,!Int,!ModuleOffsets,!IndirectSymbols);
			compute_files_module_offsets [] text_offset file_n file_symbol_index n_relocations indirect_symbol_table_n module_offsets indirect_symbols
				= (text_offset,n_relocations,indirect_symbol_table_n,module_offsets,indirect_symbols);
			compute_files_module_offsets [{n_symbols,symbol_table}:xcoff_list] text_offset file_n file_symbol_index n_relocations indirect_symbol_table_n module_offsets indirect_symbols
				# (text_offset,n_relocations,indirect_symbol_table_n,module_offsets,indirect_symbols)
					= compute_section_module_with_indirect_symbols_offsets symbol_table.lazy_pointer_symbols file_n file_symbol_index symbol_table.symbols symbol_table.section_offsets text_offset n_relocations indirect_symbol_table_n module_offsets indirect_symbols;					
				= compute_files_module_offsets xcoff_list text_offset (file_n+1) (file_symbol_index+n_symbols) n_relocations indirect_symbol_table_n module_offsets indirect_symbols;
		}

	compute_non_lazy_pointer_module_offsets :: Int Int [SXcoff] ModuleOffsets IndirectSymbols -> (!Int,!Int,!Int,!ModuleOffsets,!IndirectSymbols);
	compute_non_lazy_pointer_module_offsets text_offset indirect_symbol_table_n xcoff_list module_offsets indirect_symbols
		= compute_files_module_offsets xcoff_list text_offset 0 0 0 indirect_symbol_table_n module_offsets indirect_symbols;
		{
			compute_files_module_offsets :: [SXcoff] Int Int Int Int Int ModuleOffsets IndirectSymbols -> (!Int,!Int,!Int,!ModuleOffsets,!IndirectSymbols);
			compute_files_module_offsets [] text_offset file_n file_symbol_index n_relocations indirect_symbol_table_n module_offsets indirect_symbols
				= (text_offset,n_relocations,indirect_symbol_table_n,module_offsets,indirect_symbols);
			compute_files_module_offsets [{n_symbols,symbol_table}:xcoff_list] text_offset file_n file_symbol_index n_relocations indirect_symbol_table_n module_offsets indirect_symbols
				# (text_offset,n_relocations,indirect_symbol_table_n,module_offsets,indirect_symbols)
					= compute_section_module_with_indirect_symbols_offsets symbol_table.non_lazy_pointer_symbols file_n file_symbol_index symbol_table.symbols symbol_table.section_offsets text_offset n_relocations indirect_symbol_table_n module_offsets indirect_symbols;
				= compute_files_module_offsets xcoff_list text_offset (file_n+1) (file_symbol_index+n_symbols) n_relocations indirect_symbol_table_n module_offsets indirect_symbols;
		}
	
		compute_section_module_offsets :: Int SymbolIndexList SSymbolArray  {#SectionAddressAndSymbolN} Int Int ModuleOffsets -> (!Int,!Int,!ModuleOffsets);
		compute_section_module_offsets file_symbol_index EmptySymbolIndex symbol_array section_offsets offset n_relocations module_offsets
			= (offset,n_relocations,module_offsets);
		compute_section_module_offsets file_symbol_index (SymbolIndex module_n symbol_list) symbol_array=:{[module_n]=module_symbol} section_offsets offset0 n_relocations module_offsets
			| not marked_bool_a.[file_symbol_index+module_n]
				= compute_section_module_offsets file_symbol_index symbol_list symbol_array section_offsets offset0 n_relocations module_offsets;
				# (module_offset,offset1,n_relocations)=compute_module_offset_and_count_relocations module_symbol offset0 n_relocations symbol_array section_offsets;
				# module_offsets = {module_offsets & [file_symbol_index+module_n]=module_offset};
				= compute_section_module_offsets file_symbol_index symbol_list symbol_array section_offsets offset1 n_relocations module_offsets;
	
		compute_section_module_with_indirect_symbols_offsets :: SymbolIndexList Int Int SSymbolArray {#SectionAddressAndSymbolN} Int Int Int ModuleOffsets IndirectSymbols -> (!Int,!Int,!Int,!ModuleOffsets,!IndirectSymbols);
		compute_section_module_with_indirect_symbols_offsets EmptySymbolIndex file_n file_symbol_index symbol_array section_offsets offset n_relocations indirect_symbol_table_n module_offsets indirect_symbols
			= (offset,n_relocations,indirect_symbol_table_n,module_offsets,indirect_symbols);
		compute_section_module_with_indirect_symbols_offsets (SymbolIndex module_n symbol_list) file_n file_symbol_index symbol_array=:{[module_n]=module_symbol} section_offsets offset0 n_relocations indirect_symbol_table_n module_offsets indirect_symbols
			| not marked_bool_a.[file_symbol_index+module_n]
				= compute_section_module_with_indirect_symbols_offsets symbol_list file_n file_symbol_index symbol_array section_offsets offset0 n_relocations indirect_symbol_table_n module_offsets indirect_symbols;
				# (Module _ _ _ _ (IndirectSymbol indirect_symbol_n indirect_symbol_name) _ _) = module_symbol;
				#! indirect_symbol_name = indirect_symbol_name
				# (module_offset,offset1,n_relocations)=compute_module_offset_and_count_relocations module_symbol offset0 n_relocations symbol_array section_offsets;
				# module_offsets = {module_offsets & [file_symbol_index+module_n]=module_offset};
				# indirect_symbols = [(indirect_symbol_n,file_n,indirect_symbol_name):indirect_symbols];
				= compute_section_module_with_indirect_symbols_offsets symbol_list file_n file_symbol_index symbol_array section_offsets offset1 n_relocations (indirect_symbol_table_n+1) module_offsets indirect_symbols;

		compute_stubs_section_module_with_indirect_symbols_offsets :: SymbolIndexList Int Int SSymbolArray {#SectionAddressAndSymbolN} Int Int Int ModuleOffsets IndirectSymbols -> (!Int,!Int,!Int,!ModuleOffsets,!IndirectSymbols);
		compute_stubs_section_module_with_indirect_symbols_offsets EmptySymbolIndex file_n file_symbol_index symbol_array section_offsets offset n_relocations indirect_symbol_table_n module_offsets indirect_symbols
			= (offset,n_relocations,indirect_symbol_table_n,module_offsets,indirect_symbols);
		compute_stubs_section_module_with_indirect_symbols_offsets (SymbolIndex module_n symbol_list) file_n file_symbol_index symbol_array=:{[module_n]=module_symbol} section_offsets offset0 n_relocations indirect_symbol_table_n module_offsets indirect_symbols
			| not marked_bool_a.[file_symbol_index+module_n]
				= compute_stubs_section_module_with_indirect_symbols_offsets symbol_list file_n file_symbol_index symbol_array section_offsets offset0 n_relocations indirect_symbol_table_n module_offsets indirect_symbols;
				# (Module _ _ _ _ (IndirectSymbol indirect_symbol_n indirect_symbol_name) _ _) = module_symbol;
				#! indirect_symbol_name = indirect_symbol_name
				# (module_offset,offset1,n_relocations)=compute_stubs_module_offset_and_count_relocations module_symbol offset0 n_relocations symbol_array section_offsets;
				# module_offsets = {module_offsets & [file_symbol_index+module_n]=module_offset};
				# indirect_symbols = [(indirect_symbol_n,file_n,indirect_symbol_name):indirect_symbols];
				= compute_stubs_section_module_with_indirect_symbols_offsets symbol_list file_n file_symbol_index symbol_array section_offsets offset1 n_relocations (indirect_symbol_table_n+1) module_offsets indirect_symbols;
	
			compute_module_offset_and_count_relocations :: Symbol Int Int SSymbolArray {#SectionAddressAndSymbolN} -> (!Int,!Int,!Int);
			compute_module_offset_and_count_relocations (Module section_n length _ _ _ old_n_module_relocations relocations) offset0 n_relocations symbol_array section_offsets
				# alignment=2;
				  alignment_mask=dec (1<<alignment);
				  aligned_offset0=(offset0+alignment_mask) bitand (bitnot alignment_mask);
				# n_module_relocations = count_relocations 0 0 section_n old_n_module_relocations relocations symbol_array section_offsets;
				= (aligned_offset0,aligned_offset0+length,n_relocations+n_module_relocations);

			compute_stubs_module_offset_and_count_relocations :: Symbol Int Int SSymbolArray {#SectionAddressAndSymbolN} -> (!Int,!Int,!Int);
			compute_stubs_module_offset_and_count_relocations (Module section_n length _ _ _ old_n_module_relocations relocations) offset0 n_relocations symbol_array section_offsets
				# n_module_relocations = count_relocations 0 0 section_n old_n_module_relocations relocations symbol_array section_offsets;
				# aligned_length = ((length+STUB_SIZE-1) / STUB_SIZE) * STUB_SIZE;
				= (offset0,offset0+aligned_length,n_relocations+n_module_relocations);

			count_relocations relocation_n n_module_relocations section_n old_n_module_relocations relocations symbol_array section_offsets
				= count_relocations relocation_n n_module_relocations;
			{
				count_relocations relocation_n n_module_relocations
					| relocation_n==old_n_module_relocations
						= n_module_relocations;
					# relocation_index=relocation_n * SIZE_OF_RELOCATION;
					| relocations BYTE relocation_index bitand 0x80<>0 // r_scattered
						# r_kind = relocations BYTE relocation_index;
						# r_type=r_kind bitand 0xf;
						| r_type==PPC_RELOC_BR24 || r_type==PPC_RELOC_BR14
							# r_value=relocations ILONG (relocation_index+4);
							# destination_section_n = determine_new_branch_section_n r_value section_offsets symbol_array xcoff_a;
							| destination_section_n==section_n
								= count_relocations (relocation_n+1) n_module_relocations;
								= count_relocations (relocation_n+1) (n_module_relocations+1);
							= count_relocations (relocation_n+1) (n_module_relocations+1);
					# r_kind = relocations BYTE (relocation_index+7);
					# r_type=r_kind bitand 0xf;
					| r_type==PPC_RELOC_BR24
						| r_kind bitand 0x10<>0 // r_extern
							# relocation_symbol_n=relocations ITBYTE (relocation_index+4);
							= case symbol_array.[relocation_symbol_n] of {
								UndefinedLabel symbol_n
									-> count_relocations (relocation_n+1) (n_module_relocations+1);
								ImportedLabelPlusOffset symbol_file_n module_symbol_n label_offset
									# (Module destination_section_n _ _ _ _ _ _) = xcoff_a.[symbol_file_n].symbol_table.symbols.[module_symbol_n];
									| destination_section_n==section_n
										-> count_relocations (relocation_n+1) n_module_relocations;
										-> count_relocations (relocation_n+1) (n_module_relocations+1);
								ImportedLabel symbol_file_n module_symbol_n
									# (Module destination_section_n _ _ _ _ _ _) = xcoff_a.[symbol_file_n].symbol_table.symbols.[module_symbol_n];
									| destination_section_n==section_n
										-> count_relocations (relocation_n+1) n_module_relocations;
										-> count_relocations (relocation_n+1) (n_module_relocations+1);
								Module destination_section_n _ _ _ _ _ _
									| destination_section_n==section_n
										-> count_relocations (relocation_n+1) n_module_relocations;
										-> count_relocations (relocation_n+1) (n_module_relocations+1);
								_
									-> count_relocations (relocation_n+1) (n_module_relocations+1);
						  	};
							= count_relocations (relocation_n+1) (n_module_relocations+1);
					| r_type==PPC_RELOC_LO16 || r_type==PPC_RELOC_HA16
						= count_relocations (relocation_n+2) (n_module_relocations+2);
					| r_type==PPC_RELOC_VANILLA && r_kind bitand 0x60==0x40
						= count_relocations (relocation_n+1) (n_module_relocations+1);
			}
}

write_relocation_strings [] output_file
	= output_file;
write_relocation_strings [relocation_string:relocation_strings] output_file
	= write_relocation_strings relocation_strings (fwrites relocation_string output_file);

compute_indirect_symbol_information indirect_symbols exported_indirect_symbol_n indirect_symbol_string_offset xcoff_a offset_a module_offset_a section_addresses
	= compute_indirect_symbol_information indirect_symbols exported_indirect_symbol_n indirect_symbol_string_offset create_names_table;
{
	compute_indirect_symbol_information :: [(Int,Int,{#Char})] Int Int NamesTable -> (![Int],![(Int,Int,Int)],![{#Char}],!Int,!Int);
	compute_indirect_symbol_information [] exported_indirect_symbol_n indirect_symbol_string_offset names_table
		= ([],[],[],exported_indirect_symbol_n,indirect_symbol_string_offset);
	compute_indirect_symbol_information [(indirect_symbol_n,file_n,indirect_symbol_name):indirect_symbols] exported_indirect_symbol_n indirect_symbol_string_offset names_table
		# symbol=xcoff_a.[file_n].symbol_table.symbols.[indirect_symbol_n];
		= case symbol of {
			UndefinedLabel label_n
				# (indirect_symbol_table,symbol_table,indirect_symbol_strings,exported_indirect_symbol_n,indirect_symbol_string_offset)
					= compute_indirect_symbol_information indirect_symbols exported_indirect_symbol_n indirect_symbol_string_offset names_table;
			 	-> ([label_n:indirect_symbol_table],symbol_table,indirect_symbol_strings,exported_indirect_symbol_n,indirect_symbol_string_offset);
			 _
				# (names_table_element,names_table)=find_symbol_in_symbol_table indirect_symbol_name names_table;
				-> case names_table_element of {
					NamesTableElement _ indirect_symbol_n _ _
						# (indirect_symbol_table,symbol_table,indirect_symbol_strings,exported_indirect_symbol_n,indirect_symbol_string_offset)
							= compute_indirect_symbol_information indirect_symbols exported_indirect_symbol_n indirect_symbol_string_offset names_table;
						-> ([indirect_symbol_n:indirect_symbol_table],symbol_table,indirect_symbol_strings,exported_indirect_symbol_n,indirect_symbol_string_offset);
					_
						-> case symbol of {
							Module section_n _ _ _ _ _ _
								# module_offset = module_offset_a.[offset_a.[file_n]+indirect_symbol_n];
								#! indirect_symbol_n = -1-exported_indirect_symbol_n;
								# names_table=insert_symbol_in_symbol_table indirect_symbol_name indirect_symbol_n (-1) names_table;
								# section_n_offset_string_offset = (section_n,module_offset+section_addresses.[section_n],indirect_symbol_string_offset);
								# (indirect_symbol_table,symbol_table,indirect_symbol_strings,exported_indirect_symbol_n,indirect_symbol_string_offset)
									= compute_indirect_symbol_information indirect_symbols (exported_indirect_symbol_n+1) (indirect_symbol_string_offset+1+size indirect_symbol_name) names_table;
								-> ([indirect_symbol_n:indirect_symbol_table],[section_n_offset_string_offset:symbol_table],[indirect_symbol_name:indirect_symbol_strings],exported_indirect_symbol_n,indirect_symbol_string_offset);							
							ImportedLabelPlusOffset symbol_file_n module_symbol_n label_offset
								# (Module section_n _ virtual_address _ _ _ _) = xcoff_a.[symbol_file_n].symbol_table.symbols.[module_symbol_n];
//								# offset = section_addresses.[section_n]+module_offset_a.[offset_a.[symbol_file_n]+module_symbol_n]+(label_offset-virtual_address);
								# offset = section_addresses.[section_n]+module_offset_a.[offset_a.[symbol_file_n]+module_symbol_n]+label_offset;
								#! indirect_symbol_n = -1-exported_indirect_symbol_n;
								# names_table=insert_symbol_in_symbol_table indirect_symbol_name indirect_symbol_n (-1) names_table;
								# section_n_offset_string_offset = (section_n,offset,indirect_symbol_string_offset);
								# (indirect_symbol_table,symbol_table,indirect_symbol_strings,exported_indirect_symbol_n,indirect_symbol_string_offset)
									= compute_indirect_symbol_information indirect_symbols (exported_indirect_symbol_n+1) (indirect_symbol_string_offset+1+size indirect_symbol_name) names_table;
								-> ([indirect_symbol_n:indirect_symbol_table],[section_n_offset_string_offset:symbol_table],[indirect_symbol_name:indirect_symbol_strings],exported_indirect_symbol_n,indirect_symbol_string_offset);
							ImportedLabel symbol_file_n module_symbol_n
								# (Module section_n _ virtual_address _ _ _ _) = xcoff_a.[symbol_file_n].symbol_table.symbols.[module_symbol_n];
								# offset = section_addresses.[section_n]+module_offset_a.[offset_a.[symbol_file_n]+module_symbol_n];				
								#! indirect_symbol_n = -1-exported_indirect_symbol_n;
								# names_table=insert_symbol_in_symbol_table indirect_symbol_name indirect_symbol_n (-1) names_table;
								# section_n_offset_string_offset = (section_n,offset,indirect_symbol_string_offset);
								# (indirect_symbol_table,symbol_table,indirect_symbol_strings,exported_indirect_symbol_n,indirect_symbol_string_offset)
									= compute_indirect_symbol_information indirect_symbols (exported_indirect_symbol_n+1) (indirect_symbol_string_offset+1+size indirect_symbol_name) names_table;
								-> ([indirect_symbol_n:indirect_symbol_table],[section_n_offset_string_offset:symbol_table],[indirect_symbol_name:indirect_symbol_strings],exported_indirect_symbol_n,indirect_symbol_string_offset);
							Label section_n label_offset section_symbol_n
								#  (Module _ _ virtual_address _ _ _ _) = xcoff_a.[file_n].symbol_table.symbols.[section_symbol_n];
								#! indirect_symbol_n = -1-exported_indirect_symbol_n;
								# names_table=insert_symbol_in_symbol_table indirect_symbol_name indirect_symbol_n (-1) names_table;
								# module_offset = module_offset_a.[offset_a.[file_n]+section_symbol_n];
//								# section_n_offset_string_offset = (section_n,module_offset+section_addresses.[section_n]+label_offset,indirect_symbol_string_offset);
								# section_n_offset_string_offset = (section_n,module_offset+section_addresses.[section_n]+(label_offset-virtual_address),indirect_symbol_string_offset);
								# (indirect_symbol_table,symbol_table,indirect_symbol_strings,exported_indirect_symbol_n,indirect_symbol_string_offset)
									= compute_indirect_symbol_information indirect_symbols (exported_indirect_symbol_n+1) (indirect_symbol_string_offset+1+size indirect_symbol_name) names_table;
								-> ([indirect_symbol_n:indirect_symbol_table],[section_n_offset_string_offset:symbol_table],[indirect_symbol_name:indirect_symbol_strings],exported_indirect_symbol_n,indirect_symbol_string_offset);							
						}
				 }
		}
}

write_indirect_symbol_table [] n_exception_symbols first_undefined_symbol_n output_object_file
	= output_object_file;
write_indirect_symbol_table [label_n:indirect_symbols] n_exception_symbols first_undefined_symbol_n output_object_file
	| label_n>=0
		# output_object_file = output_object_file FWI (label_n+first_undefined_symbol_n);
		= write_indirect_symbol_table indirect_symbols n_exception_symbols first_undefined_symbol_n output_object_file;
		# output_object_file = output_object_file FWI (n_exception_symbols-label_n);
		= write_indirect_symbol_table indirect_symbols n_exception_symbols first_undefined_symbol_n output_object_file;

//split_data_symbol_lists_of_files2 :: !{#Int} !{#Bool} ![*SXcoff] -> [*SXcoff];
split_data_symbol_lists_of_files2 :: !{#Int} !{#Bool} ![*SXcoff] -> [SXcoff];
split_data_symbol_lists_of_files2 offset_a marked_bool_a xcoff_list
	=	split_data_symbol_lists_of_files2 0 xcoff_list;
	{
		split_data_symbol_lists_of_files2 :: Int [*SXcoff] -> [SXcoff];
		split_data_symbol_lists_of_files2 file_symbol_index []
			= [];
		split_data_symbol_lists_of_files2 file_symbol_index [xcoff=:{n_symbols,symbol_table}:xcoff_list0] 
			= [ {xcoff & symbol_table={symbol_table & data_symbols=data_symbols1,symbols=symbol_table1 }} : xcoff_list1];
		{
			(data_symbols1,symbol_table1)	= split_data_symbol_list2 symbol_table.data_symbols symbol_table.symbols;
			xcoff_list1						= split_data_symbol_lists_of_files2 (file_symbol_index+n_symbols) xcoff_list0;
//			symbol_table2 = remove_unmarked_symbols 0 n_symbols file_symbol_index marked_bool_a symbol_table1;

			split_data_symbol_list2 :: SymbolIndexList *SSymbolArray -> (!SymbolIndexList,!*SSymbolArray);
			split_data_symbol_list2 EmptySymbolIndex symbol_array0
				= (EmptySymbolIndex,symbol_array0);
			split_data_symbol_list2 (SymbolIndex module_n symbol_list) symbol_array0=:{[module_n]=module_symbol}
				| not marked_bool_a.[file_symbol_index+module_n]
					= split_data_symbol_list2 symbol_list symbol_array0;
					= case module_symbol of {
						Module DATA_SECTION _ _ _ _ _ _
							# (data_symbols,symbol_array1) = split_data_symbol_list2 symbol_list symbol_array0;
							-> (SymbolIndex module_n data_symbols,symbol_array1);
					};
		
			remove_unmarked_symbols :: Int Int Int {#Bool} *SSymbolArray -> *SSymbolArray;
			remove_unmarked_symbols index n_symbols first_symbol_index marked_bool_a symbols0
				| index==n_symbols
					= symbols0;
				| marked_bool_a.[first_symbol_index+index]
					= remove_unmarked_symbols (inc index) n_symbols first_symbol_index marked_bool_a symbols0;
					= remove_unmarked_symbols (inc index) n_symbols first_symbol_index marked_bool_a { symbols0 & [index]=EmptySymbol };
		}
	}

(FWI) infixl;
(FWI) f i = fwritei (swap_bytes i) f;

(FWS) infixl;
(FWS) f s :== fwrites s f;

(FWC) infixl;
(FWC) f c :== fwritec c f;

(FWZ) infixl;
(FWZ) f i :== write_zero_bytes_to_file i f;

write_code_from_files_to_executable :: [SXcoff] Int Int {#Bool} {#Int} {#Int} XcoffArray Bool Sections Int {#Int} [{#Char}] !*File *Files -> (![[*String]],![[*String]],![[*String]],![[*String]],![{#Char}],!*File,!*Files);
write_code_from_files_to_executable [] offset0 first_symbol_n marked_bool_a module_offset_a offset_a xcoff_a one_pass_link sections first_undefined_symbol_n section_addresses relocations pe_file files
	= ([],[],[],[],relocations,pe_file,files);
write_code_from_files_to_executable [xcoff=:{n_symbols,file_name,symbol_table=symbol_table=:{data_symbols,stub_symbols,lazy_pointer_symbols,non_lazy_pointer_symbols,symbols}}:xcoff_list]
		first_symbol_n offset0 marked_bool_a module_offset_a offset_a xcoff_a one_pass_link (Sections text_section data_section sections) first_undefined_symbol_n section_addresses relocations pe_file files
	# (ok,xcoff_file,files)	= fopen file_name FReadData files;
	| not ok	
		= abort ("Cannot read file: "+++file_name);
	# (offset1,relocations,xcoff_file,pe_file)
		= write_code_to_pe_file symbol_table first_symbol_n offset0 marked_bool_a module_offset_a offset_a xcoff_a relocations xcoff_file pe_file;
	# (file_data,xcoff_file) = read_data_from_object_file data_symbols symbols xcoff_file;
	# (file_stubs,xcoff_file) = read_data_from_object_file stub_symbols symbols xcoff_file;
	# (file_lazy_pointers,xcoff_file) = read_data_from_object_file lazy_pointer_symbols symbols xcoff_file;
	# (file_non_lazy_pointers,xcoff_file) = read_data_from_object_file non_lazy_pointer_symbols symbols xcoff_file;
	# (ok,files) = fclose xcoff_file files;
	| not ok
		= abort ("Error while reading file: "+++file_name);
	# (data_strings,stubs_strings,lazy_pointer_strings,non_lazy_pointer_strings,relocations,pe_file,files)
		= write_code_from_files_to_executable xcoff_list (first_symbol_n+n_symbols) offset1 marked_bool_a module_offset_a offset_a xcoff_a one_pass_link sections first_undefined_symbol_n section_addresses relocations pe_file files;
	= ([file_data : data_strings],[file_stubs:stubs_strings],[file_lazy_pointers:lazy_pointer_strings],[file_non_lazy_pointers:non_lazy_pointer_strings],relocations,pe_file,files);
	where {
		read_data_from_object_file EmptySymbolIndex symbol_table xcoff_file
			= ([],xcoff_file);
		read_data_from_object_file (SymbolIndex module_n symbol_list) symbol_table=:{[module_n] = symbol} xcoff_file
			| marked_bool_a.[first_symbol_n+module_n]
				# (data_a,xcoff_file) = case symbol of {
					(Module _ length virtual_address file_offset _ n_relocations relocations)
						# (ok,xcoff_file) = fseek xcoff_file file_offset FSeekSet;
						| not ok
							-> abort ("Read error");
						# (data_a,xcoff_file) = freads xcoff_file length;
						| size data_a==length
							-> (data_a,xcoff_file);
					};
				  (data_strings,xcoff_file)=read_data_from_object_file symbol_list symbol_table xcoff_file;
				= ([data_a:data_strings],xcoff_file);
				= read_data_from_object_file symbol_list symbol_table xcoff_file;

		write_code_to_pe_file :: SSymbolTable Int Int {#Bool} {#Int} {#Int} XcoffArray [{#Char}] *File *File -> (!Int,![{#Char}],!*File,!*File);
		write_code_to_pe_file {text_symbols,symbols,section_offsets,section_symbol_ns}
				first_symbol_n offset0 marked_bool_a module_offset_a offset_a0 xcoff_a relocations xcoff_file pe_file
			=	write_text_to_pe_file text_symbols offset0 symbols relocations xcoff_file pe_file;
			{
				write_text_to_pe_file :: SymbolIndexList Int SSymbolArray [{#Char}] *File *File -> (!Int,![{#Char}],!*File,!*File);
				write_text_to_pe_file EmptySymbolIndex offset0 symbol_table relocations xcoff_file pe_file
					= (offset0,relocations,xcoff_file,pe_file);
				write_text_to_pe_file (SymbolIndex module_n symbol_list) offset0 symbol_table=:{[module_n] = symbol} relocations xcoff_file pe_file
					| marked_bool_a.[first_symbol_n+module_n]
						# (offset1,module_relocations,xcoff_file,pe_file) = write_text_module_to_pe_file symbol offset0 module_offset_a xcoff_file pe_file;
						# relocations = [module_relocations:relocations];
						= write_text_to_pe_file symbol_list offset1 symbol_table relocations xcoff_file pe_file;
						= write_text_to_pe_file symbol_list offset0 symbol_table relocations xcoff_file pe_file;
					{}{
						write_text_module_to_pe_file :: Symbol Int {#Int} *File *File -> (!Int,!{#Char},!*File,!*File);
						write_text_module_to_pe_file (Module TEXT_SECTION length virtual_address file_offset indirect_symbol n_relocations relocations)
								offset0 module_offset_a xcoff_file pe_file
							#  (ok,xcoff_file) = fseek xcoff_file file_offset FSeekSet;
							| not ok
								= abort ("Read error");
							# real_module_offset = module_offset_a.[first_symbol_n+module_n];
							# (text_a0,xcoff_file) = freads xcoff_file length;
							| size text_a0==length
								# alignment=2;
								  alignment_mask=dec (1<<alignment);
								  aligned_offset0=(offset0+alignment_mask) bitand (bitnot alignment_mask);
								  (text_a1,new_relocations) = relocate_text_or_data n_relocations virtual_address aligned_offset0 first_symbol_n TEXT_SECTION first_undefined_symbol_n
								  													section_addresses section_offsets symbols module_offset_a relocations section_symbol_ns offset_a xcoff_a text_a0;
								= (aligned_offset0+length,new_relocations,xcoff_file,fwrites text_a1 (write_nop_bytes_to_file (aligned_offset0-offset0) pe_file));
					}
			}
	}

toHexs n
	= toHex n+++" ";

toHexc n
	= toHex n+++":";

toHex n
	# n0=n bitand 15;
	# c=toChar (n0+(if (n0<10) 48 87));
	# n=(n>>4) bitand 0xfffffff;
	| n==0
		= toString c;
		= toHex n+++toString c;

downSize :: !Int !*{#Char} -> *{#Char};
downSize newSize string
	| newSize<=size string && newSize>=0
		= downSize_ newSize string;

downSize_ :: !Int !*{#Char} -> *{#Char};
downSize_ newSize string = code {
		fill1_r _ARRAY__ 0 1 0 01
	}

relocate_text_or_data n_relocations virtual_address aligned_module_offset first_symbol_n section_n first_undefined_symbol_n
						section_addresses section_offsets symbol_a module_offset_a relocations section_symbol_ns offset_a xcoff_a text_a
	# new_relocations = createArray (size relocations) '\0'; //relocations+++."";
	= relocate_text_or_data 0 0 symbol_a text_a new_relocations;
{
	relocate_text_or_data :: Int Int {!Symbol} *{#Char} *{#Char} -> (!*{#Char},!*{#Char});
	relocate_text_or_data relocation_n new_relocation_n symbol_a text_a new_relocations
		| relocation_n==n_relocations
			= (text_a,downSize (new_relocation_n*SIZE_OF_RELOCATION) new_relocations);
			# relocation_index=relocation_n*SIZE_OF_RELOCATION;
			# new_relocation_index=new_relocation_n*SIZE_OF_RELOCATION;
			| relocations BYTE relocation_index bitand 0x80<>0 // r_scattered
				# r_kind = relocations BYTE relocation_index;
				# r_type=r_kind bitand 0xf;
				# r_address = relocations ITBYTE (relocation_index+1);
				# r_value=relocations ILONG (relocation_index+4);
				# new_r_address=r_address+aligned_module_offset;
				#! new_relocations = {new_relocations &	[new_relocation_index+1]=toChar (new_r_address>>16),
														[new_relocation_index+2]=toChar (new_r_address>>8),
														[new_relocation_index+3]=toChar new_r_address};
				| r_type==PPC_RELOC_BR24
					# (new_address,target_section_n) = determine_new_branch_address r_value first_symbol_n section_offsets symbol_a module_offset_a section_addresses offset_a xcoff_a;
					
					#! old_branch_instruction = text_a ILONG r_address;
					# old_branch_module_address = virtual_address+(((old_branch_instruction bitand 0x3fffffc)<<6)>>6);
					# new_branch_module_address = section_addresses.[section_n]+aligned_module_offset;
					# new_branch_offset=(new_address-(new_branch_module_address/*+r_address*/))+(old_branch_module_address/*+r_address*/-r_value);					
					| new_branch_offset bitand 3<>0
						= abort "relocate_text_or_data: branch offset not multiple of 4";
					# text_a = store_BR24_displacement_at_offset new_branch_offset old_branch_instruction r_address text_a;
					| target_section_n==section_n
						= relocate_text_or_data (inc relocation_n) new_relocation_n symbol_a text_a new_relocations;
						# new_relocations = store_new_scattered_relocation r_kind new_address new_relocation_index new_relocations;
						= relocate_text_or_data (inc relocation_n) (inc new_relocation_n) symbol_a text_a new_relocations;
				| r_type==PPC_RELOC_BR14
					# (new_address,target_section_n) = determine_new_branch_address r_value first_symbol_n section_offsets symbol_a module_offset_a section_addresses offset_a xcoff_a;
					
					#! old_branch_instruction_lo16 = text_a IWORD (r_address+2);
					# old_branch_module_address = virtual_address+(((old_branch_instruction_lo16 bitand 0xfffc)<<16)>>16);
					# new_branch_module_address = section_addresses.[section_n]+aligned_module_offset;
					# new_branch_offset=(new_address-(new_branch_module_address/*+r_address*/))+(old_branch_module_address/*+r_address*/-r_value);
					| new_branch_offset bitand 3<>0
						= abort "relocate_text_or_data: branch offset not multiple of 4";
					# text_a = {text_a & [r_address+2]=toChar (new_branch_offset>>8),
										 [r_address+3]=toChar ((new_branch_offset bitand 0xfc) bitor (old_branch_instruction_lo16 bitand 0x3))
								};
					| target_section_n==section_n
						= relocate_text_or_data (inc relocation_n) new_relocation_n symbol_a text_a new_relocations;
						# new_relocations = store_new_scattered_relocation r_kind new_address new_relocation_index new_relocations;
						= relocate_text_or_data (inc relocation_n) (inc new_relocation_n) symbol_a text_a new_relocations;
				| r_type==PPC_RELOC_VANILLA && r_kind bitand 0x30==0x20
					# new_address = determine_new_address r_value first_symbol_n section_offsets symbol_a module_offset_a section_addresses;
					#! old_offset = text_a ILONG r_address;
					# new_offset = new_address+(old_offset-r_value);
					# text_a = store_long_at_offset new_offset r_address text_a;
					# new_relocations = store_new_scattered_relocation r_kind new_address new_relocation_index new_relocations;
					= relocate_text_or_data (inc relocation_n) (inc new_relocation_n) symbol_a text_a new_relocations;
				# relocation_index2=relocation_index+SIZE_OF_RELOCATION;
				| r_type==PPC_RELOC_LO16
					# r_kind2_scattered = relocations BYTE relocation_index2;
					# r_kind2_not_scattered = relocations BYTE (relocation_index2+7);
					| if (relocations BYTE relocation_index2 bitand 0x80<>0)
						(r_kind2_scattered bitand 0xf<>PPC_RELOC_PAIR)
						(r_kind2_not_scattered bitand 0xf<>PPC_RELOC_PAIR)						
						= abort_relocate_text_or_data_pair_expected PPC_RELOC_LO16;
					# r_address2 = relocations IWORD (relocation_index2+2);
					# address1 = determine_new_address r_value first_symbol_n section_offsets symbol_a module_offset_a section_addresses;
					#! old_lo16 = text_a IWORD (r_address+2);
					# old_offset = (r_address2<<16)+old_lo16;					
					# new_offset = address1+(old_offset-r_value);
					# text_a = {text_a & [r_address+2]=toChar (new_offset>>8),[r_address+3]=toChar new_offset };
					# new_relocations = store_new_scattered_relocation_and_copy_pair r_kind address1 new_relocation_index relocation_index new_relocations relocations;
					# new_relocations = {new_relocations &  [new_relocation_index+10]=toChar (new_offset>>24),
															[new_relocation_index+11]=toChar (new_offset>>16)};
					= relocate_text_or_data (relocation_n+2) (new_relocation_n+2) symbol_a text_a new_relocations;

				| r_type==PPC_RELOC_HA16
					# r_kind2_scattered = relocations BYTE relocation_index2;
					# r_kind2_not_scattered = relocations BYTE (relocation_index2+7);
					| if (relocations BYTE relocation_index2 bitand 0x80<>0)
						(r_kind2_scattered bitand 0xf<>PPC_RELOC_PAIR)
						(r_kind2_not_scattered bitand 0xf<>PPC_RELOC_PAIR)						
						= abort_relocate_text_or_data_pair_expected PPC_RELOC_HA16;
					# r_address2 = relocations IWORD (relocation_index2+2);
					# address1 = determine_new_address r_value first_symbol_n section_offsets symbol_a module_offset_a section_addresses;
					#! old_ha16 = text_a IWORD (r_address+2);
					# old_offset = (old_ha16<<16)+((r_address2<<16)>>16);
					# new_offset = address1+(old_offset-r_value);
					# new_offset_ha16 = (new_offset-((new_offset<<16)>>16))>>16;
					# text_a = {text_a & [r_address+2]=toChar (new_offset_ha16>>8),[r_address+3]=toChar new_offset_ha16 };
					# new_relocations = store_new_scattered_relocation_and_copy_pair r_kind address1 new_relocation_index relocation_index new_relocations relocations;
					# new_relocations = {new_relocations &  [new_relocation_index+10]=toChar (new_offset>>8),
															[new_relocation_index+11]=toChar (new_offset)};
					= relocate_text_or_data (relocation_n+2) (new_relocation_n+2) symbol_a text_a new_relocations;
				# r_kind2 = relocations BYTE relocation_index2;
				# r_value2=relocations ILONG (relocation_index2+4);
				| relocations BYTE relocation_index2 bitand 0x80==0 || r_kind2 bitand 0xf<>PPC_RELOC_PAIR
					= abort_relocate_text_or_data_pair_expected r_type;
				# address1 = determine_new_address r_value  first_symbol_n section_offsets symbol_a module_offset_a section_addresses;
				# address2 = determine_new_address r_value2 first_symbol_n section_offsets symbol_a module_offset_a section_addresses;
				| r_type==PPC_RELOC_HA16_SECTDIFF
					# r_address2 = relocations ITBYTE (relocation_index2+1);
					#! old_ha16 = text_a IWORD (r_address+2);
					# old_diff = (old_ha16<<16)+((r_address2<<16)>>16);
					# addend=(r_value-r_value2)-old_diff;
					# new_diff = (address1-address2)+addend;
					# new_diff_ha16 = (new_diff-((new_diff<<16)>>16))>>16;
					# text_a = {text_a & [r_address+2]=toChar (new_diff_ha16>>8),[r_address+3]=toChar new_diff_ha16 };
					# new_relocations = store_new_scattered_relocation_and_copy_pair r_kind address1 new_relocation_index relocation_index new_relocations relocations;
					# new_relocations = {new_relocations &  [new_relocation_index+12]=toChar (address2>>24),
															[new_relocation_index+13]=toChar (address2>>16),
															[new_relocation_index+14]=toChar (address2>>8),
															[new_relocation_index+15]=toChar address2,
															[new_relocation_index+10]=toChar (new_diff>>8),
															[new_relocation_index+11]=toChar (new_diff)};
					= relocate_text_or_data (relocation_n+2) (new_relocation_n+2) symbol_a text_a new_relocations;
				| r_type==PPC_RELOC_LO16_SECTDIFF
					# r_address2 = relocations ITBYTE (relocation_index2+1);
					#! old_lo16 = text_a IWORD (r_address+2);
					# old_diff = (r_address2<<16)+old_lo16;
					# addend=(r_value-r_value2)-old_diff;
					# new_diff = (address1-address2)+addend;
					# text_a = {text_a & [r_address+2]=toChar (new_diff>>8),[r_address+3]=toChar new_diff };
					# new_relocations = store_new_scattered_relocation_and_copy_pair r_kind address1 new_relocation_index relocation_index new_relocations relocations;
					# new_relocations = {new_relocations &  [new_relocation_index+12]=toChar (address2>>24),
															[new_relocation_index+13]=toChar (address2>>16),
															[new_relocation_index+14]=toChar (address2>>8),
															[new_relocation_index+15]=toChar address2,
															[new_relocation_index+10]=toChar (new_diff>>24),
															[new_relocation_index+11]=toChar (new_diff>>16)};
					= relocate_text_or_data (relocation_n+2) (new_relocation_n+2) symbol_a text_a new_relocations;
				| r_type==PPC_RELOC_SECTDIFF || r_type==PPC_RELOC_LOCAL_SECTDIFF
					#! old_diff = text_a ILONG r_address;													
					# addend=(r_value-r_value2)-old_diff;
					# new_diff = (address1-address2)+addend;
					# text_a = store_long_at_offset new_diff r_address text_a;
					# new_relocations = store_new_scattered_relocation_and_copy_pair r_kind address1 new_relocation_index relocation_index new_relocations relocations;
					# new_relocations = {new_relocations &  [new_relocation_index+12]=toChar (address2>>24),
															[new_relocation_index+13]=toChar (address2>>16),
															[new_relocation_index+14]=toChar (address2>>8),
															[new_relocation_index+15]=toChar address2};
					= relocate_text_or_data (relocation_n+2) (new_relocation_n+2) symbol_a text_a new_relocations;
					= abort ("relocate_text_or_data (scattered) "+++toString r_type);
			# r_kind = relocations BYTE (relocation_index+7);
			# r_type=r_kind bitand 0xf;
			# r_symbolnum = relocations ITBYTE (relocation_index+4);
			# r_address = relocations ILONG relocation_index;
			# new_r_address=r_address+aligned_module_offset;
			#! new_relocations = store_long_at_offset new_r_address new_relocation_index new_relocations;
			| r_type==PPC_RELOC_VANILLA && r_kind bitand 0x60==0x40
				| r_kind bitand 0x10<>0 // r_extern
					= case symbol_a.[r_symbolnum] of {
						UndefinedLabel symbol_n
							# new_r_symbolnum = symbol_n+first_undefined_symbol_n;
							# new_relocations = store_new_relocation r_kind new_r_symbolnum new_relocation_index new_relocations;
							-> relocate_text_or_data (inc relocation_n) (inc new_relocation_n) symbol_a text_a new_relocations;
						ImportedLabelPlusOffset symbol_file_n module_symbol_n label_offset
							# (Module section_n _ virtual_address _ _ _ _) = xcoff_a.[symbol_file_n].symbol_table.symbols.[module_symbol_n];
							#! old_offset = text_a ILONG r_address;
							# new_offset = old_offset+section_addresses.[section_n]+module_offset_a.[offset_a.[symbol_file_n]+module_symbol_n]+label_offset;
							# text_a = store_long_at_offset new_offset r_address text_a;
							# new_relocations = store_new_relocation (r_kind bitand 0xef) section_n new_relocation_index new_relocations;
							-> relocate_text_or_data (inc relocation_n) (inc new_relocation_n) symbol_a text_a new_relocations;
						ImportedLabel symbol_file_n module_symbol_n
							# (Module section_n _ virtual_address _ _ _ _) = xcoff_a.[symbol_file_n].symbol_table.symbols.[module_symbol_n];
							#! old_offset = text_a ILONG r_address;
							# new_offset = old_offset+section_addresses.[section_n]+module_offset_a.[offset_a.[symbol_file_n]+module_symbol_n];
							# text_a = store_long_at_offset new_offset r_address text_a;
							# new_relocations = store_new_relocation (r_kind bitand 0xef) section_n new_relocation_index new_relocations;
							-> relocate_text_or_data (inc relocation_n) (inc new_relocation_n) symbol_a text_a new_relocations;
						Module section_n _ _ _ _ _ _
							#! old_offset = text_a ILONG r_address;
							# new_offset = old_offset+section_addresses.[section_n]+module_offset_a.[first_symbol_n+r_symbolnum];
							# text_a = store_long_at_offset new_offset r_address text_a;
							# new_relocations = store_new_relocation (r_kind bitand 0xef) section_n new_relocation_index new_relocations;
							-> relocate_text_or_data (inc relocation_n) (inc new_relocation_n) symbol_a text_a new_relocations;
						_
							-> abort "relocate_text_or_data PPC_RELOC_VANILLA extern";
					  }	
					# section_symbol_n=section_symbol_ns.[r_symbolnum];
					# (Module section_n _ virtual_address _ _ _ _) = symbol_a.[section_symbol_n];
					# new_virtual_address=section_addresses.[r_symbolnum]+module_offset_a.[first_symbol_n+section_symbol_n];
					#! old_offset = text_a ILONG r_address;
					# new_offset=old_offset-virtual_address+new_virtual_address;
					# text_a = store_long_at_offset new_offset r_address text_a;
					# new_relocations = store_new_relocation r_kind section_n new_relocation_index new_relocations;
					= relocate_text_or_data (inc relocation_n) (inc new_relocation_n) symbol_a text_a new_relocations;
			| r_type==PPC_RELOC_LO16
				# relocation_index2=relocation_index+SIZE_OF_RELOCATION;
				# r_kind2 = relocations BYTE (relocation_index2+7);
				| r_kind2 bitand 0xf<>PPC_RELOC_PAIR
					= abort "relocate_text_or_data: PPC_RELOC_PAIR expected";
				# r_address2 = relocations IWORD (relocation_index2+2);

				| r_kind bitand 0x10<>0 // r_extern
					= case symbol_a.[r_symbolnum] of {
						UndefinedLabel symbol_n
							# new_r_symbolnum = symbol_n+first_undefined_symbol_n;
							# new_relocations = store_new_relocation_and_copy_pair r_kind new_r_symbolnum new_relocation_index relocation_index new_relocations relocations;
							-> relocate_text_or_data (relocation_n+2) (new_relocation_n+2) symbol_a text_a new_relocations;
						ImportedLabelPlusOffset symbol_file_n module_symbol_n label_offset
							# (Module section_n _ virtual_address _ _ _ _) = xcoff_a.[symbol_file_n].symbol_table.symbols.[module_symbol_n];
							#! old_lo16 = text_a IWORD (r_address+2);
							# old_offset = (r_address2<<16)+old_lo16;
							# new_offset = old_offset+section_addresses.[section_n]+module_offset_a.[offset_a.[symbol_file_n]+module_symbol_n]+label_offset;							
							# text_a = {text_a & [r_address+2]=toChar (new_offset>>8), [r_address+3]=toChar new_offset };							
							# new_relocations = store_new_relocation_and_copy_pair (r_kind bitand 0xef) section_n new_relocation_index relocation_index new_relocations relocations;
							# new_relocations = {new_relocations &  [new_relocation_index+10]=toChar (new_offset>>24),
																	[new_relocation_index+11]=toChar (new_offset>>16)};
							-> relocate_text_or_data (relocation_n+2) (new_relocation_n+2) symbol_a text_a new_relocations;
						ImportedLabel symbol_file_n module_symbol_n
							# (Module section_n _ virtual_address _ _ _ _) = xcoff_a.[symbol_file_n].symbol_table.symbols.[module_symbol_n];
							#! old_lo16 = text_a IWORD (r_address+2);
							# old_offset = (r_address2<<16)+old_lo16;
							# new_offset = old_offset+section_addresses.[section_n]+module_offset_a.[offset_a.[symbol_file_n]+module_symbol_n];
							# text_a = {text_a & [r_address+2]=toChar (new_offset>>8), [r_address+3]=toChar new_offset };
							# new_relocations = store_new_relocation_and_copy_pair (r_kind bitand 0xef) section_n new_relocation_index relocation_index new_relocations relocations;
							# new_relocations = {new_relocations &  [new_relocation_index+10]=toChar (new_offset>>24),
																	[new_relocation_index+11]=toChar (new_offset>>16)};
							-> relocate_text_or_data (relocation_n+2) (new_relocation_n+2) symbol_a text_a new_relocations;
						Module section_n _ _ _ _ _ _
							#! old_lo16 = text_a IWORD (r_address+2);
							# old_offset = (r_address2<<16)+old_lo16;
							# new_offset = old_offset+section_addresses.[section_n]+module_offset_a.[first_symbol_n+r_symbolnum];
							# text_a = {text_a & [r_address+2]=toChar (new_offset>>8), [r_address+3]=toChar new_offset };
							# new_relocations = store_new_relocation_and_copy_pair (r_kind bitand 0xef) section_n new_relocation_index relocation_index new_relocations relocations;
							# new_relocations = {new_relocations &  [new_relocation_index+10]=toChar (new_offset>>24),
																	[new_relocation_index+11]=toChar (new_offset>>16)};
							-> relocate_text_or_data (relocation_n+2) (new_relocation_n+2) symbol_a text_a new_relocations;
						_
							-> abort "relocate_text_or_data PPC_RELOC_LO16 extern";
					  }	
					# section_symbol_n=section_symbol_ns.[r_symbolnum];
					# (Module section_n _ virtual_address _ _ _ _) = symbol_a.[section_symbol_n];
					# new_virtual_address=section_addresses.[r_symbolnum]+module_offset_a.[first_symbol_n+section_symbol_n];
					#! old_lo16 = text_a IWORD (r_address+2);
					# old_offset = (r_address2<<16)+old_lo16;
					# new_offset=old_offset-virtual_address+new_virtual_address;
					# text_a = {text_a & [r_address+2]=toChar (new_offset>>8), [r_address+3]=toChar new_offset };
					# new_relocations = store_new_relocation_and_copy_pair r_kind section_n new_relocation_index relocation_index new_relocations relocations;
					# new_relocations = {new_relocations &  [new_relocation_index+10]=toChar (new_offset>>24),
															[new_relocation_index+11]=toChar (new_offset>>16)};
					= relocate_text_or_data (relocation_n+2) (new_relocation_n+2) symbol_a text_a new_relocations;
			| r_type==PPC_RELOC_HA16
				# relocation_index2=relocation_index+SIZE_OF_RELOCATION;
				# r_kind2 = relocations BYTE (relocation_index2+7);
				| r_kind2 bitand 0xf<>PPC_RELOC_PAIR
					= abort "relocate_text_or_data: PPC_RELOC_PAIR expected";
				# r_address2 = relocations IWORD (relocation_index2+2);
				| r_kind bitand 0x10<>0 // r_extern
					= case symbol_a.[r_symbolnum] of {
						UndefinedLabel symbol_n
							# new_r_symbolnum = symbol_n+first_undefined_symbol_n;
							# new_relocations = store_new_relocation_and_copy_pair r_kind new_r_symbolnum new_relocation_index relocation_index new_relocations relocations;
							-> relocate_text_or_data (relocation_n+2) (new_relocation_n+2) symbol_a text_a new_relocations;
						ImportedLabelPlusOffset symbol_file_n module_symbol_n label_offset
							# (Module section_n _ virtual_address _ _ _ _) = xcoff_a.[symbol_file_n].symbol_table.symbols.[module_symbol_n];
							#! old_ha16 = text_a IWORD (r_address+2);
							# old_offset = (old_ha16<<16)+((r_address2<<16)>>16);
							# new_offset = old_offset+section_addresses.[section_n]+module_offset_a.[offset_a.[symbol_file_n]+module_symbol_n]+label_offset;
							# new_ha16 = (new_offset-((new_offset<<16)>>16))>>16;
							# text_a = {text_a & [r_address+2]=toChar (new_ha16>>8), [r_address+3]=toChar new_ha16};
							# new_relocations = store_new_relocation_and_copy_pair (r_kind bitand 0xef) section_n new_relocation_index relocation_index new_relocations relocations;
							# new_relocations = {new_relocations &  [new_relocation_index+10]=toChar (new_offset>>8),
																	[new_relocation_index+11]=toChar new_offset};
							-> relocate_text_or_data (relocation_n+2) (new_relocation_n+2) symbol_a text_a new_relocations;
						ImportedLabel symbol_file_n module_symbol_n
							# (Module section_n _ virtual_address _ _ _ _) = xcoff_a.[symbol_file_n].symbol_table.symbols.[module_symbol_n];
							#! old_ha16 = text_a IWORD (r_address+2);
							# old_offset = (old_ha16<<16)+((r_address2<<16)>>16);
							# new_offset = old_offset+section_addresses.[section_n]+module_offset_a.[offset_a.[symbol_file_n]+module_symbol_n];
							# new_ha16 = (new_offset-((new_offset<<16)>>16))>>16;
							# text_a = {text_a & [r_address+2]=toChar (new_ha16>>8), [r_address+3]=toChar new_ha16};
							# new_relocations = store_new_relocation_and_copy_pair (r_kind bitand 0xef) section_n new_relocation_index relocation_index new_relocations relocations;
							# new_relocations = {new_relocations &  [new_relocation_index+10]=toChar (new_offset>>8),
																	[new_relocation_index+11]=toChar new_offset};
							-> relocate_text_or_data (relocation_n+2) (new_relocation_n+2) symbol_a text_a new_relocations;
						Module section_n _ virtual_address _ _ _ _
							#! old_ha16 = text_a IWORD (r_address+2);
							# old_offset = (old_ha16<<16)+((r_address2<<16)>>16);
							# new_offset = old_offset+section_addresses.[section_n]+module_offset_a.[first_symbol_n+r_symbolnum];
							# new_ha16 = (new_offset-((new_offset<<16)>>16))>>16;
							# text_a = {text_a & [r_address+2]=toChar (new_ha16>>8), [r_address+3]=toChar new_ha16};
							# new_relocations = store_new_relocation_and_copy_pair (r_kind bitand 0xef) section_n new_relocation_index relocation_index new_relocations relocations;
							# new_relocations = {new_relocations &  [new_relocation_index+10]=toChar (new_offset>>8),
																	[new_relocation_index+11]=toChar new_offset};
							-> relocate_text_or_data (relocation_n+2) (new_relocation_n+2) symbol_a text_a new_relocations;
						_
							-> abort "relocate_text_or_data PPC_RELOC_HA16 extern";
					  }
					# section_symbol_n=section_symbol_ns.[r_symbolnum];
					# (Module section_n _ virtual_address _ _ _ _) = symbol_a.[section_symbol_n];
					# new_virtual_address=section_addresses.[r_symbolnum]+module_offset_a.[first_symbol_n+section_symbol_n];
					#! old_ha16 = text_a IWORD (r_address+2);
					# old_offset = (old_ha16<<16)+((r_address2<<16)>>16);
					# new_offset=old_offset-virtual_address+new_virtual_address;
					# new_ha16 = (new_offset-((new_offset<<16)>>16))>>16;
					# text_a = {text_a & [r_address+2]=toChar (new_ha16>>8), [r_address+3]=toChar new_ha16};
					# new_relocations = store_new_relocation_and_copy_pair r_kind section_n new_relocation_index relocation_index new_relocations relocations;
					# new_relocations = {new_relocations &  [new_relocation_index+10]=toChar (new_offset>>8),
															[new_relocation_index+11]=toChar new_offset};
					= relocate_text_or_data (relocation_n+2) (new_relocation_n+2) symbol_a text_a new_relocations;

			| r_type==PPC_RELOC_BR24
				| r_kind bitand 0x10<>0 // r_extern
					#! old_branch_instruction = text_a ILONG r_address;
					#! old_branch_offset = ((old_branch_instruction bitand 0x3fffffc)<<6)>>6;	
					= case symbol_a.[r_symbolnum] of {
						UndefinedLabel symbol_n
							# new_branch_offset = (old_branch_offset+virtual_address)-(section_addresses.[section_n]+aligned_module_offset);
							| new_branch_offset bitand 3<>0
								-> abort "relocate_text_or_data: branch offset not multiple of 4";														
							# text_a = store_BR24_displacement_at_offset new_branch_offset old_branch_instruction r_address text_a;
							# new_r_symbolnum = symbol_n+first_undefined_symbol_n;
							# new_relocations = store_new_relocation r_kind new_r_symbolnum new_relocation_index new_relocations;
							-> relocate_text_or_data (relocation_n+1) (new_relocation_n+1) symbol_a text_a new_relocations;
						ImportedLabelPlusOffset symbol_file_n module_symbol_n label_offset
							# (Module destination_section_n _ _ _ _ _ _) = xcoff_a.[symbol_file_n].symbol_table.symbols.[module_symbol_n];
							# offset=old_branch_offset+(virtual_address+r_address);
							# new_branch_address = section_addresses.[section_n]+aligned_module_offset+r_address;
							# new_address=section_addresses.[destination_section_n]+module_offset_a.[offset_a.[symbol_file_n]+module_symbol_n]+label_offset;
							# new_branch_offset=(new_address-new_branch_address)+offset;							
							| new_branch_offset bitand 3<>0
								-> abort "relocate_text_or_data: branch offset not multiple of 4";							
							# text_a = store_BR24_displacement_at_offset new_branch_offset old_branch_instruction r_address text_a;
							| destination_section_n==section_n
								-> relocate_text_or_data (relocation_n+1) new_relocation_n symbol_a text_a new_relocations;
								# new_relocations = store_new_relocation (r_kind bitand 0xef) destination_section_n new_relocation_index new_relocations;
								-> relocate_text_or_data (relocation_n+1) (new_relocation_n+1) symbol_a text_a new_relocations;
						ImportedLabel symbol_file_n module_symbol_n
							# (Module destination_section_n _ _ _ _ _ _) = xcoff_a.[symbol_file_n].symbol_table.symbols.[module_symbol_n];
							# offset=old_branch_offset+(virtual_address+r_address);
							# new_branch_address = section_addresses.[section_n]+aligned_module_offset+r_address;
							# new_address=section_addresses.[destination_section_n]+module_offset_a.[offset_a.[symbol_file_n]+module_symbol_n];
							# new_branch_offset=(new_address-new_branch_address)+offset;
							| new_branch_offset bitand 3<>0
								-> abort "relocate_text_or_data: branch offset not multiple of 4";							
							# text_a = store_BR24_displacement_at_offset new_branch_offset old_branch_instruction r_address text_a;
							| destination_section_n==section_n
								-> relocate_text_or_data (relocation_n+1) new_relocation_n symbol_a text_a new_relocations;
								# new_relocations = store_new_relocation (r_kind bitand 0xef) destination_section_n new_relocation_index new_relocations;
								-> relocate_text_or_data (relocation_n+1) (new_relocation_n+1) symbol_a text_a new_relocations;
						Module destination_section_n _ _ _ _ _ _
							# offset=old_branch_offset+(virtual_address+r_address);
							# new_branch_address = section_addresses.[section_n]+aligned_module_offset+r_address;
							# new_address=section_addresses.[destination_section_n]+module_offset_a.[first_symbol_n+r_symbolnum];
							# new_branch_offset=(new_address-new_branch_address)+offset;
							| new_branch_offset bitand 3<>0
								-> abort "relocate_text_or_data: branch offset not multiple of 4";							
							# text_a = store_BR24_displacement_at_offset new_branch_offset old_branch_instruction r_address text_a;
							| destination_section_n==section_n
								-> relocate_text_or_data (relocation_n+1) new_relocation_n symbol_a text_a new_relocations;
								# new_relocations = store_new_relocation (r_kind bitand 0xef) destination_section_n new_relocation_index new_relocations;
								-> relocate_text_or_data (relocation_n+1) (new_relocation_n+1) symbol_a text_a new_relocations;
						_
							-> abort "relocate_text_or_data PPC_RELOC_BR24 extern";
					  }
					= abort ("relocate_text_or_data: PPC_RELOC_BR24 not extern");
				= abort ("relocate_text_or_data "+++toString r_type);

	abort_relocate_text_or_data_pair_expected r_kind
		= abort ("relocate_text_or_data: PPC_RELOC_PAIR expected "+++toString r_kind);
}

store_new_relocation r_kind new_r_symbolnum new_relocation_index new_relocations
	= { new_relocations &	[new_relocation_index+4]=toChar (new_r_symbolnum>>16),
							[new_relocation_index+5]=toChar (new_r_symbolnum>>8),
							[new_relocation_index+6]=toChar new_r_symbolnum,
							[new_relocation_index+7]=toChar r_kind};

store_new_relocation_and_copy_pair r_kind section_n new_relocation_index relocation_index new_relocations relocations
	= { store_new_relocation r_kind section_n new_relocation_index new_relocations &
			[new_relocation_index+8]=relocations.[relocation_index+8],
			[new_relocation_index+9]=relocations.[relocation_index+9],
			[new_relocation_index+10]=relocations.[relocation_index+10],
			[new_relocation_index+11]=relocations.[relocation_index+11],
			[new_relocation_index+12]=relocations.[relocation_index+12],
			[new_relocation_index+13]=relocations.[relocation_index+13],
			[new_relocation_index+14]=relocations.[relocation_index+14],
			[new_relocation_index+15]=relocations.[relocation_index+15]};

store_new_scattered_relocation r_kind new_address new_relocation_index new_relocations
	= { new_relocations &	[new_relocation_index]=toChar r_kind,
							[new_relocation_index+4]=toChar (new_address>>24),
							[new_relocation_index+5]=toChar (new_address>>16),
							[new_relocation_index+6]=toChar (new_address>>8),
							[new_relocation_index+7]=toChar new_address};

store_new_scattered_relocation_and_copy_pair r_kind new_address new_relocation_index relocation_index new_relocations relocations
	= { store_new_scattered_relocation r_kind new_address new_relocation_index new_relocations &
			[new_relocation_index+8]=relocations.[relocation_index+8],
			[new_relocation_index+9]=relocations.[relocation_index+9],
			[new_relocation_index+10]=relocations.[relocation_index+10],
			[new_relocation_index+11]=relocations.[relocation_index+11],
			[new_relocation_index+12]=relocations.[relocation_index+12],
			[new_relocation_index+13]=relocations.[relocation_index+13],
			[new_relocation_index+14]=relocations.[relocation_index+14],
			[new_relocation_index+15]=relocations.[relocation_index+15]};	

store_BR24_displacement_at_offset new_branch_offset old_branch_instruction index text_a
	= {text_a & [index]=toChar (((new_branch_offset bitand 0x3000000) bitor (old_branch_instruction bitand 0xfc000000))>>24),
				[index+1]=toChar (new_branch_offset>>16),
				[index+2]=toChar (new_branch_offset>>8),
				[index+3]=toChar ((new_branch_offset bitand 0xfc) bitor (old_branch_instruction bitand 0x3))
	  };

store_long_at_offset :: Int Int *{#Char} -> *{#Char};
store_long_at_offset v index array
	= {array & [index]=toChar (v>>24),[index+1]=toChar (v>>16),[index+2]=toChar (v>>8),[index+3]=toChar v};

write_data_from_non_text_section_to_executable data_sections stub_sections lazy_pointer_sections non_lazy_pointer_sections
												data_section_size stubs_section_size lazy_pointers_section_size non_lazy_pointers_section_size
												xcoff_list4 marked_bool_a module_offset_a marked_offset_a xcoff_a first_undefined_symbol_n section_addresses relocations pe_file
	# (relocations,pe_file) = write_data_from_object_files_to_executable data_sections xcoff_list4 0 0 relocations pe_file;
	# pe_file = write_zero_bytes_to_file ((~data_section_size) bitand 3) pe_file;
	# (relocations,pe_file) = write_stubs_from_object_files_to_executable stub_sections xcoff_list4 0 0 relocations pe_file;
	# pe_file = write_zero_bytes_to_file ((~stubs_section_size) bitand 3) pe_file;
	# (relocations,pe_file) = write_lazy_pointers_from_object_files_to_executable lazy_pointer_sections xcoff_list4 0 0 relocations pe_file;
	# pe_file = write_zero_bytes_to_file ((~lazy_pointers_section_size) bitand 3) pe_file;
	# (relocations,pe_file) = write_non_lazy_pointers_from_object_files_to_executable non_lazy_pointer_sections xcoff_list4 0 0 relocations pe_file;
	= (relocations,write_zero_bytes_to_file ((~non_lazy_pointers_section_size) bitand 3) pe_file);
{
	write_data_from_object_files_to_executable :: [[*{#Char}]] [SXcoff] Int Int [String] *File -> (![String],!*File);
	write_data_from_object_files_to_executable [] [] first_symbol_n offset0 relocations pe_file0
		= (relocations,pe_file0);
	write_data_from_object_files_to_executable [data_section_strings:data_section_list] [xcoff=:{n_symbols,symbol_table={data_symbols,symbols,section_offsets,section_symbol_ns}}:xcoff_list] first_symbol_n offset0 relocations pe_file0
		# (offset1,relocations,pe_file1)
			= write_data_from_object_file_to_executable data_symbols first_symbol_n offset0 symbols section_offsets section_symbol_ns data_section_strings relocations pe_file0;
		= write_data_from_object_files_to_executable data_section_list xcoff_list (first_symbol_n+n_symbols) offset1 relocations pe_file1;
	
	write_stubs_from_object_files_to_executable :: [[*{#Char}]] [SXcoff] Int Int [String] *File -> (![String],!*File);
	write_stubs_from_object_files_to_executable [] [] first_symbol_n offset0 relocations pe_file0
		= (relocations,pe_file0);
	write_stubs_from_object_files_to_executable [data_section_strings:data_section_list] [xcoff=:{n_symbols,symbol_table={stub_symbols,symbols,section_offsets,section_symbol_ns}}:xcoff_list] first_symbol_n offset0 relocations pe_file0
		# (offset1,relocations,pe_file1)
			= write_stub_code_from_object_file_to_executable stub_symbols first_symbol_n offset0 symbols section_offsets section_symbol_ns data_section_strings relocations pe_file0;
		= write_stubs_from_object_files_to_executable data_section_list xcoff_list (first_symbol_n+n_symbols) offset1 relocations pe_file1;
	
	write_lazy_pointers_from_object_files_to_executable :: [[*{#Char}]] [SXcoff] Int Int [String] *File -> (![String],!*File);
	write_lazy_pointers_from_object_files_to_executable [] [] first_symbol_n offset0 relocations pe_file0
		= (relocations,pe_file0);
	write_lazy_pointers_from_object_files_to_executable [data_section_strings:data_section_list] [xcoff=:{n_symbols,symbol_table={lazy_pointer_symbols,symbols,section_offsets,section_symbol_ns}}:xcoff_list] first_symbol_n offset0 relocations pe_file0
		# (offset1,relocations,pe_file1)
			= write_data_from_object_file_to_executable lazy_pointer_symbols first_symbol_n offset0 symbols section_offsets section_symbol_ns data_section_strings relocations pe_file0;
		= write_lazy_pointers_from_object_files_to_executable data_section_list xcoff_list (first_symbol_n+n_symbols) offset1 relocations pe_file1;
	
	write_non_lazy_pointers_from_object_files_to_executable :: [[*{#Char}]] [SXcoff] Int Int [String] *File -> (![String],!*File);
	write_non_lazy_pointers_from_object_files_to_executable [] [] first_symbol_n offset0 relocations pe_file0
		= (relocations,pe_file0);
	write_non_lazy_pointers_from_object_files_to_executable [data_section_strings:data_section_list] [xcoff=:{n_symbols,symbol_table={non_lazy_pointer_symbols,symbols,section_offsets,section_symbol_ns}}:xcoff_list] first_symbol_n offset0 relocations pe_file0
		# (offset1,relocations,pe_file1)
			= write_data_from_object_file_to_executable non_lazy_pointer_symbols first_symbol_n offset0 symbols section_offsets section_symbol_ns data_section_strings relocations pe_file0;
		= write_non_lazy_pointers_from_object_files_to_executable data_section_list xcoff_list (first_symbol_n+n_symbols) offset1 relocations pe_file1;

	write_data_from_object_file_to_executable :: SymbolIndexList Int Int SSymbolArray {#SectionAddressAndSymbolN} {#Int} [*{#Char}] [String] *File -> (!Int,![String],!*File);
	write_data_from_object_file_to_executable EmptySymbolIndex first_symbol_n offset0 symbol_table section_offsets section_symbol_ns data_section_strings relocations pe_file0
		= (offset0,relocations,pe_file0);
	write_data_from_object_file_to_executable (SymbolIndex module_n symbol_list) first_symbol_n offset0 symbol_table=:{[module_n] = symbol} section_offsets section_symbol_ns data_section_strings relocations pe_file0
		| marked_bool_a.[first_symbol_n+module_n]
			= case data_section_strings of {
				[data_a0:data_section_strings]
					# (offset1,module_relocations,pe_file1) = write_data_module_to_pe_file symbol offset0 module_offset_a marked_offset_a xcoff_a data_a0 pe_file0;
					# relocations = [module_relocations:relocations];
					-> write_data_from_object_file_to_executable symbol_list first_symbol_n offset1 symbol_table section_offsets section_symbol_ns data_section_strings relocations pe_file1;
				};
			= write_data_from_object_file_to_executable symbol_list first_symbol_n offset0 symbol_table section_offsets section_symbol_ns data_section_strings relocations pe_file0;
		{}{
			write_data_module_to_pe_file :: Symbol Int {#Int} {#Int} XcoffArray *{#Char} *File -> (!Int,!String,!*File);
			write_data_module_to_pe_file (Module section_n length virtual_address _ _ n_relocations relocations)
					offset0 module_offset_a offset_a xcoff_a data_a0 pe_file0
				# (real_module_offset,module_offset_a) = module_offset_a![first_symbol_n+module_n];
				#! module_offset_a=module_offset_a;
				# alignment=2;
				  alignment_mask=dec (1<<alignment);					
				  aligned_offset0=(offset0+alignment_mask) bitand (bitnot alignment_mask);
				  
				  (data_a1,new_relocations) = relocate_text_or_data n_relocations virtual_address aligned_offset0 first_symbol_n section_n first_undefined_symbol_n
				  													section_addresses section_offsets symbol_table module_offset_a relocations section_symbol_ns offset_a xcoff_a data_a0;

				= (aligned_offset0+length,new_relocations,fwrites data_a1 (write_zero_bytes_to_file (aligned_offset0-offset0) pe_file0));
		}

	write_stub_code_from_object_file_to_executable :: SymbolIndexList Int Int SSymbolArray {#SectionAddressAndSymbolN} {#Int} [*{#Char}] [String] *File -> (!Int,![String],!*File);
	write_stub_code_from_object_file_to_executable EmptySymbolIndex first_symbol_n offset0 symbol_table section_offsets section_symbol_ns data_section_strings relocations pe_file0
		= (offset0,relocations,pe_file0);
	write_stub_code_from_object_file_to_executable (SymbolIndex module_n symbol_list) first_symbol_n offset0 symbol_table=:{[module_n] = symbol} section_offsets section_symbol_ns data_section_strings relocations pe_file0
		| marked_bool_a.[first_symbol_n+module_n]
			= case data_section_strings of {
				[data_a0:data_section_strings]
					# (offset1,module_relocations,pe_file1) = write_stub_module_to_pe_file symbol offset0 module_offset_a marked_offset_a xcoff_a data_a0 pe_file0;
					# relocations = [module_relocations:relocations];
					-> write_stub_code_from_object_file_to_executable symbol_list first_symbol_n offset1 symbol_table section_offsets section_symbol_ns data_section_strings relocations pe_file1;
				};
			= write_stub_code_from_object_file_to_executable symbol_list first_symbol_n offset0 symbol_table section_offsets section_symbol_ns data_section_strings relocations pe_file0;
		{}{
			write_stub_module_to_pe_file :: Symbol Int {#Int} {#Int} XcoffArray *{#Char} *File -> (!Int,!String,!*File);
			write_stub_module_to_pe_file (Module section_n length virtual_address _ _ n_relocations relocations)
					offset0 module_offset_a offset_a xcoff_a data_a0 pe_file0
				# (real_module_offset,module_offset_a) = module_offset_a![first_symbol_n+module_n];
				#! module_offset_a=module_offset_a;
				# (data_a1,new_relocations) = relocate_text_or_data n_relocations virtual_address offset0 first_symbol_n section_n first_undefined_symbol_n
				  													section_addresses section_offsets symbol_table module_offset_a relocations section_symbol_ns offset_a xcoff_a data_a0;
				# aligned_length = ((length+STUB_SIZE-1) / STUB_SIZE) * STUB_SIZE;
				= (offset0+aligned_length,new_relocations,write_zero_bytes_to_file (aligned_length-length) (fwrites data_a1 pe_file0));
		}
}

(THEN) infixl;
(THEN) a f :== f a;

write_zero_longs_to_file n pe_file0
	| n==0
		= pe_file0;
		= write_zero_longs_to_file (dec n) (fwritei 0 pe_file0);

write_zero_bytes_to_file n pe_file0
	| n==0
		= pe_file0;
		= write_zero_bytes_to_file (dec n) (fwritec '\0' pe_file0);

write_nop_bytes_to_file n pe_file0
	| n==0
		= pe_file0;
		= write_nop_bytes_to_file (dec n) (fwritec (toChar 0x90) pe_file0);

find_main_symbol :: NamesTable -> (!Bool,!Int,!Int);
find_main_symbol names_table0
	# (main_names_table_element,_)=find_symbol_in_symbol_table "_main" names_table0;
	= case main_names_table_element of {
		(NamesTableElement _ symbol_n file_n _)
			-> (True,symbol_n,file_n);
		_
			-> (False,0,0);
	};

find_exception_symbols :: [String] NamesTable -> (![(String,Int,Int)],!NamesTable);
find_exception_symbols [] names_table
	= ([],names_table);
find_exception_symbols [exception_symbol_name:exception_symbol_names] names_table
	# (main_names_table_element,names_table)=find_symbol_in_symbol_table exception_symbol_name names_table;
	= case main_names_table_element of {
		(NamesTableElement _ symbol_n file_n _)
			#  (exception_symbols,names_table) = find_exception_symbols exception_symbol_names names_table;
			-> ([(exception_symbol_name,file_n,symbol_n) : exception_symbols],names_table);
		_
			-> find_exception_symbols exception_symbol_names names_table;
	};

link_mach_o_files :: ![String] !String !Files -> (!Bool,![String],!Files);
link_mach_o_files file_names application_file_name files
	#! one_pass_link = True;
	   (read_mach_o_files_errors,sections,n_xcoff_files,xcoff_list0,names_table0,files1)
		= read_mach_o_files file_names create_names_table one_pass_link files 0;
	| not_nil read_mach_o_files_errors
		= (False,read_mach_o_files_errors,files1);
	#! (undefined_symbols,n_undefined_symbols,xcoff_list1,names_table2)=import_symbols_in_xcoff_files [] 0 xcoff_list0 names_table0;
/*
	| not_nil undefined_symbols
		= (False,["Undefined symbols:" : undefined_symbols],files1);
*/
	# (exception_symbols,names_table3)=find_exception_symbols ["_catch_exception_raise","_catch_exception_raise_state","_catch_exception_raise_state_identity"] names_table2;
	#! (main_symbol_error,main_symbol_n,main_file_n) = find_main_symbol names_table3;
	| not  main_symbol_error
		= (False,["Symbol \"main\" not defined"],files1);
	# undefined_symbols = reverse undefined_symbols;
	#! (ok,files5)
		= write_mach_o_file application_file_name n_xcoff_files xcoff_list1 exception_symbols undefined_symbols n_undefined_symbols main_symbol_n main_file_n one_pass_link sections files1;
	| not ok
		= (False,["Link error: Cannot write the application file '"+++application_file_name+++"'"],files5);
	= (True,[],files5);

xcoff_list_to_array n_xcoff_files xcoff_list
	= fill_array 0 xcoff_list (createArray n_xcoff_files empty_xcoff);
{		
	fill_array file_n [] xcoff_a
		= xcoff_a;
	fill_array file_n [xcoff:xcoff_list] xcoff_a
		= fill_array (inc file_n) xcoff_list {xcoff_a & [file_n]=xcoff};
}

xcoff_array_to_list :: Int *{#*SXcoff} -> [*SXcoff];
xcoff_array_to_list i a0
	| i >= size a0
		= [];
		# (a_i,a2)=replace a0 i empty_xcoff;
		#! a_i=a_i;
		= [a_i : xcoff_array_to_list (inc i) a2];
/*
print :: !String !a -> Bool;
print s a
	# (error,_)=ferror (fwrites s stderr);
	| not error
		= True;
*/

compute_size_undefined_symbol_strings [undefined_symbol:undefined_symbols] size_undefined_symbol_strings
	= compute_size_undefined_symbol_strings undefined_symbols (size_undefined_symbol_strings+size undefined_symbol+1);
compute_size_undefined_symbol_strings [] size_undefined_symbol_strings
	= size_undefined_symbol_strings;

count_exception_symbols_and_compute_size_strings [(exception_symbol_name,_,_):exception_symbols] size_exception_symbol_strings n_exception_symbols
	= count_exception_symbols_and_compute_size_strings exception_symbols (size_exception_symbol_strings+size exception_symbol_name+1) (n_exception_symbols+1);
count_exception_symbols_and_compute_size_strings [] size_exception_symbol_strings n_exception_symbols
	= (n_exception_symbols,size_exception_symbol_strings);

write_indirect_symbols_symbol_table [] first_indirect_symbol_string_offset output_object_file
	= output_object_file;
write_indirect_symbols_symbol_table [(section_n,module_offset,string_offset):indirect_symbols] first_indirect_symbol_string_offset output_object_file
	# output_object_file = output_object_file
		FWI (first_indirect_symbol_string_offset+string_offset) FWI (((N_SECT bitor N_EXT)<<24) bitor (section_n<<16)) FWI module_offset
	= write_indirect_symbols_symbol_table indirect_symbols first_indirect_symbol_string_offset output_object_file;

REFERENCE_FLAG_UNDEFINED_LAZY:==1;

write_undefined_symbols [undefined_symbol:undefined_symbols] string_offset pe_file
	# pe_file=pe_file FWI string_offset FWI ((N_UNDF bitor N_EXT)<<24) FWI 0;
//	# pe_file=pe_file FWI string_offset FWI (((N_UNDF bitor N_EXT)<<24) bitor REFERENCE_FLAG_UNDEFINED_LAZY) FWI 0;
	= write_undefined_symbols undefined_symbols (string_offset+size undefined_symbol+1) pe_file;
write_undefined_symbols [] string_offset pe_file
	= pe_file;

write_exception_symbol_strings [(exception_symbol_name,_,_):exception_symbols] exec_file
	# exec_file=fwrites exception_symbol_name exec_file;
	# exec_file=fwritec '\000' exec_file;
	= write_exception_symbol_strings exception_symbols exec_file;
write_exception_symbol_strings [] exec_file
	= exec_file;
	
write_symbol_strings [symbol_name:symbol_names] exec_file
	# exec_file=fwrites symbol_name exec_file;
	# exec_file=fwritec '\000' exec_file;
	= write_symbol_strings symbol_names exec_file;
write_symbol_strings [] exec_file
	= exec_file;

write_function_symbol symbol_file_n symbol_n string_offset xcoff_a module_offset_a offset_a exe_file
	# offset = case xcoff_a.[symbol_file_n].symbol_table.symbols.[symbol_n] of {
					Module _ _ _ _ _ _ _
						= module_offset_a.[offset_a.[symbol_file_n]+symbol_n];
					Label _ label_offset section_symbol_n
						= module_offset_a.[offset_a.[symbol_file_n]+section_symbol_n]+label_offset;
				};
	= exe_file FWI string_offset FWI (((N_SECT bitor N_EXT)<<24) bitor (1<<16)) FWI offset;

write_exception_function_symbols [(exception_symbol_name,file_n,symbol_n):exception_symbols] string_offset xcoff_a2 module_offset_a2 offset_a exe_file
	# exe_file = write_function_symbol file_n symbol_n string_offset xcoff_a2 module_offset_a2 offset_a exe_file;
	= write_exception_function_symbols exception_symbols (string_offset+size exception_symbol_name+1) xcoff_a2 module_offset_a2 offset_a exe_file;
write_exception_function_symbols [] string_offset xcoff_a2 module_offset_a2 offset_a exe_file
	= exe_file;

write_mach_o_file :: .{#Char} Int *[*SXcoff] [(String,Int,Int)] [String] Int Int Int Bool *Sections *Files -> (!Bool,*Files);
write_mach_o_file application_file_name n_xcoff_files xcoff_list1 exception_symbols undefined_symbols n_undefined_symbols
		main_symbol_n main_file_n one_pass_link sections files
	# (n_xcoff_symbols,xcoff_list2) = n_symbols_of_xcoff_list 0 xcoff_list1;

	  (marked_bool_a0,offset_a,xcoff_a0)
		= create_xcoff_boolean_array n_xcoff_files n_xcoff_symbols xcoff_list2;

	  (marked_bool_a1,xcoff_a1,files) = mark_used_modules main_symbol_n main_file_n exception_symbols marked_bool_a0 offset_a xcoff_a0 files;
	# (create_ok,pe_file,files) = fopen application_file_name FWriteData files;
	| not create_ok
		= (False,files);

	# xcoff_list3 = xcoff_array_to_list 0 xcoff_a1;

	  xcoff_list4 = split_data_symbol_lists_of_files2 offset_a marked_bool_a1 xcoff_list3;

	  xcoff_a2 = xcoff_list_to_array n_xcoff_files xcoff_list4;	

	  (text_section_size,data_section_size,bss_section_size,stubs_section_size,lazy_pointers_section_size,non_lazy_pointers_section_size,
		n_code_relocations,n_data_relocations,n_stub_relocations,n_lazy_pointers_relocations,n_non_lazy_pointers_relocations,
		first_lazy_pointer_symbol_n,first_non_lazy_pointer_symbol_n,n_indirect_symbols,module_offset_a2,indirect_symbols)
			= compute_module_offsets n_xcoff_symbols xcoff_list4 marked_bool_a1 xcoff_a2;

	  indirect_symbols = reverse indirect_symbols;

	  text_section_size_align_4=(text_section_size+3 ) bitand -4;
	  data_section_size_align_4=(data_section_size+3) bitand -4;
	  bss_section_size_align_4=(bss_section_size+3) bitand -4;
	  stubs_section_size_align_4=(stubs_section_size+3) bitand -4;
	  lazy_pointers_section_size_align_4=(lazy_pointers_section_size+3) bitand -4;
	  non_lazy_pointers_section_size_align_4=(non_lazy_pointers_section_size+3) bitand -4;

	  bss_offset=text_section_size_align_4+data_section_size_align_4;
	  stubs_offset=bss_offset+bss_section_size_align_4;
	  lazy_pointers_offset=stubs_offset+stubs_section_size_align_4;
	  non_lazy_pointers_offset=lazy_pointers_offset+lazy_pointers_section_size_align_4;

	  section_addresses = {0,0,text_section_size_align_4,bss_offset,stubs_offset,lazy_pointers_offset,non_lazy_pointers_offset};

	  (indirect_symbol_table,indirect_symbols_symbol_table,indirect_symbol_strings,n_exported_indirect_symbols,indirect_symbol_strings_size)
		= compute_indirect_symbol_information indirect_symbols 0 0 xcoff_a2 offset_a module_offset_a2 section_addresses;

	  size_undefined_symbol_strings = compute_size_undefined_symbol_strings undefined_symbols 0;
	  (n_exception_symbols,size_exception_symbol_strings) = count_exception_symbols_and_compute_size_strings exception_symbols 0 0;

	  first_undefined_symbol_n = 1+n_exception_symbols+n_exported_indirect_symbols;

	  pe_file
		= write_mach_o_headers text_section_size_align_4 data_section_size_align_4 bss_section_size_align_4 stubs_section_size_align_4 lazy_pointers_section_size_align_4 non_lazy_pointers_section_size_align_4
								n_code_relocations n_data_relocations n_stub_relocations n_lazy_pointers_relocations n_non_lazy_pointers_relocations
								first_lazy_pointer_symbol_n first_non_lazy_pointer_symbol_n n_indirect_symbols
								first_undefined_symbol_n n_undefined_symbols (7+size_exception_symbol_strings+indirect_symbol_strings_size+size_undefined_symbol_strings) pe_file;

	  relocations = [];
	  (data_sections,stub_sections,lazy_pointer_sections,non_lazy_pointer_sections,relocations,pe_file,files4)
		= write_code_from_files_to_executable xcoff_list4 0 0 marked_bool_a1 module_offset_a2 offset_a xcoff_a2 one_pass_link sections first_undefined_symbol_n section_addresses relocations pe_file files;

	  pe_file=pe_file
		THEN write_zero_bytes_to_file ((~text_section_size) bitand 3);

	  (relocations,pe_file)
	  	= write_data_from_non_text_section_to_executable data_sections stub_sections lazy_pointer_sections non_lazy_pointer_sections
															data_section_size stubs_section_size lazy_pointers_section_size non_lazy_pointers_section_size
															xcoff_list4 marked_bool_a1 module_offset_a2 offset_a xcoff_a2 first_undefined_symbol_n section_addresses
															relocations pe_file;
	  pe_file=pe_file
		THEN write_relocation_strings (reverse relocations);

	  pe_file=pe_file
	  	THEN write_indirect_symbol_table indirect_symbol_table n_exception_symbols first_undefined_symbol_n;

	  pe_file=pe_file
	  	THEN write_function_symbol main_file_n main_symbol_n 1 xcoff_a2 module_offset_a2 offset_a
	  	THEN write_exception_function_symbols exception_symbols 7 xcoff_a2 module_offset_a2 offset_a
	  	THEN write_indirect_symbols_symbol_table indirect_symbols_symbol_table (7+size_exception_symbol_strings)
	  	THEN write_undefined_symbols undefined_symbols (7+size_exception_symbol_strings+indirect_symbol_strings_size);

	  pe_file=pe_file
	  	FWS "\000_main\000"
	  	THEN write_exception_symbol_strings exception_symbols
	  	THEN write_symbol_strings indirect_symbol_strings
	  	THEN write_symbol_strings undefined_symbols;

	= fclose pe_file files4;
