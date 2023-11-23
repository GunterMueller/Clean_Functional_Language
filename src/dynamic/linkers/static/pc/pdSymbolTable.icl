implementation module pdSymbolTable;

import StdEnv;
import xcoff;
import ExtString;
import NamesTable;
import what_linker;
import ExtInt;
import pdExtString;
import pdExtInt;

CreateImportedLabel :: !Int !Int -> Symbol;
CreateImportedLabel file_n symbol_n
	= ImportedLabel file_n symbol_n;

symbol_get_offset :: !Symbol -> Int;
symbol_get_offset (Module  offset _ _ _ _ _ _ )
	= offset;
	
// Label
isLabel :: !Symbol -> Bool;
isLabel (Label _ _ _) = True;
isLabel	_ = False;

getLabel_offset :: !Symbol -> Int;
getLabel_offset (Label _ offset _) = offset;

getLabel_module_n :: !Symbol -> Int;
getLabel_module_n (Label _ _ module_n) = module_n;

// Module
isModule :: !Symbol -> Bool;
isModule (Module  _ _ _ _ _ _ _)	= True;
isModule s						= abort ("isModule: " +++ toString s);

getModule_virtual_label_offset :: !Symbol -> Int;
getModule_virtual_label_offset (Module virtual_label_offset _ _ _ _ _ _) = virtual_label_offset;

fill_library_offsets :: LibraryList Int Int *{#Int} -> *{#Int};
fill_library_offsets EmptyLibraryList file_n offset offset_array
	= offset_array;
fill_library_offsets (Library  _ _ symbols n_symbols libraries) file_n offset offset_array
	= fill_library_offsets libraries (inc file_n) (offset+n_symbols) {offset_array & [file_n]=offset};

:: *Sections = Sections !*String !*String !Sections | EndSections;
	
:: SymbolIndexListKind = Text | Data | Bss;


::	*SymbolArray :== SSymbolArray;
::	SSymbolArray :== {!Symbol};
:: SymbolsArray :== {!.SSymbolArray};

:: SectionKind
	= SK_UNDEF
	| SK_TEXT
	| SK_DATA
	| SK_BSS
	| SK_USER !String
	;

instance == SectionKind
where {
	(==) SK_UNDEF SK_UNDEF	= True;
	(==) SK_TEXT SK_TEXT	= True;
	(==) SK_DATA SK_DATA	= True;
	(==) SK_BSS SK_BSS		= True;
	(==) (SK_USER s1) (SK_USER s2) = s1 == s2;
	(==) _ _				= False;
};

instance toInt SectionKind
where {
	toInt SK_UNDEF	= 0;
	toInt SK_TEXT	= 1;
	toInt SK_DATA	= 2;
	toInt SK_BSS	= 3;
	toInt _			= abort "instance toInt SectionKind; not defined";
};	
	
::	Symbol
	= Module !Int !Int !Int !Int !Int !String !Int		// offset length virtual_address file_offset n_relocations relocations section_n characteristics
	| Label !Int !Int !Int								// section_n offset module_n
	| SectionLabel !Int !Int							// section_n offset
	| ImportLabel !String								// label_name
	| ImportedLabel !Int !Int 							// file_n symbol_n
	| ImportedLabelPlusOffset !Int !Int !Int			// file_n symbol_noffset
	| ImportedFunctionDescriptor !Int !Int 				// file_n symbol_n
	| ImageBaseSymbol
	| EmptySymbol;

::	SymbolIndexList = SymbolIndex !Int !SymbolIndexList | EmptySymbolIndex;

::	LibraryList = Library !String !Int !LibrarySymbolsList !Int !LibraryList | EmptyLibraryList;
//  dll_name dll_base symbols 

::	LibrarySymbolsList = LibrarySymbol !String !LibrarySymbolsList | EmptyLibrarySymbolsList;

:: Xcoff ={
		file_name			:: !String,
		module_name			:: !String,
		symbol_table		:: !.SSymbolTable,
		n_symbols			:: !Int
	};

::	*SymbolTable :== *SSymbolTable;
:: SSymbolTable ={
		text_symbols	:: !SymbolIndexList,
		data_symbols	:: !SymbolIndexList,
		bss_symbols		:: !SymbolIndexList,
		imported_symbols:: !SymbolIndexList,
		section_symbol_ns::!.{#Int},
		n_sections		:: !Int,
		symbols			:: !.SSymbolArray,
		extra_sections	:: [ExtraSection]
	};
	
:: ExtraSection 
	= { 
		es_name			:: !String
	,	es_flags		:: !Int
	,	es_symbols		:: !SymbolIndexList
	,	es_buffer_n		:: !Int
	};	

:: Directive
	= {
		dr_section_name		:: !String
	,	dr_section_flags 	:: !String
	,	dr_section_n		:: !Int
	,	dr_section_kind		:: SectionKind
	};
	
imported_library_symbols :: !.LibrarySymbolsList !Int !{#.Bool} -> .[String];
imported_library_symbols EmptyLibrarySymbolsList offset marked_bool_a
	= [];
imported_library_symbols (LibrarySymbol symbol_name library_symbols) offset marked_bool_a
	| marked_bool_a.[offset]
		= [symbol_name : imported_library_symbols library_symbols (inc offset) marked_bool_a];
		= imported_library_symbols library_symbols (inc offset) marked_bool_a;
			
:: UndefinedSymbol :== ({#Char},Int,Int);

import_symbols_in_xcoff_files :: !*[*Xcoff] !Int [({#Char},Int,Int)] !*NamesTable -> (![({#Char},Int,Int)],![*Xcoff],!*NamesTable);
import_symbols_in_xcoff_files [] xcoff_n undefined_symbols names_table0
	= (undefined_symbols,[],names_table0);
		
import_symbols_in_xcoff_files [xcoff0:xcoff_list0] xcoff_n undefined_symbols0 names_table0
	# (undefined_symbols1,xcoff1,names_table1)		
		= import_symbols_in_xcoff_file undefined_symbols0 xcoff0 names_table0;
		
	# (undefined_symbols2,xcoff_list1,names_table2)	
		= import_symbols_in_xcoff_files xcoff_list0 (xcoff_n+1) undefined_symbols1 names_table1;
	
	= (undefined_symbols2,[xcoff1:xcoff_list1],names_table2);
{
	import_symbols_in_xcoff_file :: [UndefinedSymbol] *Xcoff *NamesTable -> ([UndefinedSymbol],!*Xcoff,!*NamesTable);
	import_symbols_in_xcoff_file undefined_symbols xcoff0=:{symbol_table=symbol_table=:{imported_symbols,symbols}} names_table
		# (undefined_symbols,symbols,names_table) 
			= import_symbols imported_symbols undefined_symbols symbols names_table;
		
		= (undefined_symbols,{xcoff0 & symbol_table = {symbol_table & symbols=symbols,imported_symbols=EmptySymbolIndex}},names_table);

		import_symbols :: SymbolIndexList [UndefinedSymbol] *SymbolArray *NamesTable -> ([UndefinedSymbol],!*SymbolArray,!*NamesTable);
		import_symbols EmptySymbolIndex undefined_symbols symbol_table0 names_table0
			= (undefined_symbols,symbol_table0,names_table0);

		import_symbols (SymbolIndex index symbol_index_list) undefined_symbols symbol_table0=:{[index]=symbol} names_table0
			= case symbol of {
				ImportLabel label_name
					#  (names_table_element,names_table1) 
						= find_symbol_in_symbol_table label_name names_table0;
					-> case names_table_element of {
						NamesTableElement symbol_name symbol_n file_n symbol_list
							#  symbol_table1 = {symbol_table0 & [index] = ImportedLabel file_n symbol_n};
							-> import_symbols symbol_index_list undefined_symbols symbol_table1 names_table1;

						EmptyNamesTableElement
							| size label_name<6 || label_name.[0]<>'_' || label_name.[1]<>'_' || label_name.[2]<>'i' 
												|| label_name.[3]<>'m' || label_name.[4]<>'p' || label_name.[5]<>'_'
								->	import_symbols symbol_index_list [(label_name,xcoff_n,index):undefined_symbols] symbol_table0 names_table1;
							
								# (names_table_element2,names_table2) = find_symbol_in_symbol_table (label_name % (6,size label_name-1)) names_table1;
								->	case names_table_element2 of {
										NamesTableElement _ symbol_n file_n _
												| file_n<0
													-> import_symbols symbol_index_list undefined_symbols symbol_table1 names_table2;
													{
														symbol_table1 = {symbol_table0 & [index] = ImportedFunctionDescriptor file_n symbol_n};
													}
												_
													-> import_symbols symbol_index_list [(label_name,xcoff_n,index):undefined_symbols] symbol_table0 names_table2;
										}
						}
			}
	}
				
:: OffsetArray :== {#Int};

instance toString Symbol
where {
	toString (Module offset length virtual_address file_offset n_relocations relocations _)
		= "Module " +++ 
			"   \nlength: " +++ hex_int length +++
			"   \nn_relocations: " +++ hex_int n_relocations ;
	toString (Label _ _ _)
		= "Label";
	toString (SectionLabel _ _ )
		= "SectionLabel";
	toString (ImportLabel _ )
		=  "ImportLabel";
	toString (ImportedLabel i j)
		= "ImportedLabel " +++ toString i +++ " - " +++ toString j;
	toString (ImportedLabelPlusOffset _ _ _)
		= "ImportedLabelPlusOffset";
	toString (ImportedFunctionDescriptor _ _)
		= "ImportedFunctionDescriptor";
	toString (EmptySymbol)
		= "EmptySymbol";
};

mark_used_modules :: !Int !Int ![String] !{#Bool} !*{#Bool} !*{#Int} !*{#*Xcoff} -> (![String],!*{#Int}, !*{#Bool},!*{#*Xcoff});
mark_used_modules main_symbol_n main_file_n undefined_symbols already_marked_bool marked_bool_a0 marked_offset_a xcoff_a
	= mark_used_module main_file_n main_symbol_n undefined_symbols marked_offset_a xcoff_a marked_bool_a0;
{
	mark_used_module :: !Int !Int ![String] !*{#Int} !*{#*Xcoff} !*{#Bool} -> (![String],!*{#Int},!*{#Bool},!*{#*Xcoff});
	mark_used_module file_n symbol_n undefined_symbols marked_offset_a xcoff_a marked_bool_a0
		# s = "file_n: " +++ toString file_n +++ " symbol_n: " +++ (hex_int symbol_n);
		
		| file_n < 0
			#! (size1, marked_offset_a) 
				= usize marked_offset_a;
			#! (first_symbol_n, marked_offset_a)
				= marked_offset_a![size1 + file_n];
			#! index_of_symbol_n
				= first_symbol_n + symbol_n;
			#! (marked_symbol_n,already_marked_bool)
				= already_marked_bool![index_of_symbol_n];
			| marked_symbol_n
				= (undefined_symbols,marked_offset_a,marked_bool_a0,xcoff_a);
				
				= (undefined_symbols,marked_offset_a,{marked_bool_a0 & [index_of_symbol_n] = True},xcoff_a);

		# (first_symbol_n, marked_offset_a1) 
			= marked_offset_a![file_n];
		# bool_offset
			=first_symbol_n + symbol_n;
		| marked_bool_a0.[bool_offset]
			= (undefined_symbols,marked_offset_a1,marked_bool_a0,xcoff_a);
		| already_marked_bool.[bool_offset]
			= (undefined_symbols,marked_offset_a1,marked_bool_a0,xcoff_a);

			# marked_bool_a1 = {marked_bool_a0 & [bool_offset]=True};
			
			#! (symbol,xcoff_a) = xcoff_a![file_n].symbol_table.symbols.[symbol_n];
			# marked_bool_a1 = {marked_bool_a0 & [bool_offset]=True};
			= case symbol of {
				(Module c1 length virtual_address c2 n_relocations relocations _)
					-> mark_relocations_module 0 n_relocations undefined_symbols relocations marked_bool_a1 xcoff_a marked_offset_a1;
						{
mark_relocations_module relocation_n n_relocations undefined_symbols relocation_string marked_bool_a0 xcoff_a marked_offset_a
	| relocation_n>=n_relocations
		= (undefined_symbols,marked_offset_a, marked_bool_a0,xcoff_a);

		#! relocation_index = relocation_n * SIZE_OF_RELOCATION;
		#! relocation_type = relocations IWORD (relocation_index+8);
		#!	relocation_symbol_n = relocations ILONG (relocation_index+4);
		#!	relocation_offset = relocations ILONG relocation_index;
			
		// JMP ...
		#! (marked_offset_a,xcoff_a)
			= what_linker (marked_offset_a,xcoff_a) (case (((relocation_offset-virtual_address) + 4) == length) of {
				True
					#! module_n = symbol_n;		
					#! (first_symbol_n, marked_offset_a) = marked_offset_a![file_n];
					#! bool_offset = first_symbol_n + relocation_symbol_n;
					|  already_marked_bool.[bool_offset] //&& relocation_type == REL_ABSOLUTE
						// There is a reference from an (yet) unlinked module to another already linked module. If the unlinked
						// module does not contain an jump instruction at its end, one has to be generated. Accessing the file
						// is expensive. Therefore the worst is assumed: there is a non-jump in which case one has to be 
						// generated.
						/*
						#! updated_relocations
							= WriteLong { c \\ c <-: relocations} relocation_index (relocation_offset + 5) +++ "1"; 
							
						#! updated_module_symbol
							= Module c1 (length + 5) virtual_address c2 /*(inc n_relocations)*/ n_relocations updated_relocations;
						*/
						
						#! (module_name,xcoff_a) = xcoff_a![file_n].module_name;
						
						/*
						#! xcoff_a = upd_symbol updated_module_symbol file_n module_n xcoff_a;
						*/
						| relocation_type == REL_ABSOLUTE
							// in this case an extra jump should be generated because the module does not end on one. The
							// relocation type should probably be changed into REL_REL32. The above code should be valid.
							-> abort "pdSymbolTable: jmp problem; please report immediately martijnv@cs.kun.nl";
						
							-> (marked_offset_a,xcoff_a);
						-> (marked_offset_a,xcoff_a);				
				False
					-> (marked_offset_a,xcoff_a); 
			}
		// ... JMP
		);

		#! (undefined_symbols2,marked_offsets_a2, marked_bool_a1,xcoff_a1) 
			= mark_used_module file_n relocation_symbol_n undefined_symbols marked_offset_a xcoff_a marked_bool_a0;
		= mark_relocations_module (inc relocation_n) n_relocations undefined_symbols2 relocation_string marked_bool_a1 xcoff_a1 marked_offsets_a2;
						}
						
				SectionLabel section_n label_offset
					| section_n>=1
						-> case section_symbol_n == (-1) of {
							True
								-> abort ("een foutje" +++ toString section_symbol_n +++ " - " +++ toString label_offset);
								
							False
								-> mark_used_module file_n section_symbol_n undefined_symbols marked_offset_a1 xcoff_a3 marked_bool_a1;
						};

					{
						xcoff_a3 = replace_symbol xcoff_a2 file_n symbol_n (Label section_n label_offset section_symbol_n);
						(section_symbol_n,xcoff_a2) = select_section_symbol_n xcoff_a file_n section_n;
					}

				ImportedLabel symbol_file_n imported_symbol_n
					->	if (symbol_file_n<0)
							(mark_used_module symbol_file_n imported_symbol_n undefined_symbols marked_offset_a1 xcoff_a marked_bool_a1)
							(mark_used_module symbol_file_n imported_symbol_n undefined_symbols marked_offset_a1 xcoff_a2 marked_bool_a1);
						{
							xcoff_a2=replace_imported_label_symbol xcoff_a file_n symbol_n symbol_file_n imported_symbol_n;
						}
				ImportedLabelPlusOffset symbol_file_n imported_symbol_n _
					-> mark_used_module symbol_file_n imported_symbol_n undefined_symbols marked_offset_a1 xcoff_a marked_bool_a1;
					
				ImportLabel label_name
					-> ([label_name : undefined_symbols],marked_offset_a1,marked_bool_a1,xcoff_a);
					
				ImportedFunctionDescriptor symbol_file_n imported_symbol_n
					->	mark_used_module symbol_file_n imported_symbol_n undefined_symbols marked_offset_a1 xcoff_a marked_bool_a1;
				EmptySymbol
					-> abort "EmptySymbol; internal error in mark_used_modules";
				
			};
		
		 {
			select_section_symbol_n :: !*{#*Xcoff} !Int !Int -> (!Int,!*{#*Xcoff});
			select_section_symbol_n xcoff_a0 file_n section_n
				= xcoff_a0![file_n].symbol_table.section_symbol_ns.[section_n];
	
			replace_symbol :: !*{#*Xcoff} !Int !Int !Symbol -> *{#*Xcoff};
			replace_symbol xcoff_a0 file_n symbol_n symbol
				= { xcoff_a0 & [file_n].symbol_table.symbols.[symbol_n] = symbol };		

			replace_imported_label_symbol :: !*{#*Xcoff} !Int !Int !Int !Int -> *{#*Xcoff};
			replace_imported_label_symbol xcoff_a0 /* import site */ file_n symbol_n /* label being imported */ symbol_file_n imported_symbol_n
				# (file0,xcoff_a1) = replace xcoff_a0 symbol_file_n empty_xcoff;
				(label_symbol,file1) = file0!symbol_table.symbols.[imported_symbol_n];	

				= case label_symbol of {
					SectionLabel section_n v_label_offset
						# (section_symbol_n,file2) = select_symbol_section_n1 file1 section_n;
						# (module_symbol,file3) = file2!symbol_table.symbols.[section_symbol_n];

						-> case module_symbol of {
							Module v_module_offset _ _ _ _ _ _
								-> 
									(replace_symbol {xcoff_a1 & [symbol_file_n] = file3} file_n symbol_n
									(ImportedLabelPlusOffset symbol_file_n section_symbol_n (v_label_offset-v_module_offset)));
							_
								-> {xcoff_a1 & [symbol_file_n] = file3};
						   };
					Label _ v_label_offset module_n
						/* 
							at an earlier point in time, mark_used_modules has already converted a Section-
							Label into a Label. Re-implements a part of the SectionLabel-case.
						*/
						# (module_symbol,file2) = file1!symbol_table.symbols.[module_n];
						-> case module_symbol of {
							Module v_module_offset _ _ _ _ _ _
								-> 	(replace_symbol {xcoff_a1 & [symbol_file_n] = file2} file_n symbol_n
									(ImportedLabelPlusOffset symbol_file_n module_n (v_label_offset-v_module_offset)));
							_
								-> {xcoff_a1 & [symbol_file_n] = file2};
						   };
					_
						-> {xcoff_a1 & [symbol_file_n] = file1};
				  };

			select_symbol_section_n1 :: !*Xcoff !Int -> (!Int,!*Xcoff);
			select_symbol_section_n1 file section_n
				= file!symbol_table.section_symbol_ns.[section_n];
		}
}

xcoff_list_to_array :: !.Int ![.Xcoff] -> {#Xcoff};
xcoff_list_to_array n_xcoff_files xcoff_list
	= fill_array 0 xcoff_list (createArray n_xcoff_files empty_xcoff);
{		
	fill_array file_n [] xcoff_a
		= xcoff_a;
	fill_array file_n [xcoff:xcoff_list] xcoff_a
		= fill_array (inc file_n) xcoff_list {xcoff_a & [file_n]=xcoff};
}

xcoff_array_to_list :: !Int !*{#*Xcoff} -> [*Xcoff];
xcoff_array_to_list i a0
	| i >= size a0
		= [];
		= [a_i : xcoff_array_to_list (inc i) a2];
where {
	(a_i,a2)=replace a0 i empty_xcoff;
}
		
empty_xcoff ::.Xcoff;
empty_xcoff
	= { file_name="",module_name="",symbol_table=empty_symbol_table,n_symbols=0};
	{
		
		empty_symbol_table :: .SSymbolTable;
		empty_symbol_table = {	
			text_symbols=EmptySymbolIndex,data_symbols=EmptySymbolIndex,bss_symbols=EmptySymbolIndex,
			imported_symbols=EmptySymbolIndex,symbols={},section_symbol_ns={},n_sections=0,extra_sections=[]
		};
	}

xcoff_list_to_xcoff_array :: ![*Xcoff] !Int -> *{#*Xcoff};
xcoff_list_to_xcoff_array xcoff_list n_xcoffs
	= fill_xcoff_array 0 xcoff_list (xcoff_array n_xcoffs);
{
	xcoff_array :: !Int -> *{#*Xcoff};
	xcoff_array n = { empty_xcoff \\ i<-[0..dec n]};
	
	fill_xcoff_array i [] xcoff_a
		= xcoff_a;
	fill_xcoff_array i [xcoff=:{symbol_table}:xcoff_list] xcoff_a
		= fill_xcoff_array (inc i) xcoff_list {xcoff_a & [i]=xcoff};
}

// assumuption: a normal static link is performed		
remove_garbage_from_symbol_table :: !Int !Int Int *{#Bool} {#*Xcoff} -> (*{#Bool},{#*Xcoff});
remove_garbage_from_symbol_table file_n limit file_symbol_n marked_bool_a xcoff_a
	| (file_n == limit)
		= (marked_bool_a,xcoff_a);

		#! (xcoff_n=:{n_symbols,symbol_table},xcoff_a)
			= replace xcoff_a file_n empty_xcoff;
			
		// remove symbols
		#! (text_symbols,symbols_a,marked_bool_a,count)
			= remove_garbage symbol_table.text_symbols symbol_table.symbols marked_bool_a 0;
		#! (data_symbols,symbols_a,marked_bool_a,count)
			= remove_garbage symbol_table.data_symbols symbols_a marked_bool_a count;
		#! (bss_symbols,symbols_a,marked_bool_a,count)
			= remove_garbage symbol_table.bss_symbols symbols_a marked_bool_a count;

//		#! s_xcoff_n = "xcoff: " +++ toString file_n +++ "count: " +++ toString count +++ " total: " +++ toString n_symbols;	
		#! xcoff_n = { xcoff_n & symbol_table = {symbol_table & text_symbols=text_symbols, data_symbols=data_symbols, bss_symbols=bss_symbols,symbols=symbols_a} }
		#! xcoff_a = { xcoff_a & [file_n] = xcoff_n };

		= remove_garbage_from_symbol_table (inc file_n) limit (file_symbol_n + n_symbols) marked_bool_a xcoff_a;
where {
	remove_garbage EmptySymbolIndex symbols_a marked_bool_a count
		= (EmptySymbolIndex,symbols_a,marked_bool_a,count);
	remove_garbage (SymbolIndex module_n sis) symbols_a=:{[module_n]=module_symbol} marked_bool_a count
		| marked_bool_a.[file_symbol_n + module_n]
			#! (sis,symbols_a,marked_bool_a,count)
				= remove_garbage sis symbols_a marked_bool_a count;
			= (SymbolIndex module_n sis,symbols_a,marked_bool_a,count);

			= remove_garbage sis symbols_a marked_bool_a (inc count);
	where {
		remove_module :: !*{!Symbol} !*{#Bool} -> (*{!Symbol},!*{#Bool});
		remove_module symbols_a=:{[module_n] = module_symbol} marked_bool_a
			| is_empty_symbol module_symbol
				= (symbols_a,marked_bool_a);
			#! (n_relocations,relocations)
				= select module_symbol;
			#! symbols_a
				= { symbols_a & [module_n] = EmptySymbol };
			= (symbols_a,marked_bool_a);
		where {
			is_empty_symbol EmptySymbol
				= True;
			is_empty_symbol _
				= False;
		
			is_module_symbol :: !Int !*{!Symbol} -> (!Bool,!*{!Symbol});
			is_module_symbol symbol_n symbol_a=:{[symbol_n] = module_symbol}
				= (is_module module_symbol,symbol_a);
			where {
				is_module (Module _ _ _ _ n_relocations relocations _) 
					= True;
				is_module _ 
					= False;
			}
			
			remove_symbols :: !Int !Int !*{!Symbol} {#Char} !*{#Bool} -> (*{!Symbol},!*{#Bool});
			remove_symbols relocation_n n_relocations symbol_a relocations marked_bool_a
				| (relocation_n == n_relocations)
					= (symbol_a,marked_bool_a);
					
					#! (is_module,symbol_a)
						= is_module_symbol relocation_symbol_n symbol_a;
					| is_module
						= remove_symbols (inc relocation_n) n_relocations symbol_a relocations marked_bool_a;
					
						// no module
						#! (marked_symbol,marked_bool_a)
							= marked_bool_a![relocation_symbol_n];
						| marked_symbol
							= remove_symbols (inc relocation_n) n_relocations symbol_a relocations marked_bool_a;

							= remove_symbols (inc relocation_n) n_relocations symbol_a relocations marked_bool_a;
				
			where {
				relocation_symbol_n=relocations ILONG (relocation_index+4);
				relocation_index=relocation_n * SIZE_OF_RELOCATION;
			}
		}
	
	}
}