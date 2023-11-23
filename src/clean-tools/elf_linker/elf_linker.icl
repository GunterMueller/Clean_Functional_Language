implementation module elf_linker;

import StdFile,StdArray,StdClass,StdEnum,StdInt,StdBool,StdChar;
from StdMisc import abort;
from StdList import ++,instance length [],reverse;
from StdString import instance % {#Char},instance +++ {#Char},instance toString Int;

import elf_linker2,elf_relocations;

swap_bytes i :== i;
//swap_bytes i = ((i>>24) bitand 0xff) bitor ((i>>8) bitand 0xff00) bitor ((i<<8) bitand 0xff0000) bitor (i<<24);

(!=) a b :== a<>b;

is_nil [] = True;
is_nil _ = False;

not_nil [] = False;
not_nil _ = True;

(CHAR) string i :== string.[i];

:: *Sections = Sections !*String !*String !Sections | EndSections;

read_xcoff_files :: [String] NamesTable Bool Files Int -> (![String],!Sections,!Int,![*Xcoff],!NamesTable,!Files);
read_xcoff_files file_names names_table0 one_pass_link files0 file_n
	= case file_names of {
		[]
			-> ([],EndSections,file_n,[],names_table0,files0);
		[file_name:file_names]
			#	(error,text_section,data_section,xcoff_file0,names_table1,files1)
					= read_xcoff_file file_name names_table0 one_pass_link files0 file_n;
			| is_nil error
				#	(error2,sections,file_n1,xcoff_files,symbol_table2,files2)
						= read_xcoff_files file_names names_table1 one_pass_link files1 (inc file_n);
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

mark_used_modules :: ![(Int,Int)] !*{#Bool} !OffsetArray !*{#*Xcoff} -> (!*{#Bool},!*{#*Xcoff});
mark_used_modules [(main_symbol_n,main_file_n):exported_symbols] marked_bool_a marked_offset_a xcoff_a
	# (marked_bool_a,xcoff_a) = mark_used_module main_file_n main_symbol_n marked_offset_a xcoff_a marked_bool_a;
	= mark_used_modules exported_symbols marked_bool_a marked_offset_a xcoff_a;
{
	mark_used_module :: Int Int OffsetArray *{#*Xcoff} *{#Bool} -> (!*{#Bool},!*{#*Xcoff});
	mark_used_module file_n symbol_n marked_offset_a xcoff_a marked_bool_a0
		| file_n<0
			= ({marked_bool_a0 & [marked_offset_a.[size marked_offset_a+file_n]+symbol_n]=True},xcoff_a);
		# bool_offset=marked_offset_a.[file_n]+symbol_n;
		| marked_bool_a0.[bool_offset]
			= (marked_bool_a0,xcoff_a);
			# marked_bool_a1 = {marked_bool_a0 & [bool_offset]=True};
			  (symbol,xcoff_a1) = xcoff_a![file_n].symbol_table.symbols.[symbol_n];
			= case symbol of {
				Module section_n _ _ _ _ n_relocations relocations _
					| section_n==TEXT_SECTION
						-> mark_relocations_module 0 n_relocations relocations marked_bool_a1 xcoff_a1;
					| section_n==DATA_SECTION
						-> mark_relocations_module 0 n_relocations relocations marked_bool_a1 xcoff_a1;
					| section_n==BSS_SECTION
						-> (marked_bool_a1,xcoff_a1);
				SectionLabel section_n label_offset
					# (section_symbol_n,xcoff_a2) = xcoff_a1![file_n].symbol_table.section_symbol_ns.[section_n];
					  xcoff_a3 = {xcoff_a2 & [file_n].symbol_table.symbols.[symbol_n]=Label section_n label_offset section_symbol_n};
					-> mark_used_module file_n section_symbol_n marked_offset_a xcoff_a3 marked_bool_a1;
				ImportedLabel symbol_file_n imported_symbol_n
					# xcoff_a2=replace_imported_label_symbol xcoff_a1 file_n symbol_n symbol_file_n imported_symbol_n;
					-> mark_used_module symbol_file_n imported_symbol_n marked_offset_a xcoff_a2 marked_bool_a1;
				ImportedLabelPlusOffset symbol_file_n imported_symbol_n _
					-> mark_used_module symbol_file_n imported_symbol_n marked_offset_a xcoff_a1 marked_bool_a1;
				UndefinedLabel _
					-> (marked_bool_a0,xcoff_a);
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
							Module _ v_module_offset _ _ _ _ _ _
								-> {xcoff_a3 & [file_n].symbol_table.symbols.[symbol_n] = ImportedLabelPlusOffset symbol_file_n section_symbol_n (v_label_offset-v_module_offset)};
							_
								-> xcoff_a3
						   };
					Label _ v_label_offset module_n
						#	(module_symbol,xcoff_a2) = xcoff_a1![symbol_file_n].symbol_table.symbols.[module_n];
						-> case module_symbol of {
							Module _ v_module_offset _ _ _ _ _ _
								-> {xcoff_a2 & [file_n].symbol_table.symbols.[symbol_n] = ImportedLabelPlusOffset symbol_file_n module_n (v_label_offset-v_module_offset)};
							_
								-> xcoff_a2;
						   };
					_
						-> xcoff_a1;
				  };

			mark_relocations_module relocation_n n_relocations relocation_string marked_bool_a0 xcoff_a
				| relocation_n>=n_relocations
					= (marked_bool_a0,xcoff_a);
					# relocation_symbol_n=get_relocation_symbol_n relocation_string (relocation_n*SIZE_OF_RELOCATION);
					  (marked_bool_a1,xcoff_a1) = mark_used_module file_n relocation_symbol_n marked_offset_a xcoff_a marked_bool_a0;
					= mark_relocations_module (inc relocation_n) n_relocations relocation_string marked_bool_a1 xcoff_a1;
		}
}
mark_used_modules [] marked_bool_a marked_offset_a xcoff_a
	= (marked_bool_a,xcoff_a);

:: *ModuleOffsets :== *{#Int};

compute_text_module_offsets :: Int Int [SXcoff] {#Bool} XcoffArray -> (!Int,!Int,!ModuleOffsets);
compute_text_module_offsets n_symbols text_offset0 xcoff_list marked_bool_a xcoff_a
	= compute_files_module_offsets xcoff_list text_offset0 0 0 (createArray n_symbols 0);
	{
		compute_files_module_offsets :: [SXcoff] Int Int Int ModuleOffsets -> (!Int,!Int,!ModuleOffsets);
		compute_files_module_offsets [] text_offset0 file_symbol_index n_relocations module_offsets
			= (text_offset0,n_relocations,module_offsets);
		compute_files_module_offsets [{n_symbols,symbol_table}:xcoff_list] text_offset0 file_symbol_index n_relocations module_offsets
			#	(text_offset1,n_relocations,module_offsets)
					= compute_section_module_offsets file_symbol_index marked_bool_a symbol_table.text_symbols symbol_table.symbols text_offset0 n_relocations module_offsets xcoff_a;
			= compute_files_module_offsets xcoff_list text_offset1 (file_symbol_index+n_symbols) n_relocations module_offsets;
	}

compute_data_module_offsets :: [SXcoff] Int Int Int ModuleOffsets XcoffArray -> (!Int,!Int,!ModuleOffsets);
compute_data_module_offsets [] data_offset0 file_symbol_index n_relocations module_offsets0 xcoff_a
	= (data_offset0,n_relocations,module_offsets0);
compute_data_module_offsets [{n_symbols,symbol_table}:xcoff_list] data_offset0 file_symbol_index n_relocations module_offsets0 xcoff_a
	#	(data_offset1,n_relocations,module_offsets1)
			= compute_data_section_module_offsets file_symbol_index symbol_table.data_symbols symbol_table.symbols data_offset0 n_relocations module_offsets0 xcoff_a;
	= compute_data_module_offsets xcoff_list data_offset1 (file_symbol_index+n_symbols) n_relocations module_offsets1 xcoff_a;

	compute_data_section_module_offsets :: Int SymbolIndexList SSymbolArray Int Int ModuleOffsets XcoffArray -> (!Int,!Int,!ModuleOffsets);
	compute_data_section_module_offsets file_symbol_index EmptySymbolIndex symbol_array offset0 n_relocations module_offsets xcoff_a
		= (offset0,n_relocations,module_offsets);
	compute_data_section_module_offsets file_symbol_index (SymbolIndex module_n symbol_list) symbol_array=:{[module_n]=module_symbol} offset0 n_relocations module_offsets xcoff_a
		# (offset1,n_relocations,module_offsets)=compute_module_offset module_symbol module_n offset0 file_symbol_index n_relocations symbol_array module_offsets xcoff_a;
		= compute_data_section_module_offsets file_symbol_index symbol_list symbol_array offset1 n_relocations module_offsets xcoff_a;

compute_bss_module_offsets :: [SXcoff] Int Int {#Bool} ModuleOffsets XcoffArray -> (!Int,!ModuleOffsets);
compute_bss_module_offsets [] bss_offset0 file_symbol_index marked_bool_a module_offsets0 xcoff_a
	= (bss_offset0,module_offsets0);
compute_bss_module_offsets [{n_symbols,symbol_table}:xcoff_list] bss_offset0 file_symbol_index marked_bool_a module_offsets0 xcoff_a
	#	(bss_offset1,n_relocations,module_offsets1)
			= compute_section_module_offsets file_symbol_index marked_bool_a symbol_table.bss_symbols symbol_table.symbols bss_offset0 0 module_offsets0 xcoff_a;
	= compute_bss_module_offsets xcoff_list bss_offset1 (file_symbol_index+n_symbols) marked_bool_a module_offsets1 xcoff_a;

	compute_section_module_offsets :: Int {#Bool} SymbolIndexList SSymbolArray Int Int ModuleOffsets XcoffArray -> (!Int,!Int,!ModuleOffsets);
	compute_section_module_offsets file_symbol_index marked_bool_a EmptySymbolIndex symbol_array offset0 n_relocations module_offsets xcoff_a
		= (offset0,n_relocations,module_offsets);
	compute_section_module_offsets file_symbol_index marked_bool_a (SymbolIndex module_n symbol_list) symbol_array=:{[module_n]=module_symbol} offset0 n_relocations module_offsets xcoff_a
		| not marked_bool_a.[file_symbol_index+module_n]
			= compute_section_module_offsets file_symbol_index marked_bool_a symbol_list symbol_array offset0 n_relocations module_offsets xcoff_a;
			# (offset1,n_relocations,module_offsets)=compute_module_offset module_symbol module_n offset0 file_symbol_index n_relocations symbol_array module_offsets xcoff_a;
			= compute_section_module_offsets file_symbol_index marked_bool_a symbol_list symbol_array offset1 n_relocations module_offsets xcoff_a;

		compute_module_offset :: Symbol Int Int Int Int SSymbolArray ModuleOffsets XcoffArray -> (!Int,!Int,!ModuleOffsets);
		compute_module_offset (Module section_n _ length _ _ old_n_module_relocations relocations align) module_n offset0 file_symbol_index n_relocations symbol_array module_offsets xcoff_a
			#	alignment_mask=align-1;
				aligned_offset0=if ((align bitand alignment_mask)==0)
									((offset0+alignment_mask) bitand (bitnot alignment_mask))
									((offset0+alignment_mask) - ((offset0+alignment_mask) rem align));
			| section_n<>DATA_SECTION
				# n_module_relocations = count_text_relocations old_n_module_relocations relocations symbol_array xcoff_a;
				= (aligned_offset0+length,n_relocations+n_module_relocations,{module_offsets & [file_symbol_index+module_n] = aligned_offset0});
				# n_module_relocations = count_data_relocations old_n_module_relocations relocations symbol_array xcoff_a;
				= (aligned_offset0+length,n_relocations+n_module_relocations,{module_offsets & [file_symbol_index+module_n] = aligned_offset0});
	
write_code_relocations :: [SXcoff] {#Bool} XcoffArray {#Int} {#Int} *File -> *File;
write_code_relocations xcoff_list marked_bool_a xcoff_a module_offset_a offset_a pe_file
	= write_files_code_relocations xcoff_list 0 pe_file;
	{
		write_files_code_relocations :: [SXcoff] Int *File -> *File;
		write_files_code_relocations [] file_symbol_index pe_file
			= pe_file;
		write_files_code_relocations [{n_symbols,symbol_table}:xcoff_list] file_symbol_index pe_file
			# pe_file = write_section_code_relocations file_symbol_index marked_bool_a symbol_table.text_symbols symbol_table.symbols pe_file;
			= write_files_code_relocations xcoff_list (file_symbol_index+n_symbols) pe_file;

		write_section_code_relocations :: Int {#Bool} SymbolIndexList SSymbolArray *File -> *File;
		write_section_code_relocations file_symbol_index marked_bool_a EmptySymbolIndex symbol_array pe_file
			= pe_file;
		write_section_code_relocations file_symbol_index marked_bool_a (SymbolIndex module_n symbol_list) symbol_array=:{[module_n]=module_symbol} pe_file
			| not marked_bool_a.[file_symbol_index+module_n]
				= write_section_code_relocations file_symbol_index marked_bool_a symbol_list symbol_array pe_file;
				# module_offset = module_offset_a.[file_symbol_index+module_n];
				# pe_file=write_text_module_relocations module_symbol module_offset file_symbol_index symbol_array xcoff_a module_offset_a offset_a pe_file;
				= write_section_code_relocations file_symbol_index marked_bool_a symbol_list symbol_array pe_file;
	}

write_data_relocations :: [SXcoff] XcoffArray {#Int} {#Int} *File -> *File;
write_data_relocations xcoff_list xcoff_a module_offset_a offset_a pe_file
	= write_files_data_relocations 0 xcoff_list pe_file;
	{
		write_files_data_relocations :: Int [SXcoff] *File -> *File;
		write_files_data_relocations file_symbol_index [] pe_file
			= pe_file;
		write_files_data_relocations file_symbol_index [{n_symbols,symbol_table}:xcoff_list] pe_file
			# pe_file = write_section_data_relocations file_symbol_index symbol_table.data_symbols symbol_table.symbols pe_file;
			= write_files_data_relocations (file_symbol_index+n_symbols) xcoff_list pe_file;

		write_section_data_relocations :: Int SymbolIndexList SSymbolArray *File -> *File;
		write_section_data_relocations file_symbol_index EmptySymbolIndex symbol_array pe_file
			= pe_file;
		write_section_data_relocations file_symbol_index (SymbolIndex module_n symbol_list) symbol_array=:{[module_n]=module_symbol} pe_file
			# module_offset = module_offset_a.[file_symbol_index+module_n];
			# pe_file=write_data_module_relocations module_symbol module_offset file_symbol_index symbol_array xcoff_a module_offset_a offset_a pe_file;
			= write_section_data_relocations file_symbol_index symbol_list symbol_array pe_file;
	}

split_data_symbol_lists_of_files2 :: !{#Int} !{#Bool} ![*SXcoff] -> [*SXcoff];
split_data_symbol_lists_of_files2 offset_a marked_bool_a xcoff_list
	=	split_data_symbol_lists_of_files2 0 xcoff_list;
	{
		split_data_symbol_lists_of_files2 :: Int [*SXcoff] -> [*SXcoff];
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
						Module DATA_SECTION _ _ _ _ _ _ _
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

write_code_from_elf_files :: [SXcoff] Int Int {#Bool} {#Int} {#Int} XcoffArray Bool Sections !*File *Files -> (![[*String]],!*File,!*Files);
write_code_from_elf_files [] offset0 first_symbol_n marked_bool_a module_offset_a marked_offset_a xcoff_a one_pass_link sections pe_file files
	= ([],pe_file,files);
write_code_from_elf_files [xcoff=:{n_symbols,file_name}:xcoff_list] first_symbol_n offset0 marked_bool_a module_offset_a marked_offset_a xcoff_a one_pass_link (Sections text_section data_section sections) pe_file files
	# (ok,xcoff_file,files)	= fopen file_name FReadData files;
	| not ok
		= abort ("Cannot read file: "+++file_name);
	# (offset1,xcoff_file,pe_file) = write_code_from_elf_file xcoff first_symbol_n offset0 marked_bool_a module_offset_a marked_offset_a xcoff_a xcoff_file pe_file;
	  (file_data,xcoff_file) = read_data_from_object_file xcoff xcoff_file;
		with {
			read_data_from_object_file {symbol_table={data_symbols,symbols}} xcoff_file
				= read_data_from_object_file data_symbols symbols xcoff_file;
			{
				read_data_from_object_file EmptySymbolIndex symbol_table xcoff_file
					= ([],xcoff_file);
				read_data_from_object_file (SymbolIndex module_n symbol_list) symbol_table=:{[module_n] = symbol} xcoff_file
					| marked_bool_a.[first_symbol_n+module_n]
						# (data_a,xcoff_file) = case symbol of {
							(Module DATA_SECTION virtual_module_offset length virtual_address file_offset n_relocations relocations _)
								# (ok,xcoff_file)			= fseek xcoff_file file_offset FSeekSet;
								| not ok
									-> abort ("Read error");
								# (data_a,xcoff_file)	= freads xcoff_file length;
								| size data_a==length
									-> (data_a,xcoff_file);
							};
						  (data_strings,xcoff_file)=read_data_from_object_file symbol_list symbol_table xcoff_file;
						= ([data_a:data_strings],xcoff_file);
						= read_data_from_object_file symbol_list symbol_table xcoff_file;
			}
		}
	  (ok,files) = fclose xcoff_file files;
	| not ok
		= abort ("Error while reading file: "+++file_name);
	#	(data_strings,pe_file,files)	= write_code_from_elf_files xcoff_list (first_symbol_n+n_symbols) offset1 marked_bool_a module_offset_a marked_offset_a xcoff_a one_pass_link sections pe_file files;
	=	([file_data : data_strings],pe_file,files);

write_code_from_elf_file :: SXcoff Int Int {#Bool} {#Int} {#Int} XcoffArray *File *File -> (!Int,!*File,!*File);
write_code_from_elf_file {symbol_table={text_symbols,symbols}}
		first_symbol_n offset0 marked_bool_a module_offset_a marked_offset_a0 xcoff_a xcoff_file pe_file
	=	write_text_to_elf_file text_symbols offset0 symbols xcoff_file pe_file;
	{
		write_text_to_elf_file :: SymbolIndexList Int SSymbolArray *File *File -> (!Int,!*File,!*File);
		write_text_to_elf_file EmptySymbolIndex offset0 symbol_table xcoff_file pe_file
			= (offset0,xcoff_file,pe_file);
		write_text_to_elf_file (SymbolIndex module_n symbol_list) offset0 symbol_table=:{[module_n] = symbol} xcoff_file pe_file
			| marked_bool_a.[first_symbol_n+module_n]
				# (offset1,xcoff_file,pe_file) = write_text_module_to_elf_file symbol offset0 module_offset_a xcoff_file pe_file;
				= write_text_to_elf_file symbol_list offset1 symbol_table xcoff_file pe_file;
				= write_text_to_elf_file symbol_list offset0 symbol_table xcoff_file pe_file;
			{}{
				write_text_module_to_elf_file :: Symbol Int {#Int} *File *File -> (!Int,!*File,!*File);
				write_text_module_to_elf_file (Module TEXT_SECTION virtual_module_offset length virtual_address file_offset n_relocations relocations align)
						offset0 module_offset_a xcoff_file pe_file
					#  (ok,xcoff_file)			= fseek xcoff_file file_offset FSeekSet;
					| not ok
						= abort ("Read error");
					# real_module_offset = module_offset_a.[first_symbol_n+module_n];
					# (text_a0,xcoff_file)	= freads xcoff_file length;
					| size text_a0==length
						#	alignment_mask=align-1;
							aligned_offset0=if ((align bitand alignment_mask)==0)
												((offset0+alignment_mask) bitand (bitnot alignment_mask))
												((offset0+alignment_mask) - ((offset0+alignment_mask) rem align));
						# text_a1 = relocate_text n_relocations virtual_address real_module_offset virtual_module_offset first_symbol_n relocations xcoff_a marked_offset_a0 module_offset_a  symbols text_a0;
						= (aligned_offset0+length,xcoff_file,fwrites text_a1 (write_nop_bytes_to_file (aligned_offset0-offset0) pe_file));
			}
	}

write_data_from_elf_files :: [[*{#Char}]] [SXcoff] Int Int {#Bool} {#Int} {#Int} XcoffArray *File -> *File;
write_data_from_elf_files [] [] first_symbol_n offset0 marked_bool_a module_offset_a marked_offset_a xcoff_a pe_file0
	= pe_file0;
write_data_from_elf_files [data_section_strings:data_section_list] [xcoff=:{n_symbols,symbol_table={data_symbols,symbols}}:xcoff_list] first_symbol_n offset0 marked_bool_a module_offset_a marked_offset_a xcoff_a pe_file0
	#	(offset1,pe_file1)
			= write_toc_or_data_to_elf_file data_symbols first_symbol_n offset0 symbols marked_bool_a
					module_offset_a marked_offset_a xcoff_a data_section_strings pe_file0;
	= write_data_from_elf_files data_section_list xcoff_list (first_symbol_n+n_symbols) offset1 marked_bool_a module_offset_a marked_offset_a xcoff_a pe_file1;

	write_toc_or_data_to_elf_file :: SymbolIndexList Int Int SSymbolArray {#Bool} {#Int} {#Int} XcoffArray [*{#Char}] *File -> (!Int,!*File);
	write_toc_or_data_to_elf_file EmptySymbolIndex first_symbol_n offset0 symbol_table marked_bool_a module_offset_a marked_offset_a0 xcoff_a data_section_strings pe_file0
		= (offset0,pe_file0);
	write_toc_or_data_to_elf_file (SymbolIndex module_n symbol_list) first_symbol_n offset0 symbol_table=:{[module_n] = symbol} marked_bool_a module_offset_a marked_offset_a0 xcoff_a data_section_strings pe_file0
		| marked_bool_a.[first_symbol_n+module_n]
			= case data_section_strings of {
				[data_a0:data_section_strings]
					-> write_toc_or_data_to_elf_file symbol_list first_symbol_n offset1 symbol_table marked_bool_a module_offset_a marked_offset_a0 xcoff_a data_section_strings pe_file1;
					{
						(offset1,pe_file1) = write_data_module_to_elf_file symbol offset0 module_offset_a marked_offset_a0 xcoff_a data_a0 pe_file0;
					}
				};
			= write_toc_or_data_to_elf_file symbol_list first_symbol_n offset0 symbol_table marked_bool_a module_offset_a marked_offset_a0 xcoff_a data_section_strings pe_file0;
		{}{
			write_data_module_to_elf_file :: Symbol Int {#Int} {#Int} XcoffArray *{#Char} *File -> (!Int,!*File);
			write_data_module_to_elf_file (Module section_n virtual_module_offset length virtual_address _ n_relocations relocations align)
					offset0 module_offset_a marked_offset_a0 xcoff_a data_a0 pe_file0
				# (real_module_offset,module_offset_a) = module_offset_a![first_symbol_n+module_n];
				#! module_offset_a=module_offset_a;
				| section_n==DATA_SECTION
					#	alignment_mask=align-1;
						aligned_offset0=if ((align bitand alignment_mask)==0)
											((offset0+alignment_mask) bitand (bitnot alignment_mask))
											((offset0+alignment_mask) - ((offset0+alignment_mask) rem align));
					= (aligned_offset0+length,fwrites data_a1 (write_zero_bytes_to_file (aligned_offset0-offset0) pe_file0));
					{
						data_a1 = relocate_data 0 n_relocations virtual_module_offset virtual_address real_module_offset relocations
												first_symbol_n module_offset_a marked_offset_a0 symbol_table xcoff_a data_a0;
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

find_exported_symbols :: [{#Char}] NamesTable -> (![(Int,Int)],![{#Char}]);
find_exported_symbols [symbol_name:symbol_names] names_table
	# (names_table_element,names_table)=find_symbol_in_symbol_table symbol_name names_table;
	# (exported_symbols,undefined_symbols) = find_exported_symbols symbol_names names_table;
	= case names_table_element of {
		(NamesTableElement _ symbol_n file_n _)
			-> ([(symbol_n,file_n):exported_symbols],undefined_symbols);
		_
			-> (exported_symbols,[symbol_name:undefined_symbols]);
	};
find_exported_symbols [] names_table
	= ([],[]);

link_elf_files :: ![String] ![String] !String !Files -> (!Bool,![String],!Files);
link_elf_files file_names exported_symbol_names application_file_name files
	#! one_pass_link = True;
	   (read_xcoff_files_errors,sections,n_xcoff_files,xcoff_list0,names_table0,files1)
		= read_xcoff_files file_names create_names_table one_pass_link files 0;
	| not_nil read_xcoff_files_errors
		= (False,read_xcoff_files_errors,files1);
	#! (undefined_symbols,n_undefined_symbols,xcoff_list1,names_table2)=import_symbols_in_xcoff_files [] 0 xcoff_list0 names_table0;
/*
	| not_nil undefined_symbols
		= (False,["Undefined symbols:" : undefined_symbols],files1);
*/
	#! (exported_symbols,undefined_exported_symbols) = find_exported_symbols exported_symbol_names  names_table2;
	| not_nil undefined_exported_symbols
		= (False,["Symbol \""+++undefined_exported_symbol+++"\" not defined" \\ undefined_exported_symbol<-undefined_exported_symbols],files1);
	# undefined_symbols = reverse undefined_symbols;
	#! (ok,files5)
		= write_elf_file application_file_name n_xcoff_files xcoff_list1 undefined_symbols n_undefined_symbols exported_symbols exported_symbol_names one_pass_link sections files1;
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

add_size_of_zstrings [symbol_name:symbol_names] size_of_zstrings
	= add_size_of_zstrings symbol_names (size_of_zstrings+size symbol_name+1);
add_size_of_zstrings [] size_of_zstrings
	= size_of_zstrings;

write_exported_symbols :: ![(Int,Int)] ![{#Char}] !Int !*File -> (!Int,!*File);
write_exported_symbols [(exported_symbol_section_n,exported_symbol_offset):exported_symbol_offsets] [exported_symbol_name:exported_symbol_names] string_offset elf_file
	| exported_symbol_section_n==TEXT_SECTION
		# info_other_shndx = BigOrLittleEndian (2 bitor (STT_FUNC<<24) bitor (STB_GLOBAL<<28))
											  	((STB_GLOBAL<<4) bitor STT_FUNC bitor (2<<16));
		# elf_file=write_symbol string_offset info_other_shndx exported_symbol_offset 0 elf_file;
		= write_exported_symbols exported_symbol_offsets exported_symbol_names (string_offset+size exported_symbol_name+1) elf_file;
		# info_other_shndx = BigOrLittleEndian ((exported_symbol_section_n+1) bitor (STT_OBJECT<<24) bitor (STB_GLOBAL<<28))
											  	((STB_GLOBAL<<4) bitor STT_OBJECT bitor ((exported_symbol_section_n+1)<<16));
		# elf_file=write_symbol string_offset info_other_shndx exported_symbol_offset 0 elf_file;
		= write_exported_symbols exported_symbol_offsets exported_symbol_names (string_offset+size exported_symbol_name+1) elf_file;
write_exported_symbols [] [] string_offset elf_file
	= (string_offset,elf_file);

write_undefined_symbols [undefined_symbol:undefined_symbols] string_offset elf_file
	# elf_file=write_symbol string_offset (BigOrLittleEndian (STB_GLOBAL<<28) (STB_GLOBAL<<4)) 0 0 elf_file;
	= write_undefined_symbols undefined_symbols (string_offset+size undefined_symbol+1) elf_file;
write_undefined_symbols [] string_offset elf_file
	= (string_offset,elf_file);

write_symbol_names [undefined_symbol:undefined_symbols] elf_file
	# elf_file=fwrites undefined_symbol elf_file;
	# elf_file=fwritec '\000' elf_file;
	= write_symbol_names undefined_symbols elf_file;
write_symbol_names [] elf_file
	= elf_file;

compute_exported_symbol_offsets [(main_symbol_n,main_file_n):exported_symbols] xcoff_a module_offset_a offset_a
	#! (exported_symbol_section_n,exported_symbol_offset)
		= case xcoff_a.[main_file_n].symbol_table.symbols.[main_symbol_n] of {
			Module section_n _ _ _ _ _ _ _
				-> (section_n,module_offset_a.[offset_a.[main_file_n]+main_symbol_n]);
			Label _ label_offset section_symbol_n
				-> case xcoff_a.[main_file_n].symbol_table.symbols.[section_symbol_n] of {
					Module section_n _ _ _ _ _ _ _
						-> (section_n,module_offset_a.[offset_a.[main_file_n]+section_symbol_n]+label_offset);
				  };
		  };
	= [(exported_symbol_section_n,exported_symbol_offset):compute_exported_symbol_offsets exported_symbols xcoff_a module_offset_a offset_a];
compute_exported_symbol_offsets [] xcoff_a module_offset_a offset_a
	= [];

write_elf_file :: .{#Char} Int *[*SXcoff] [String] Int [(Int,Int)] [{#Char}] Bool *Sections *Files -> (!Bool,*Files);
write_elf_file application_file_name n_xcoff_files xcoff_list1 undefined_symbols n_undefined_symbols
		exported_symbols exported_symbol_names one_pass_link sections files2
#
	(n_xcoff_symbols,xcoff_list2) = n_symbols_of_xcoff_list 0 xcoff_list1;

	(marked_bool_a0,offset_a,xcoff_a0)
		= create_xcoff_boolean_array n_xcoff_files n_xcoff_symbols xcoff_list2;

	(marked_bool_a1,xcoff_a1) = mark_used_modules exported_symbols marked_bool_a0 offset_a xcoff_a0;

	xcoff_list3 = xcoff_array_to_list 0 xcoff_a1;

	xcoff_list4 = split_data_symbol_lists_of_files2 offset_a marked_bool_a1 xcoff_list3;

	xcoff_a2 = xcoff_list_to_array n_xcoff_files xcoff_list4;
	
	(pe_text_section_size,n_code_relocations,module_offset_a0)
		= compute_text_module_offsets n_xcoff_symbols 0 xcoff_list4 marked_bool_a1 xcoff_a2;

	(pe_data_section_size,n_data_relocations,module_offset_a1)
		= compute_data_module_offsets xcoff_list4 0 0 0 module_offset_a0 xcoff_a2;

	(pe_bss_section_size,module_offset_a2)
		= compute_bss_module_offsets xcoff_list4 0 0 marked_bool_a1 module_offset_a1 xcoff_a2;

	exported_symbol_offsets = compute_exported_symbol_offsets exported_symbols xcoff_a2 module_offset_a2 offset_a;

	string_table_size = 18;
	string_table_size = add_size_of_zstrings undefined_symbols string_table_size;
	string_table_size = add_size_of_zstrings exported_symbol_names string_table_size;

	# (create_ok,elf_file,files3) = fopen application_file_name FWriteData files2;
	| not create_ok
		= (False,files3);

		# elf_file
			= write_elf_headers pe_text_section_size pe_data_section_size pe_bss_section_size
								n_code_relocations n_data_relocations (4+length exported_symbol_names+n_undefined_symbols) string_table_size elf_file;
		  (data_sections0,elf_file,files4)
			= write_code_from_elf_files xcoff_list4 0 0 marked_bool_a1 module_offset_a2 offset_a xcoff_a2 one_pass_link sections elf_file files3;

		  pe_text_section_size_4=(pe_text_section_size+3) bitand (-4);

		  elf_file = elf_file
			THEN write_zero_bytes_to_file (pe_text_section_size_4-pe_text_section_size);

		  pe_data_section_size_4=(pe_data_section_size+3) bitand (-4);

		  elf_file = elf_file
			THEN write_data_from_elf_files data_sections0 xcoff_list4 0 0 marked_bool_a1 module_offset_a2 offset_a xcoff_a2
			THEN write_zero_bytes_to_file (pe_data_section_size_4-pe_data_section_size);

		  elf_file=elf_file
			THEN write_code_relocations xcoff_list4 marked_bool_a1 xcoff_a2 module_offset_a2 offset_a
			THEN write_data_relocations xcoff_list4 xcoff_a2 module_offset_a2 offset_a;
	
		  elf_file=write_symbol 0 0 0 0 elf_file;
		  elf_file=write_symbol 1 (BigOrLittleEndian (2 bitor (STT_SECTION<<24)) ((2<<16) bitor STT_SECTION)) 0 0 elf_file;
		  elf_file=write_symbol 7 (BigOrLittleEndian (3 bitor (STT_SECTION<<24)) ((3<<16) bitor STT_SECTION)) 0 0 elf_file;
		  elf_file=write_symbol 13 (BigOrLittleEndian (4 bitor (STT_SECTION<<24)) ((4<<16) bitor STT_SECTION)) 0 0 elf_file;
		  string_offset = 18;
		  (string_offset,elf_file) = write_undefined_symbols undefined_symbols string_offset elf_file;
		  (string_offset,elf_file) = write_exported_symbols exported_symbol_offsets exported_symbol_names string_offset elf_file;

		  elf_file=elf_file
			FWS "\000.text\000.data\000.bss\000"
			THEN write_symbol_names undefined_symbols
			THEN write_symbol_names exported_symbol_names;
	
		= fclose elf_file files4;
