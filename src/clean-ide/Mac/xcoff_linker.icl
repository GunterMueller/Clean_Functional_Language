implementation module xcoff_linker;

import StdFile,StdArray,StdClass,StdEnum,StdInt,StdBool,StdChar;
from StdMisc import abort;
//from StdList import ++;
//from StdString import class %,class +++;
import StdString, StdList;

import linker2,linker3,linker_resources,ConvertMWObject;

// RWS (!=);
(!=) a b :== a<>b;

// RWS (BYTE);
(BYTE) string i :== toInt (string.[i]);

// RWS (LONG);
(LONG) string i
	= (string BYTE i<<24) bitor (string BYTE (i+1)<<16) bitor (string BYTE (i+2)<<8) bitor (string BYTE (i+3));

store_xcoff_relocations_in_modules :: !*Xcoff -> .Xcoff;
store_xcoff_relocations_in_modules xcoff=:{symbol_table,text_relocations,data_relocations,n_text_relocations,n_data_relocations}
	= { xcoff & symbol_table
			= { symbol_table &
					symbols	= store_relocations_in_modules 0 n_data_relocations data_relocations data_symbols
								(store_relocations_in_modules 0 n_text_relocations text_relocations text_symbols symbol_array0)
			  } 
	  };
	{
//		{symbol_table,text_relocations,data_relocations,n_text_relocations,n_data_relocations} = xcoff;
		{text_symbols,data_symbols,symbols=symbol_array0} = symbol_table;
		
		store_relocations_in_modules :: Int Int String SymbolIndexList *SymbolArray -> *SymbolArray;
		store_relocations_in_modules relocation_n n_relocations relocations symbols0 symbol_array0
			| relocation_n==n_relocations
				= symbol_array0;
				= store_relocations_in_modules next_relocation_n n_relocations relocations symbols1 symbol_array1;
				{
					(next_relocation_n,symbols1,symbol_array1)=store_relocation_in_module symbols0 symbol_array0;
					relocation_offset=relocations LONG (relocation_n*SIZE_OF_RELOCATION);

					store_relocation_in_module :: SymbolIndexList *SymbolArray -> (!Int,!SymbolIndexList,!*SymbolArray);
//					store_relocation_in_module :: _ _  -> (!_,!_,!.SymbolArray);
					store_relocation_in_module symbols=:(SymbolIndex index next_symbols) symbol_array=:{[index]=symbol}
						= case symbol of {
							Module {section_n=a,module_offset,length=module_length,align=alignment}
								| relocation_offset>=module_offset && relocation_offset<module_offset+module_length
									-> (relocation_n_for_next_function,symbols,{symbol_array & [index]=module_with_relocation});
									{
										module_with_relocation= Module {section_n=a,module_offset=module_offset,length=module_length,
																		first_relocation_n=relocation_n,end_relocation_n=relocation_n_for_next_function,
																		align=alignment};
										
										relocation_n_for_next_function = add_relocations_to_function (inc relocation_n);
										
										add_relocations_to_function relocation_n
											| relocation_n==n_relocations
												= relocation_n;
											| next_relocation_offset>=module_offset && next_relocation_offset<module_offset+module_length
												= add_relocations_to_function (inc relocation_n);
												= relocation_n;
											{}{
												next_relocation_offset=relocations LONG (relocation_n*SIZE_OF_RELOCATION);
											}
										
									}
									-> store_relocation_in_module next_symbols symbol_array;
						}
				}
	}

is_nil [] = True;
is_nil _ = False;

not_nil [] = False;
not_nil _ = True;

read_xcoff_files :: [String] *NamesTable Bool *Files Int -> (![String],!Sections,!Int,![*Xcoff],!*NamesTable,!*Files);
read_xcoff_files file_names names_table0 one_pass_link files file_n
	= case file_names of {
		[]
			-> ([],EndSections,file_n,[],names_table0,files);
		[file_name:file_names]
			# (ok,xcoff_header_or_error_message,file,files) = open_file_and_read_xcoff_header file_name files;
			| not ok
				#  (_,files) = fclose file files
				-> ([xcoff_header_or_error_message],EndSections,file_n,[],names_table0,files);
			| xcoff_header_or_error_message WORD 0==0x01DF
				# (error,text_section,data_section,xcoff_file0,names_table1,files) = read_xcoff_file file_name names_table0 one_pass_link xcoff_header_or_error_message file files file_n;
				| is_nil error
					#  xcoff_file1 = store_xcoff_relocations_in_modules (sort_modules xcoff_file0);
					   (error2,sections,file_n1,xcoff_files,symbol_table2,files) = read_xcoff_files file_names names_table1 one_pass_link files (inc file_n);
					-> (error2,Sections text_section data_section sections,file_n1,[xcoff_file1:xcoff_files],symbol_table2,files);
					-> (error,EndSections,file_n,[],names_table1,files);
			| xcoff_header_or_error_message LONG 0==0x4D574F42
				# (error,mw_sections2,mw_xcoff_files,file_n2,names_table1,files) = read_mw_object_files file_name file_n names_table0 xcoff_header_or_error_message file files;
				| is_nil error
					#  (error2,sections,file_n1,xcoff_files,symbol_table2,files) = read_xcoff_files file_names names_table1 one_pass_link files file_n2;
					-> (error2,append_sections mw_sections2 sections,file_n1,mw_xcoff_files++xcoff_files,symbol_table2,files);
					{
						append_sections EndSections sections = sections;
						append_sections (Sections a b r) sections = Sections a b (append_sections r sections);
					}
					-> (error,EndSections,file_n,[],names_table1,files);
				-> (["Not an xcoff file: \""+++file_name+++"\""],EndSections,file_n,[],names_table0,files);
	};

import_symbols_in_xcoff_files undefined_symbols [] names_table0
	=	(undefined_symbols,[],names_table0);
import_symbols_in_xcoff_files undefined_symbols0 [xcoff0:xcoff_list0] names_table0
	=	(undefined_symbols2,[xcoff1:xcoff_list1],names_table2);
	{
		(undefined_symbols1,xcoff1,names_table1)
			= import_symbols_in_xcoff_file undefined_symbols0 xcoff0 names_table0;
		
		(undefined_symbols2,xcoff_list1,names_table2)
			= import_symbols_in_xcoff_files undefined_symbols1 xcoff_list0 names_table1;
	};

	import_symbols_in_xcoff_file :: [String] *Xcoff *NamesTable -> ([String],!*Xcoff,!*NamesTable);
	import_symbols_in_xcoff_file undefined_symbols0 xcoff0 names_table0
		=	(undefined_symbols1,{xcoff0 & symbol_table = {symbol_table & symbols=symbols1,imported_symbols=EmptySymbolIndex}},names_table1);
		{
			(undefined_symbols1,symbols1,names_table1)
				= import_symbols imported_symbols undefined_symbols0 symbols names_table0;
//			{symbol_table=symbol_table=:{imported_symbols,symbols}}=xcoff0;
/*
			{symbol_table}=xcoff0;
			{imported_symbols,symbols}=symbol_table;
*/
			symbol_table	= xcoff0.symbol_table;
			imported_symbols= symbol_table.imported_symbols;
			symbols			= symbol_table.symbols;
		};

		import_symbols :: SymbolIndexList [String] *SymbolArray *NamesTable -> ([String],!*SymbolArray,!*NamesTable);
		import_symbols EmptySymbolIndex undefined_symbols symbol_table0 names_table0
			= (undefined_symbols,symbol_table0,names_table0);
		import_symbols (SymbolIndex index symbol_index_list) undefined_symbols symbol_table0=:{[index]=symbol} names_table0
			= case symbol of {
				ImportLabel label_name
					->	case (names_table_element) of {
							NamesTableElement symbol_name symbol_n file_n symbol_list
								->	import_symbols symbol_index_list undefined_symbols symbol_table1 names_table1;
								{
									symbol_table1 = {symbol_table0 & [index] = ImportedLabel {implab_file_n=file_n,implab_symbol_n=symbol_n}};
								}
							EmptyNamesTableElement
								-> case names_table_element2 of {
										NamesTableElement _ symbol_n file_n _
											| file_n<0
												-> import_symbols symbol_index_list undefined_symbols symbol_table1 names_table2;
												{
													symbol_table1 = {symbol_table0 & [index] = 
																	ImportedFunctionDescriptor {implab_file_n=file_n,implab_symbol_n=symbol_n}};
												}
										_
											-> import_symbols symbol_index_list [label_name:undefined_symbols] symbol_table0 names_table2;
									};
									{								
										(names_table_element2,names_table2) = find_symbol_in_symbol_table ("."+++label_name) names_table1;
									}
//								-> import_symbols symbol_index_list [label_name:undefined_symbols] symbol_table0 names_table1;
//								->	abort ("undefined symbol "+++label_name);

						};
					{
						(names_table_element,names_table1) = find_symbol_in_symbol_table label_name names_table0;
					}
			};

find_main_symbol :: *NamesTable -> (!Bool,!Int,!Int);
find_main_symbol names_table0
	= case (main_names_table_element) of {
		(NamesTableElement _ symbol_n file_n _)
			-> (True,symbol_n,file_n);
		_
			-> (False,0,0);
	};
	{
		(main_names_table_element,_)=find_symbol_in_symbol_table "main" names_table0;
	}

mark_used_modules :: !Int !Int !*{#Bool} !{#Int} !*{#*Xcoff} -> (![String],!*{#Bool},!*{#*Xcoff});
mark_used_modules main_symbol_n main_file_n marked_bool_a marked_offset_a xcoff_a
	= mark_used_module main_file_n main_symbol_n [] marked_bool_a xcoff_a;
{
	mark_used_module :: !Int !Int ![String] !*{#Bool} !*{#*Xcoff} -> (![String],!*{#Bool},!*{#*Xcoff});
	mark_used_module file_n symbol_n undefined_symbols marked_bool_a xcoff_a
		| file_n<0
			= (undefined_symbols,{marked_bool_a & [marked_offset_a.[size marked_offset_a+file_n]+symbol_n]=True},xcoff_a);
		# bool_offset=marked_offset_a.[file_n]+symbol_n;
		| marked_bool_a.[bool_offset]
			= (undefined_symbols,marked_bool_a,xcoff_a);
		#  marked_bool_a={marked_bool_a & [bool_offset]=True};
//		#! symbol = xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
		# (symbol,xcoff_a) = xcoff_a![file_n].symbol_table.symbols.[symbol_n];
		=  case symbol of {
			Module {section_n,first_relocation_n,end_relocation_n}
				| first_relocation_n==end_relocation_n
					-> (undefined_symbols,marked_bool_a,xcoff_a);
				| section_n==TEXT_SECTION
//					#! text_relocations = xcoff_a.[file_n].text_relocations;
					# (text_relocations,xcoff_a) = xcoff_a![file_n].text_relocations;
					-> mark_relocations_module first_relocation_n text_relocations undefined_symbols marked_bool_a xcoff_a;
				| section_n==DATA_SECTION || section_n==TOC_SECTION
//						#! data_relocations = xcoff_a.[file_n].data_relocations;
					# (data_relocations,xcoff_a) = xcoff_a![file_n].data_relocations;
					-> mark_relocations_module first_relocation_n data_relocations undefined_symbols marked_bool_a xcoff_a;
				| section_n==BSS_SECTION
					-> (undefined_symbols,marked_bool_a,xcoff_a);
					{};{
						mark_relocations_module relocation_n relocation_string undefined_symbols marked_bool_a xcoff_a
							| relocation_n==end_relocation_n
								= (undefined_symbols,marked_bool_a,xcoff_a);
								# relocation_symbol_n=relocation_string LONG (relocation_n*SIZE_OF_RELOCATION+4);
								  relocation_symbol_n_2=(inc relocation_symbol_n) >> 1;
								  (undefined_symbols,marked_bool_a,xcoff_a)= mark_used_module file_n relocation_symbol_n_2 undefined_symbols marked_bool_a xcoff_a;
								= mark_relocations_module (inc relocation_n) relocation_string undefined_symbols marked_bool_a xcoff_a;
					};
			Label {label_section_n=section_n,label_module_n=module_n}
				-> mark_used_module file_n module_n undefined_symbols marked_bool_a xcoff_a;
			ImportedLabel {implab_file_n=symbol_file_n,implab_symbol_n=imported_symbol_n}
				| symbol_file_n<0
					-> mark_used_module symbol_file_n imported_symbol_n undefined_symbols marked_bool_a xcoff_a;
					#  xcoff_a=replace_imported_label_symbol xcoff_a file_n symbol_n symbol_file_n imported_symbol_n;
					-> mark_used_module symbol_file_n imported_symbol_n undefined_symbols marked_bool_a xcoff_a;
			ImportedLabelPlusOffset {implaboffs_file_n=symbol_file_n,implaboffs_symbol_n=imported_symbol_n}
				-> mark_used_module symbol_file_n imported_symbol_n undefined_symbols marked_bool_a xcoff_a;
			ImportLabel label_name
				-> ([label_name : undefined_symbols],marked_bool_a,xcoff_a);
			ImportedFunctionDescriptor {implab_file_n=symbol_file_n,implab_symbol_n=imported_symbol_n}
				->	mark_used_module symbol_file_n imported_symbol_n undefined_symbols marked_bool_a xcoff_a;
			_
				-> abort ("file "+++toString file_n+++" symbol "+++toString symbol_n);
		};
		{};{
			replace_imported_label_symbol :: *{#*Xcoff} Int Int Int Int -> *{#*Xcoff};
			replace_imported_label_symbol xcoff_a file_n symbol_n symbol_file_n imported_symbol_n
//				#! label_symbol=xcoff_a.[symbol_file_n].symbol_table.symbols.[imported_symbol_n];
				# (label_symbol,xcoff_a) = xcoff_a![symbol_file_n].symbol_table.symbols.[imported_symbol_n];				
				=  case label_symbol of {
					Label {label_offset=v_label_offset,label_module_n=module_n}

//						#! module_symbol=xcoff_a.[symbol_file_n].symbol_table.symbols.[module_n];

						# (module_symbol,xcoff_a) = xcoff_a![symbol_file_n].symbol_table.symbols.[module_n];

						-> case module_symbol of {
							Module {module_offset=v_module_offset}
//								-> (replace_symbol xcoff_a file_n symbol_n
								-> {xcoff_a & [file_n].symbol_table.symbols.[symbol_n]=
									(ImportedLabelPlusOffset {
										implaboffs_file_n=symbol_file_n,
										implaboffs_symbol_n=module_n,
										implaboffs_offset=v_label_offset-v_module_offset})
//										);
										};
							_
								-> xcoff_a;
						   };
					_
						-> xcoff_a
				  };

			replace_symbol :: *{#*Xcoff} Int Int Symbol -> *{#*Xcoff};
			replace_symbol xcoff_a file_n symbol_n symbol
				# (file,xcoff_a) = replace xcoff_a file_n empty_xcoff;
				= {xcoff_a & [file_n] = replace_symbol1 file symbol};
			{
				replace_symbol1 :: *Xcoff Symbol -> *Xcoff;
				replace_symbol1 file=:{symbol_table=symbol_table=:{symbols}} symbol
					= {file & symbol_table={symbol_table & symbols={symbols & [symbol_n]=symbol}}};
			};

/*
			select_symbol1 :: *Xcoff Int -> (!Symbol,!*Xcoff);
			select_symbol1 file=:{symbol_table=symbol_table=:{symbols}} symbol_n
				= (symbol,{file & symbol_table={symbol_table & symbols=symbols1}});
				{
					(symbol,symbols1) = uselect symbols symbol_n;
				}
*/
		};
};

/* RWS ... */
fexists :: !{#Char} !*Files -> (!Bool, !*Files);
fexists path files
	# (exists, file, files)
		=	fopen path FReadData files;
	| not exists
		=	(exists, files);
	// otherwise
	# (_, files)
		=	fclose file files;
	=	(exists, files);
/* ... RWS */

link_xcoff_files :: ![String] ![String] !String !(!Int, !{#Char}) !Int !Int !Int !Int !Int !Int !Int !Bool !Bool !*Files -> ((!Bool,![String]),!*Files);
link_xcoff_files file_names library_file_names application_file_name font_info heap_size heap_size_multiple stack_size
				flags extra_application_memory initial_heap_size memory_profile_minimum_heap_size generate_xcoff add_carb_resource files
	# one_pass_link = True;
	  allow_unused_undefined_symbols = True;
	  (read_xcoff_files_errors,sections,n_xcoff_files,xcoff_list0,names_table0,files1)
	  													= read_xcoff_files file_names create_names_table one_pass_link files 0;
	| not_nil read_xcoff_files_errors
		= ((False,read_xcoff_files_errors),files1);
	# n_libraries = length library_file_names;
	  (read_library_errors,library_list0,n_library_symbols,files2,names_table1)
	  													= read_library_files library_file_names (~n_libraries) 0 files1 names_table0;
	| not_nil read_library_errors
		= ((False,read_library_errors),files2);
	# (undefined_symbols0,xcoff_list1,names_table2)		= import_symbols_in_xcoff_files [] xcoff_list0 names_table1;
	| not allow_unused_undefined_symbols && not_nil undefined_symbols0
		= ((False,["Undefined symbols0:" : undefined_symbols0]),files2);
	# (main_symbol_found,main_symbol_n,main_file_n)		= find_main_symbol names_table2;
	| not main_symbol_found
		= ((False,["Symbol \"main\" not defined"]),files2);
	# (undefined_symbols,n_xcoff_symbols,marked_bool_a1,marked_offset_a0,xcoff_a1)
							= mark_modules main_symbol_n main_file_n xcoff_list1 n_xcoff_files n_libraries n_library_symbols library_list0;
	| not_nil undefined_symbols
		= ((False,["Undefined symbols1:" : undefined_symbols]),files2);
/* RWS ... */
	# (application_existed, files3)
		= fexists application_file_name files2;
/* ... RWS */
	# (ok,error_string,pef_application_size,end_toc_offset,files5)
			= write_output_file generate_xcoff application_file_name
								n_xcoff_files n_libraries n_library_symbols library_list0 
								main_symbol_n main_file_n one_pass_link sections 
								n_xcoff_symbols marked_bool_a1 marked_offset_a0 xcoff_a1 files3;
	| end_toc_offset > 64000	// DvA: initial guess...
		= ((False,["Too many TOC-entries: "+++toString end_toc_offset]),files5);
	| not ok
		= ((False,["Link error: "+++error_string]),files5);
	# (ok2,files6) = create_application_resource application_file_name (if add_carb_resource Carbon Classic) /* RWS ... */ application_existed /* ... RWS */ font_info heap_size heap_size_multiple stack_size flags
												(pef_application_size+extra_application_memory) initial_heap_size memory_profile_minimum_heap_size files5;
	| not ok2
		= ((False,["Link error"]),files6);
	= ((True,[]),files6);
/*
	= (True,[
			"\nNumber of symbols: ",toString n_xcoff_symbols,
			"\nData relocations: ",toString n_data_relocations,
			"\nText relocations: ",toString n_text_relocations,
			"\nNumber of strings: ",toString n_strings,
			"\nSize of strings: ",toString strings_size
			],files6);
*/
