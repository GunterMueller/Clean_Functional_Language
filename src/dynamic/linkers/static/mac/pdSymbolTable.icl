implementation module pdSymbolTable;

instance toString Symbol
where {
	toString (Module _)
		= abort "toString(Symbol): Module";
	toString (Label _)
		= abort "toString(Symbol): Label"; 
	toString (ImportLabel _) 
		= abort "toString(Symbol): ImportLabel";
	toString (ImportedLabel _) 
		= abort "toString(Symbol): ImportedLabel";
	toString (AliasModule _)
		= abort "toString(Symbol): AliasModule";
	toString (ImportedLabelPlusOffset _)
		= abort "toString(Symbol): ImportedLabelPlusOffset";
	toString (ImportedFunctionDescriptor _)
		= abort "toString(Symbol): ImportedFunctionDescriptor";
	toString (ImportedFunctionDescriptorTocModule _)
		= abort "toString(Symbol): ImportedFunctionDescriptorTocModule";
	toString (EmptySymbol)
		= abort "toString(Symbol): EmptySymbol";
		
	
};
// macOS dependent
import StdString, StdInt, StdArray, StdClass, StdBool, StdEnum, StdFile, StdMisc;
import xcoff, ExtString;
//from linker2 import insert_exported_symbol_in_toc_table;

import NamesTable;
getModule_virtual_label_offset :: !Symbol -> !Int;
getModule_virtual_label_offset (Module {module_offset=virtual_module_offset})  = virtual_module_offset;


// Module {module_offset=virtual_module_offset}  
// ADDED
split_data_symbol_lists_without_removing_unmarked_symbols :: *Xcoff -> !*Xcoff;
split_data_symbol_lists_without_removing_unmarked_symbols  xcoff 
	= split_data_symbol_lists_of_files2 xcoff ;
	{
		split_data_symbol_lists_of_files2 ::  *Xcoff  -> !*Xcoff;
		split_data_symbol_lists_of_files2 xcoff=:{n_symbols,symbol_table,data_relocations,header={data_v_address}}  
			#	(toc_symbols1,data_symbols1,symbol_table1)
					= split_data_symbol_list2 symbol_table.data_symbols symbol_table.symbols  ;
			= (	{xcoff & symbol_table={symbol_table & toc_symbols=toc_symbols1,data_symbols=data_symbols1,symbols=symbol_table1 }}
		  	);
			{
				split_data_symbol_list2 :: SymbolIndexList *SymbolArray  -> (!SymbolIndexList,!SymbolIndexList,!*SymbolArray);
				split_data_symbol_list2 EmptySymbolIndex symbol_array0 
					= (EmptySymbolIndex,EmptySymbolIndex,symbol_array0);
				split_data_symbol_list2 (SymbolIndex module_n symbol_list) symbol_array0=:{[module_n]=module_symbol} 
						= case module_symbol of {
							Module {section_n=TOC_SECTION}
								#	(toc_symbols,data_symbols,symbol_array1)
										= split_data_symbol_list2 symbol_list symbol_array0 ;
								-> (SymbolIndex module_n toc_symbols,data_symbols,symbol_array1);
							Module {section_n=DATA_SECTION}
								#	(toc_symbols,data_symbols,symbol_array1)
										= split_data_symbol_list2 symbol_list symbol_array0 ;
								-> (toc_symbols,SymbolIndex module_n data_symbols,symbol_array1);
						}
			}
	}

symbol_get_offset :: !Symbol -> !Int;
symbol_get_offset (Module {module_offset})
	= module_offset;

fill_library_offsets :: LibraryList Int Int *{#Int} -> *{#Int};
fill_library_offsets EmptyLibraryList file_n offset offset_array
	= offset_array;
fill_library_offsets (Library  _ symbols n_symbols libraries) file_n offset offset_array
	= fill_library_offsets libraries (inc file_n) (offset+n_symbols) {offset_array & [file_n]=offset};
			
::	SymbolArray :== {!Symbol};

::	Symbol
	= Module !Module
	| Label !Label 
	| ImportLabel !String 
	| ImportedLabel !ImportedLabel 
	| AliasModule !AliasModule
	| ImportedLabelPlusOffset !ImportedLabelPlusOffset
	| ImportedFunctionDescriptor !ImportedLabel
	| ImportedFunctionDescriptorTocModule !ImportedFunctionDescriptorTocModule
	| EmptySymbol;
	
	

// Label
isLabel :: !Symbol -> !Bool;
isLabel (Label _) = True;
isLabel	_ = False;

getLabel_offset :: !Symbol -> !Int;
getLabel_offset (Label {label_offset=offset}) = offset;

getLabel_module_n :: !Symbol -> !Int;
getLabel_module_n (Label {label_module_n=module_n}) = module_n;

/*

	#! symbol = symbols_a.[file_n,symbol_n];
	= case symbol of {
		Label {label_offset=offset,label_module_n=module_n}
			#! symbol = symbols_a.[file_n,module_n];
			-> case symbol of {
				Module {module_offset=virtual_module_offset}
					-> module_offset_a.[marked_offset_a0.[file_n]+module_n]+offset-virtual_module_offset;
		}
	};
*/

// Module
isModule :: !Symbol -> !Bool;
isModule (Module _) = True;
isModule _ 	= False;

/*
	::	ImportedLabel = {
			implab_file_n			::!Int,
			implab_symbol_n			::!Int
		};
*/

CreateImportedLabel :: !Int !Int -> !Symbol;
CreateImportedLabel file_n symbol_n
	#! imported_label
		= { ImportedLabel |
			implab_file_n		= file_n
		,	implab_symbol_n		= symbol_n
		};
	= ImportedLabel imported_label;
	
	::	Module = {
			section_n				::!Int,
			module_offset			::!Int,
			length					::!Int,
			first_relocation_n		::!Int,
			end_relocation_n		::!Int,
			align					::!Int
		};
	::	Label = {
	 		label_section_n			::!Int,
			label_offset			::!Int,
			label_module_n			::!Int
		};
	::	ImportedLabel = {
			implab_file_n			::!Int,
			implab_symbol_n			::!Int
		};
	::	AliasModule = {
			alias_module_offset		::!Int,
			alias_first_relocation_n::!Int,
			alias_global_module_n	::!Int
		};
	::	ImportedLabelPlusOffset = {
			implaboffs_file_n		::!Int,
			implaboffs_symbol_n		::!Int,
			implaboffs_offset		::!Int
		};
	::	ImportedFunctionDescriptorTocModule = {
			imptoc_offset			::!Int,
			imptoc_file_n			::!Int,
			imptoc_symbol_n			::!Int			
		};

::	SymbolIndexList = SymbolIndex !Int !SymbolIndexList | EmptySymbolIndex;

/*111
::	NamesTable :== {!NamesTableElement};

::	NamesTableElement
	= NamesTableElement !String !Int !Int !NamesTableElement	// symbol_name symbol_n file_n symbol_list
	| EmptyNamesTableElement;
*/

::	LibraryList = Library !String !LibrarySymbolsList !Int !LibraryList | EmptyLibraryList;

::	LibrarySymbolsList = LibrarySymbol !String !LibrarySymbolsList | EmptyLibrarySymbolsList;


/*
::	LibraryList = Library !String !Int !LibrarySymbolsList !Int !LibraryList | EmptyLibraryList;

::	LibrarySymbolsList = LibrarySymbol !String !LibrarySymbolsList | EmptyLibrarySymbolsList;
*/

:: Xcoff ={
		module_name 		:: !String
	,	header				:: !XcoffHeader
	,	symbol_table		:: !.SymbolTable
	,	text_relocations	:: !String
	,	data_relocations	:: !String
	,	n_text_relocations	:: !Int
	,	n_data_relocations	:: !Int
	,	n_symbols			:: !Int
	};

// accessors
get_text_relocations	:== (\xcoff=:{text_relocations} -> (text_relocations,xcoff));
get_data_relocations	:== (\xcoff=:{data_relocations} -> (data_relocations,xcoff));
get_header				:== (\xcoff=:{header}			-> (header,xcoff));	
get_n_symbols			:== (\xcoff=:{n_symbols}		-> (n_symbols,xcoff));
get_text_v_address		:== (\xcoff=:{header={text_v_address}} -> (text_v_address,xcoff));
get_data_v_address		:== (\xcoff=:{header={data_v_address}} -> (data_v_address,xcoff));
get_toc0_symbols		:== (\symbol_table=:{toc0_symbol} -> (toc0_symbol,symbol_table));
get_toc_symbols			:== (\symbol_table=:{toc_symbols} -> (toc_symbols,symbol_table));	

::	XcoffHeader ={
		file_name			:: !String,
		text_section_offset	:: !Int,
		text_section_size	:: !Int,
		data_section_offset	:: !Int,
		data_section_size	:: !Int,
		text_v_address		:: !Int,
		data_v_address		:: !Int
	};

::	SymbolTable ={
		text_symbols	:: !SymbolIndexList,
		data_symbols	:: !SymbolIndexList,
		toc_symbols		:: !SymbolIndexList,
		bss_symbols		:: !SymbolIndexList,
		toc0_symbol		:: !SymbolIndexList,
		imported_symbols:: !SymbolIndexList,
		symbols			:: !.SymbolArray
	};

::	LoaderRelocations
	= CodeRelocation !Int !.LoaderRelocations
	| DataRelocation !Int !.LoaderRelocations
	| DeltaRelocation !Int !.LoaderRelocations
	| DeltaDataRelocation !Int !Int !.LoaderRelocations
	| ImportedSymbolsRelocation !Int !.LoaderRelocations
	| EmptyRelocation;

:: SymbolsArray :== {!.SymbolArray};

:: *Sections = Sections !*String !*String !Sections | EndSections;

::	TocTable = Toc !TocElem !.TocTable !.TocTable | EmptyTocTable;
::	TocElem = {global_module_n::!Int,symbol_n::!Int,offset::!Int};

/*
n_symbols_of_xcoff_list :: !Int ![Xcoff] -> Int;
n_symbols_of_xcoff_list n_symbols0 []
	= n_symbols0;
n_symbols_of_xcoff_list n_symbols0 [{n_symbols}:xcoff_list0]
	= n_symbols_of_xcoff_list (n_symbols0+n_symbols) xcoff_list0;
*/

/*
implementation module pcSortSymbols;

::	SortArray :== {#SortElement};
::	SortElement = { index::!Int, offset::!Int };
*/

/*
sort_symbols :: !SymbolIndexList !*SymbolArray -> (!SymbolIndexList,!*SymbolArray);
sort_symbols symbols symbol_array0
	=	(array_to_list sorted_array 0,symbol_array1);
	{
		sorted_array=heap_sort array;
		(array,symbol_array1)=fill_array new_array 0 symbols symbol_array0;
		new_array=createArray n_elements {index=0,offset=0};
		n_elements=length_of_symbol_index_list symbols 0;
		
		fill_array :: *SortArray Int SymbolIndexList *SymbolArray -> (!*SortArray,!*SymbolArray);
		fill_array a i EmptySymbolIndex symbol_array
			= (a,symbol_array);
		fill_array a i (SymbolIndex index l) symbol_array=:{[index]=m}
			= c a i m symbol_array;
			{
				c :: *SortArray Int Symbol *SymbolArray -> (!*SortArray,!*SymbolArray);
				c a i (Module {module_offset}) symbol_array
					= fill_array {a & [i]={index=index,offset=module_offset}} (inc i) l symbol_array;
			};
		
		array_to_list :: SortArray Int -> SymbolIndexList;
		array_to_list a i
			| i<n_elements
				= SymbolIndex a.[i].index (array_to_list a (inc i));
				= EmptySymbolIndex;
			
		heap_sort :: *SortArray -> *SortArray;
		heap_sort a
			| n_elements<2
				=	a
				=	sort_heap max_index (init_heap (n_elements>>1) a);
				{
					sort_heap :: Int *SortArray -> *SortArray;
					sort_heap i a=:{[i]=a_i,[0]=a_0}
						| i==1
							= { a & [0]=a_i,[i]=a_0}; 
							= sort_heap deci (add_element_to_heap {a & [i]=a_0} a_i 0 deci);{
								deci=dec i;
							}
				
					init_heap :: Int *SortArray -> *SortArray;
					init_heap i a0
						| i>=0
							= init_heap (dec i) (add_element_to_heap1 a0 i max_index); {
								add_element_to_heap1 :: *SortArray Int Int -> *SortArray;
								add_element_to_heap1 a=:{[i]=ir} i max_index
									= add_element_to_heap a ir i max_index;
							}
							= a0;
					
					max_index=dec n_elements;
				}
		
		add_element_to_heap :: *SortArray SortElement Int Int -> *SortArray;
		add_element_to_heap a ir i max_index
			= heap_sort_lp a i (inc (i+i)) max_index ir;
		{
			heap_sort_lp :: *SortArray Int Int Int SortElement-> *SortArray;
			heap_sort_lp a i j max_index ir
				| j<max_index
					= heap_sort1 a i j max_index ir;
				{
					heap_sort1 :: !*SortArray !Int !Int !Int !SortElement -> *SortArray;
					heap_sort1 a=:{[j]=a_j,[j1]=a_j_1} i j max_index ir
						= heap_sort1 a_j a_j_1 a i j max_index ir;
					{
						heap_sort1 :: !SortElement !SortElement !*SortArray !Int !Int !Int !SortElement -> *SortArray;
						heap_sort1 a_j a_j_1 a i j max_index ir
						| a_j.SortElement.offset < a_j_1.SortElement.offset
							= heap_sort2 a i (inc j) max_index ir;
							= heap_sort2 a i j max_index ir;

						j1=inc j;
					}
				}
				| j>max_index
					= {a & [i] = ir};
				// j==max_index
					= heap_sort2 a i j max_index ir;
				{}{
					heap_sort2 a=:{[j]=a_j} i j max_index ir
						= heap_sort2 a_j a i j max_index ir;
					{
						heap_sort2 :: SortElement *SortArray !Int !Int !Int SortElement-> *SortArray;
						heap_sort2 a_j a i j max_index ir
						| ir.SortElement.offset<a_j.SortElement.offset
							= heap_sort_lp {a & [i] = a_j} j (inc (j+j)) max_index ir;
			   				= {a & [i] = ir};
			   		}
				}
		}
	}

length_of_symbol_index_list EmptySymbolIndex length
	= length;
length_of_symbol_index_list (SymbolIndex _ l) length
	= length_of_symbol_index_list l (inc length);

symbols_are_sorted :: SymbolIndexList {!Symbol} -> Bool;
symbols_are_sorted EmptySymbolIndex symbol_array
	= True;
symbols_are_sorted (SymbolIndex i1 l) symbol_array
	=	sorted_symbols2 i1 l symbol_array;
	{
		sorted_symbols2 :: Int SymbolIndexList {!Symbol} -> Bool;
		sorted_symbols2 i1 EmptySymbolIndex symbol_array
			= True;
		sorted_symbols2 i1 (SymbolIndex i2 l) symbol_array
			= symbol_index_less_or_equal i1 i2 symbol_array && sorted_symbols2 i2 l symbol_array;
	}

reverse_and_sort_symbols :: !SymbolIndexList !*SymbolArray -> (!SymbolIndexList,!*SymbolArray);
reverse_and_sort_symbols symbols symbol_array
	| symbols_are_sorted reversed_symbols symbol_array
		= (reversed_symbols,symbol_array);
		= sort_symbols reversed_symbols symbol_array;
//	| symbols_are_sorted sorted_symbols symbol_array1
//		= (sorted_symbols,symbol_array1);
	{}{
//		(sorted_symbols,symbol_array1) = sort_symbols reversed_symbols symbol_array;
		reversed_symbols=reverse_symbols symbols;
	}

reverse_symbols :: !SymbolIndexList -> SymbolIndexList;
reverse_symbols l = reverse_symbols l EmptySymbolIndex;
{
	reverse_symbols EmptySymbolIndex t = t;
	reverse_symbols (SymbolIndex i l) t = reverse_symbols l (SymbolIndex i t);
}
*/

/* NOT SHARED:
	symbol_index_less_or_equal :: Int Int {!Symbol} -> Bool;
	symbol_index_less_or_equal i1 i2 {[i1]=m1,[i2]=m2}
		= case (m1,m2) of {
			(Module {module_offset=offset1},Module {module_offset=offset2})
				-> offset1<=offset2; 
		}

sort_modules :: !*Xcoff -> .Xcoff;
sort_modules xcoff=:{symbol_table}
	= { xcoff & symbol_table = 
		{ symbol_table &
			text_symbols=text_symbols1,
			data_symbols=data_symbols1,
			bss_symbols=bss_symbols1,
			symbols=symbols3
		}
	  };
	{
		(text_symbols1,symbols1)=reverse_and_sort_symbols text_symbols symbols0;
		(data_symbols1,symbols2)=reverse_and_sort_symbols data_symbols symbols1;
		(bss_symbols1,symbols3)=reverse_and_sort_symbols bss_symbols symbols2;
		
//		{symbol_table} = xcoff;
		{text_symbols,data_symbols,bss_symbols,symbols=symbols0} = symbol_table;
	}
*/

empty_xcoff ::.Xcoff;
empty_xcoff
	= {
		module_name = "", header=header,symbol_table=empty_symbol_table,n_symbols=0,
		text_relocations="",data_relocations="",n_text_relocations=0,n_data_relocations=0
	};
	{
		header={
			file_name="",text_section_offset=0,data_section_offset=0,text_section_size=0,data_section_size=0,text_v_address=0,data_v_address=0
		};
		empty_symbol_table = {	
			text_symbols=EmptySymbolIndex,data_symbols=EmptySymbolIndex,toc_symbols=EmptySymbolIndex,bss_symbols=EmptySymbolIndex,
			toc0_symbol=EmptySymbolIndex,imported_symbols=EmptySymbolIndex,symbols=createArray 0 EmptySymbol
		};
	}
	
:: UndefinedSymbol :== ({#Char},Int,Int);

import_symbols_in_xcoff_files :: !*[*Xcoff] !Int [({#Char},Int,Int)] !*{!NamesTableElement} -> (![({#Char},Int,Int)],![.Xcoff],!.{!NamesTableElement});
import_symbols_in_xcoff_files [] xcoff_n undefined_symbols names_table0
	= (undefined_symbols,[],names_table0);
import_symbols_in_xcoff_files [xcoff0:xcoff_list0] xcoff_n undefined_symbols0 names_table0
	# (undefined_symbols1,xcoff1,names_table1)		= import_symbols_in_xcoff_file undefined_symbols0 xcoff0 names_table0;
	# (undefined_symbols2,xcoff_list1,names_table2)	= import_symbols_in_xcoff_files xcoff_list0 (xcoff_n+1) undefined_symbols1 names_table1;
	= (undefined_symbols2,[xcoff1:xcoff_list1],names_table2);
{
	import_symbols_in_xcoff_file :: [UndefinedSymbol] *Xcoff *NamesTable -> ([UndefinedSymbol],!*Xcoff,!*NamesTable);
	import_symbols_in_xcoff_file undefined_symbols xcoff0=:{symbol_table=symbol_table=:{imported_symbols,symbols}} names_table
		# (undefined_symbols,symbols,names_table) = import_symbols imported_symbols undefined_symbols symbols names_table;
		= (undefined_symbols,{xcoff0 & symbol_table = {symbol_table & symbols=symbols,imported_symbols=EmptySymbolIndex}},names_table);

		import_symbols :: SymbolIndexList [UndefinedSymbol] *SymbolArray *NamesTable -> ([UndefinedSymbol],!*SymbolArray,!*NamesTable);
		import_symbols EmptySymbolIndex undefined_symbols symbol_table0 names_table0
			= (undefined_symbols,symbol_table0,names_table0);
		import_symbols (SymbolIndex index symbol_index_list) undefined_symbols symbol_table0=:{[index]=symbol} names_table0
			= case symbol of {
				ImportLabel label_name
					#  (names_table_element,names_table1) = find_symbol_in_symbol_table label_name names_table0;
					-> case names_table_element of {
						NamesTableElement symbol_name symbol_n file_n symbol_list
							#  symbol_table1 = {symbol_table0 & [index] = ImportedLabel {implab_file_n=file_n,implab_symbol_n=symbol_n}};
							-> import_symbols symbol_index_list undefined_symbols symbol_table1 names_table1;
						EmptyNamesTableElement
							# (names_table_element2,names_table2) = find_symbol_in_symbol_table ("."+++label_name) names_table1;
							-> case names_table_element2 of {
									NamesTableElement _ symbol_n file_n _
										| file_n<0
											# symbol_table1 = {symbol_table0 & [index] = 
																ImportedFunctionDescriptor {implab_file_n=file_n,implab_symbol_n=symbol_n}};
											-> import_symbols symbol_index_list undefined_symbols symbol_table1 names_table2;
									_
										-> import_symbols symbol_index_list [(label_name,xcoff_n,index):undefined_symbols] symbol_table0 names_table2;
								}
//								-> import_symbols symbol_index_list [(label_name,xcoff_n,index):undefined_symbols] symbol_table0 names_table1;
//								->	abort ("undefined symbol "+++label_name);
						}
			}
	}

//PRINT_INT i | not error = True; {}{ (error,_)=ferror (fwritec ' ' (fwritei i stderr)); }
//PRINT_STRING_INT s i | not error = True; {}{ (error,_)=ferror (fwritec ' ' (fwritei i (fwrites s stderr))); }

mark_used_modules :: !Int !Int ![String] !{#Bool} !*{#Bool} !*{#Int} !*{#*Xcoff} -> (![String],!*{#Int}, !*{#Bool},!*{#*Xcoff});
mark_used_modules main_symbol_n main_file_n undefined_symbols already_marked_bool marked_bool_a0 marked_offset_a xcoff_a
	= mark_used_module main_file_n main_symbol_n undefined_symbols marked_offset_a xcoff_a marked_bool_a0;
{
	mark_used_module :: !Int !Int ![String] !*{#Int} !*{#*Xcoff} !*{#Bool} -> (![String],!*{#Int},!*{#Bool},!*{#*Xcoff});
	mark_used_module file_n symbol_n undefined_symbols marked_offset_a xcoff_a marked_bool_a0		
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
				
			
		# (first_symbol_n, marked_offset_a) 
			= marked_offset_a![file_n];
		# bool_offset
			=first_symbol_n + symbol_n;
		| marked_bool_a0.[bool_offset] || already_marked_bool.[bool_offset]
			= (undefined_symbols,marked_offset_a,marked_bool_a0,xcoff_a);
			
			# marked_bool_a1 = {marked_bool_a0 & [bool_offset]=True};
			# marked_bool_a = marked_bool_a1;
			
			//#! symbol = xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
			#! (symbol,xcoff_a) = xcoff_a![file_n].symbol_table.symbols.[symbol_n];
			= case symbol of {
			
				Module {section_n,first_relocation_n,end_relocation_n}
					| first_relocation_n==end_relocation_n
						-> (undefined_symbols,marked_offset_a,marked_bool_a,xcoff_a);
					| section_n==TEXT_SECTION
						#! text_relocations = xcoff_a.[file_n].text_relocations;
//						# (text_relocations,xcoff_a) = xcoff_a![file_n].text_relocations;
						-> mark_relocations_module first_relocation_n marked_offset_a text_relocations undefined_symbols marked_bool_a xcoff_a;
					| section_n==DATA_SECTION || section_n==TOC_SECTION
						#! data_relocations = xcoff_a.[file_n].data_relocations;
//						# (data_relocations,xcoff_a) = xcoff_a![file_n].data_relocations;
						-> mark_relocations_module first_relocation_n marked_offset_a data_relocations undefined_symbols marked_bool_a xcoff_a;
					| section_n==BSS_SECTION
						-> (undefined_symbols,marked_offset_a,marked_bool_a,xcoff_a);
					{}{
						mark_relocations_module relocation_n marked_offset_a relocation_string undefined_symbols marked_bool_a xcoff_a
							| relocation_n==end_relocation_n
								= (undefined_symbols,marked_offset_a,marked_bool_a,xcoff_a);
								# relocation_symbol_n=relocation_string LONG (relocation_n*SIZE_OF_RELOCATION+4);
								  relocation_symbol_n_2=(inc relocation_symbol_n) >> 1;
								  (undefined_symbols,marked_offset_a,marked_bool_a,xcoff_a)= mark_used_module file_n relocation_symbol_n_2 undefined_symbols marked_offset_a xcoff_a marked_bool_a ;
								= mark_relocations_module (inc relocation_n) marked_offset_a relocation_string undefined_symbols marked_bool_a xcoff_a;
					}
			
				Label {label_section_n=section_n,label_module_n=module_n}
					-> mark_used_module file_n module_n undefined_symbols marked_offset_a xcoff_a marked_bool_a;
			
				ImportedLabel {implab_file_n=symbol_file_n,implab_symbol_n=imported_symbol_n}
					| symbol_file_n<0
						-> mark_used_module symbol_file_n imported_symbol_n undefined_symbols marked_offset_a xcoff_a marked_bool_a ;
						#  xcoff_a=replace_imported_label_symbol xcoff_a file_n symbol_n symbol_file_n imported_symbol_n;
						-> mark_used_module symbol_file_n imported_symbol_n undefined_symbols marked_offset_a xcoff_a marked_bool_a ;

				ImportedLabelPlusOffset {implaboffs_file_n=symbol_file_n,implaboffs_symbol_n=imported_symbol_n}
					-> mark_used_module symbol_file_n imported_symbol_n undefined_symbols marked_offset_a xcoff_a marked_bool_a ;

				ImportLabel label_name
					-> ([label_name : undefined_symbols],marked_offset_a,marked_bool_a,xcoff_a);

				ImportedFunctionDescriptor {implab_file_n=symbol_file_n,implab_symbol_n=imported_symbol_n}
					->	mark_used_module symbol_file_n imported_symbol_n undefined_symbols marked_offset_a xcoff_a marked_bool_a ;

				_
					-> abort ("file "+++toString file_n+++" symbol "+++toString symbol_n);
			}
		
		{}{
			replace_imported_label_symbol :: *{#*Xcoff} Int Int Int Int -> *{#*Xcoff};
			replace_imported_label_symbol xcoff_a file_n symbol_n symbol_file_n imported_symbol_n
				#! label_symbol=xcoff_a.[symbol_file_n].symbol_table.symbols.[imported_symbol_n];
//				# (label_symbol,xcoff_a) = xcoff_a![symbol_file_n].symbol_table.symbols.[imported_symbol_n];				
				=  case label_symbol of {
					Label {label_offset=v_label_offset,label_module_n=module_n}
						#! module_symbol=xcoff_a.[symbol_file_n].symbol_table.symbols.[module_n];
//						# (module_symbol,xcoff_a) = xcoff_a![symbol_file_n].symbol_table.symbols.[module_n];

						-> case module_symbol of {
							Module {module_offset=v_module_offset}
								-> {xcoff_a & [file_n].symbol_table.symbols.[symbol_n]=
									(ImportedLabelPlusOffset {
										implaboffs_file_n=symbol_file_n,
										implaboffs_symbol_n=module_n,
										implaboffs_offset=v_label_offset-v_module_offset})
//										);
										};
							_
								-> xcoff_a;
						   }
					_
						-> xcoff_a
				  }

		} // mark_used_module
} // mark_used_modules

/*
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
			#! symbol = xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
//			# (symbol,xcoff_a) = xcoff_a![file_n].symbol_table.symbols.[symbol_n];
			=  case (symbol) of {
				Module {section_n,first_relocation_n,end_relocation_n}
					| first_relocation_n==end_relocation_n
						-> (undefined_symbols,marked_bool_a,xcoff_a);
					| section_n==TEXT_SECTION
						#! text_relocations = xcoff_a.[file_n].text_relocations;
//						# (text_relocations,xcoff_a) = xcoff_a![file_n].text_relocations;
						-> mark_relocations_module first_relocation_n text_relocations undefined_symbols marked_bool_a xcoff_a;
					| section_n==DATA_SECTION || section_n==TOC_SECTION
						#! data_relocations = xcoff_a.[file_n].data_relocations;
//						# (data_relocations,xcoff_a) = xcoff_a![file_n].data_relocations;
						-> mark_relocations_module first_relocation_n data_relocations undefined_symbols marked_bool_a xcoff_a;
					| section_n==BSS_SECTION
						-> (undefined_symbols,marked_bool_a,xcoff_a);
					{}{
						mark_relocations_module relocation_n relocation_string undefined_symbols marked_bool_a xcoff_a
							| relocation_n==end_relocation_n
								= (undefined_symbols,marked_bool_a,xcoff_a);
								# relocation_symbol_n=relocation_string LONG (relocation_n*SIZE_OF_RELOCATION+4);
								  relocation_symbol_n_2=(inc relocation_symbol_n) >> 1;
								  (undefined_symbols,marked_bool_a,xcoff_a)= mark_used_module file_n relocation_symbol_n_2 undefined_symbols marked_bool_a xcoff_a;
								= mark_relocations_module (inc relocation_n) relocation_string undefined_symbols marked_bool_a xcoff_a;
					}
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
			}
		{}{
			replace_imported_label_symbol :: *{#*Xcoff} Int Int Int Int -> *{#*Xcoff};
			replace_imported_label_symbol xcoff_a file_n symbol_n symbol_file_n imported_symbol_n
				#! label_symbol=xcoff_a.[symbol_file_n].symbol_table.symbols.[imported_symbol_n];
//				# (label_symbol,xcoff_a) = xcoff_a![symbol_file_n].symbol_table.symbols.[imported_symbol_n];				
				=  case label_symbol of {
					Label {label_offset=v_label_offset,label_module_n=module_n}
						#! module_symbol=xcoff_a.[symbol_file_n].symbol_table.symbols.[module_n];
//						# (module_symbol,xcoff_a) = xcoff_a![symbol_file_n].symbol_table.symbols.[module_n];

						-> case module_symbol of {
							Module {module_offset=v_module_offset}
								-> {xcoff_a & [file_n].symbol_table.symbols.[symbol_n]=
									(ImportedLabelPlusOffset {
										implaboffs_file_n=symbol_file_n,
										implaboffs_symbol_n=module_n,
										implaboffs_offset=v_label_offset-v_module_offset})
//										);
										};
							_
								-> xcoff_a;
						   }
					_
						-> xcoff_a
				  }
		}
}

*/
/*
SYMBOL_TABLE_SIZE:==4096;
SYMBOL_TABLE_SIZE_MASK:==4095;

create_names_table :: *NamesTable;
create_names_table = createArray SYMBOL_TABLE_SIZE EmptyNamesTableElement;

insert_symbol_in_symbol_table :: !String Int Int !*NamesTable -> *NamesTable;
insert_symbol_in_symbol_table symbol_name symbol_n file_n names_table=:{[symbol_hash]=symbol_list}
	| symbol_in_symbol_table_list symbol_list
		= names_table;
		= { names_table & [symbol_hash] = NamesTableElement symbol_name symbol_n file_n symbol_list};
	{}{
		symbol_hash=symbol_name_hash symbol_name;
		
		symbol_in_symbol_table_list EmptyNamesTableElement
			= False;
		symbol_in_symbol_table_list (NamesTableElement string  _ _ symbol_table_list)
			| string==symbol_name
				= True;
				= symbol_in_symbol_table_list symbol_table_list;
	}

find_symbol_in_symbol_table :: !String !*NamesTable -> (!NamesTableElement,!*NamesTable);
find_symbol_in_symbol_table symbol_name names_table=:{[symbol_hash]=symbol_list}
	=	(symbol_in_symbol_table_list symbol_list,names_table);
	{
		symbol_hash=symbol_name_hash symbol_name;
		
		symbol_in_symbol_table_list EmptyNamesTableElement
			= EmptyNamesTableElement;
		symbol_in_symbol_table_list names_table_element=:(NamesTableElement string _ _ symbol_table_list)
			| string==symbol_name
				= names_table_element;
				= symbol_in_symbol_table_list symbol_table_list;
	}

	symbol_name_hash symbol_name = (simple_hash symbol_name 0 0) bitand SYMBOL_TABLE_SIZE_MASK;
	{
		simple_hash string index value
			| index== size string
				= value;
				= simple_hash string (inc index) (((value<<2) bitxor (value>>10)) bitxor (string BYTE index));
	}
*/

xcoff_list_to_symbols_array :: !.Int ![.Xcoff] -> {!{!Symbol}};
xcoff_list_to_symbols_array n_xcoff_files xcoff_list
	= fill_array 0 xcoff_list (createArray n_xcoff_files (createArray 0 EmptySymbol));
{		
	fill_array file_n [] symbols_a
		= symbols_a;
	fill_array file_n [xcoff=:{symbol_table={symbols}}:xcoff_list] symbols_a
		= fill_array (inc file_n) xcoff_list {symbols_a & [file_n]=symbols};
}

xcoff_array_to_list :: Int *{#*Xcoff} -> [*Xcoff];
xcoff_array_to_list i a0
	| i >= size a0
		= [];
		# (a_i,a2)=replace a0 i empty_xcoff;
		= [a_i : xcoff_array_to_list (inc i) a2];
		
/*
split_data_symbol_lists_without_removing_unmarked_symbols :: *Xcoff -> !*Xcoff;
split_data_symbol_lists_without_removing_unmarked_symbols  xcoff 
	= split_data_symbol_lists_of_files2 xcoff ;
	{
		split_data_symbol_lists_of_files2 ::  *Xcoff  -> !*Xcoff;
		split_data_symbol_lists_of_files2 xcoff=:{n_symbols,symbol_table,data_relocations,header={data_v_address}}  
			#	(toc_symbols1,data_symbols1,symbol_table1)
					= split_data_symbol_list2 symbol_table.data_symbols symbol_table.symbols  ;
			= (	{xcoff & symbol_table={symbol_table & toc_symbols=toc_symbols1,data_symbols=data_symbols1,symbols=symbol_table1 }}
		  	);
			{
				split_data_symbol_list2 :: SymbolIndexList *SymbolArray  -> (!SymbolIndexList,!SymbolIndexList,!*SymbolArray);
				split_data_symbol_list2 EmptySymbolIndex symbol_array0 
					= (EmptySymbolIndex,EmptySymbolIndex,symbol_array0);
				split_data_symbol_list2 (SymbolIndex module_n symbol_list) symbol_array0=:{[module_n]=module_symbol} 
						= case module_symbol of {
							Module {section_n=TOC_SECTION}
								#	(toc_symbols,data_symbols,symbol_array1)
										= split_data_symbol_list2 symbol_list symbol_array0 ;
								-> (SymbolIndex module_n toc_symbols,data_symbols,symbol_array1);
							Module {section_n=DATA_SECTION}
								#	(toc_symbols,data_symbols,symbol_array1)
										= split_data_symbol_list2 symbol_list symbol_array0 ;
								-> (toc_symbols,SymbolIndex module_n data_symbols,symbol_array1);
						}
			}
	}
*/
split_data_symbol_lists_of_files2 :: *{#Int} *{#Bool} Sections [*Xcoff] *TocTable -> (!Sections,![*Xcoff],!*TocTable,*{#Int},*{#Bool});
split_data_symbol_lists_of_files2 offset_a marked_bool_a sections xcoff_list toc_table0
	= split_data_symbol_lists_of_files2 0 sections xcoff_list toc_table0 offset_a marked_bool_a;
	{
		split_data_symbol_lists_of_files2 :: Int Sections [*Xcoff] *TocTable *{#Int} *{#Bool} -> (!Sections,![*Xcoff],!*TocTable,*{#Int},*{#Bool});
		split_data_symbol_lists_of_files2 file_symbol_index EndSections [] toc_table0 offset_a marked_bool_a
			= (EndSections,[],toc_table0,offset_a,marked_bool_a);
		split_data_symbol_lists_of_files2 file_symbol_index (Sections text_section data_section0 sections0) [xcoff=:{n_symbols,symbol_table,data_relocations,header={data_v_address}}:xcoff_list0] toc_table0 offset_a marked_bool_a 
			#	(toc_symbols1,data_symbols1,symbol_table1,data_section1,toc_table1,offset_a,marked_bool_a)
					= split_data_symbol_list2 symbol_table.data_symbols symbol_table.symbols data_section0 toc_table0 offset_a marked_bool_a;

				(sections1,xcoff_list1,toc_table2,offset_a,marked_bool_a)
					= split_data_symbol_lists_of_files2 (file_symbol_index+n_symbols) sections0 xcoff_list0 toc_table1 offset_a marked_bool_a;


				(symbol_table2,marked_bool_a) 
					= case symbol_table.toc0_symbol of {
						SymbolIndex toc0_index EmptySymbolIndex
							# (symbol_table2,marked_bool_a)
								= remove_unmarked_symbols 0 toc0_index file_symbol_index marked_bool_a symbol_table1
							-> remove_unmarked_symbols (inc toc0_index) n_symbols file_symbol_index marked_bool_a symbol_table2;
						EmptySymbolIndex
							-> remove_unmarked_symbols 0 n_symbols file_symbol_index marked_bool_a symbol_table1;
					}
			= (	Sections text_section data_section1 sections1,
				[ {xcoff & symbol_table={symbol_table & toc_symbols=toc_symbols1,data_symbols=data_symbols1,symbols=symbol_table2 }} : xcoff_list1],
				toc_table2,
				offset_a,
				marked_bool_a
			  	);
		{
			split_data_symbol_list2 :: SymbolIndexList *SymbolArray *String *TocTable *{#Int} *{#Bool} -> (!SymbolIndexList,!SymbolIndexList,!*SymbolArray,!*String,!*TocTable,*{#Int},*{#Bool});
			split_data_symbol_list2 EmptySymbolIndex symbol_array0 data_section0 toc_table0 offset_a marked_bool_a
				= (EmptySymbolIndex,EmptySymbolIndex,symbol_array0,data_section0,toc_table0,offset_a,marked_bool_a);

			split_data_symbol_list2 (SymbolIndex module_n symbol_list) symbol_array0=:{[module_n]=module_symbol} data_section0 toc_table0 offset_a marked_bool_a
				| not marked_bool_a.[file_symbol_index+module_n]
					= split_data_symbol_list2 symbol_list symbol_array0 data_section0 toc_table0 offset_a marked_bool_a;

					= case module_symbol of {
/*
// BEGIN KAN WEG
						Module {section_n=TOC_SECTION,module_offset=virtual_module_offset,length=4,first_relocation_n,end_relocation_n}
							| first_relocation_n+1==end_relocation_n && relocation_type==R_POS && relocation_size==0x1f
								-> (SymbolIndex module_n toc_symbols,data_symbols,symbol_array2,data_section2,toc_table2,offset_a2,marked_bool_a2);
								{
								(toc_symbols,data_symbols,symbol_array2,data_section2,toc_table2,offset_a2,marked_bool_a2)
									= split_data_symbol_list2 symbol_list symbol_array1 data_section1 toc_table1 offset_a1 marked_bool_a;
								(symbol_array1,toc_table1,offset_a1)
									= insert_exported_symbol_in_toc_table file_symbol_index module_n virtual_module_offset first_relocation_n
																relocation_symbol_n relocation_symbol_offset symbol_array0 offset_a toc_table0; 
									
								
								}
							{
								relocation_type=data_relocations BYTE (relocation_index+9);
								relocation_size=data_relocations BYTE (relocation_index+8);
								relocation_symbol_n=(inc (data_relocations LONG (relocation_index+4))) >> 1;
								//relocation_offset=data_relocations LONG relocation_index;
	
								relocation_index=first_relocation_n * SIZE_OF_RELOCATION;					
		
								(relocation_symbol_offset,data_section1) = read_long data_section0 (virtual_module_offset-data_v_address);	
							}
// END KAN WEG
*/
						Module {section_n=TOC_SECTION}
							#	(toc_symbols,data_symbols,symbol_array1,data_section1,toc_table1,offset_a,marked_bool_a)
									= split_data_symbol_list2 symbol_list symbol_array0 data_section0 toc_table0 offset_a marked_bool_a;
							-> (SymbolIndex module_n toc_symbols,data_symbols,symbol_array1,data_section1,toc_table1,offset_a,marked_bool_a);
						Module {section_n=DATA_SECTION}
							#	(toc_symbols,data_symbols,symbol_array1,data_section1,toc_table1,offset_a,marked_bool_a)
									= split_data_symbol_list2 symbol_list symbol_array0 data_section0 toc_table0 offset_a marked_bool_a;
							-> (toc_symbols,SymbolIndex module_n data_symbols,symbol_array1,data_section1,toc_table1,offset_a,marked_bool_a);

					}

			
				remove_unmarked_symbols :: !Int !Int !Int !*{#Bool} !*SymbolArray -> (*SymbolArray,!*{#Bool});
				remove_unmarked_symbols index n_symbols first_symbol_index marked_bool_a symbols
					| index>=n_symbols
						= (symbols,marked_bool_a);
					| marked_bool_a.[first_symbol_index+index]
						= remove_unmarked_symbols (inc index) n_symbols first_symbol_index marked_bool_a symbols;
					# (symbol,symbols) = uselect symbols index;
					= case symbol of {
						Module {section_n=TOC_SECTION,module_offset=virtual_module_offset,length=4,first_relocation_n,end_relocation_n}
							| first_relocation_n+1==end_relocation_n
								-> remove_unmarked_symbols (inc index) n_symbols first_symbol_index marked_bool_a symbols;
						_
							-> remove_unmarked_symbols (inc index) n_symbols first_symbol_index marked_bool_a { symbols & [index]=EmptySymbol };
					}
		}
	}

	
	
	
::	SymbolAndFileN = { symbol_n::!Int, file_n::!Int };

/*
find_root_symbols :: *NamesTable -> (!Bool,!SymbolAndFileN,!*NamesTable);
find_root_symbols names_table
	# (main_names_table_element,names_table)=find_symbol_in_symbol_table "main" names_table;
	= case main_names_table_element of {
		(NamesTableElement _ symbol_n file_n _)
			-> (True,{symbol_n=symbol_n,file_n=file_n},names_table);
		_
			-> (False,{symbol_n=0,file_n=0},names_table);
	}
*/

/*
mark_modules :: !SymbolAndFileN !*[*Xcoff] !Int !Int !Int !LibraryList -> (![String],!Int,!{#Bool},!{#Int},!*{#*Xcoff});
mark_modules {symbol_n=main_symbol_n,file_n=main_file_n} xcoff_list n_xcoff_files n_libraries n_library_symbols library_list
//	# (n_xcoff_symbols,xcoff_list)				= n_symbols_of_xcoff_list 0 xcoff_list;
	#! n_xcoff_symbols							= n_symbols_of_xcoff_list 0 xcoff_list;
	# (marked_bool_a,marked_offset_a,xcoff_a)	= create_xcoff_mark_and_offset_arrays n_xcoff_files n_xcoff_symbols n_libraries n_library_symbols
																						library_list xcoff_list;
	# (undefined_symbols,marked_bool_a,xcoff_a)	= mark_used_modules main_symbol_n main_file_n marked_bool_a marked_offset_a xcoff_a;
	= (undefined_symbols,n_xcoff_symbols,marked_bool_a,marked_offset_a,xcoff_a);
*/

/*	
create_xcoff_mark_and_offset_arrays :: Int Int Int Int LibraryList [*Xcoff] -> (!*{#Bool},!*{#Int},!*{#*Xcoff});
create_xcoff_mark_and_offset_arrays n_xcoff_files n_xcoff_symbols n_libraries n_library_symbols library_list list0
	=	(createArray (n_xcoff_symbols+n_library_symbols) False,offset_array1,xcoff_a);
	{
		(offset_array1,xcoff_a) = fill_offsets 0 0 list0 (createArray (n_xcoff_files+n_libraries) 0) (xcoff_array n_xcoff_files);

		xcoff_array :: Int -> !*{#*Xcoff};
		xcoff_array n = { empty_xcoff \\ i<-[0..dec n]};
		
		fill_offsets :: Int Int [*Xcoff] *{#Int} *{#*Xcoff} -> (!*{#Int},!*{#*Xcoff});
		fill_offsets file_n offset [xcoff=:{n_symbols}:xcoff_list] offset_array xcoff_a
			= fill_offsets (inc file_n) (offset+n_symbols) xcoff_list {offset_array & [file_n]=offset} {xcoff_a & [file_n]=xcoff};
		fill_offsets file_n offset [] offset_array xcoff_a
			= (fill_library_offsets library_list file_n offset offset_array,xcoff_a);
		
		fill_library_offsets :: LibraryList Int Int *{#Int} -> *{#Int};
		fill_library_offsets (Library _ symbols n_symbols libraries) file_n offset offset_array
			= fill_library_offsets libraries (inc file_n) (offset+n_symbols) {offset_array & [file_n]=offset};
		fill_library_offsets EmptyLibraryList file_n offset offset_array
			= offset_array;
	}
*/
	
read_library_files :: ![String] Int Int !*Files *NamesTable -> (![String],!LibraryList,!Int,!*Files,!*NamesTable);
read_library_files [] library_n n_library_symbols0 files0 names_table0
	= ([],EmptyLibraryList,n_library_symbols0,files0,names_table0);
read_library_files [file_name:file_names] library_n n_library_symbols0 files0 names_table0
	| ok1
		= (errors,Library library_name library_symbols n_library_symbols libraries,n_library_symbols1,files2,names_table2);
		= (["Cannot read library '" +++ file_name +++ "'"],EmptyLibraryList,0,files1,names_table1);
	{}{
		(errors,libraries,n_library_symbols1,files2,names_table2)
						= read_library_files file_names (inc library_n) (n_library_symbols0+n_library_symbols) files1 names_table1;
		(ok1,library_name,library_symbols,n_library_symbols,files1,names_table1)
						= read_library_file file_name library_n files0 names_table0;
	}
 
read_library_file :: String Int *Files *NamesTable -> (!Bool,!String,!LibrarySymbolsList,!Int,!*Files,!*NamesTable);
read_library_file library_file_name library_n files0 names_table0
	# (ok1,library_file0,files1) = fopen library_file_name FReadText files0;
	| not ok1
		= (False,"",EmptyLibrarySymbolsList,0,files1,names_table0);
	# (library_name0,library_file1) = freadline library_file0;
	  library_name1=library_name1;
	  with {
		library_name1 :: {#Char}; // to help the typechecker
		library_name1
			| size library_name0==0 || library_name0 .[size library_name0-1]<>'\n'
				= library_name0;
				= library_name0 % (0,size library_name0-2);
	  }
	  (library_symbols,n_library_symbols,library_file2,names_table1) = read_library_symbols 0 library_file1 names_table0;
 	  (ok2,files2) = fclose library_file2 files1;
//	| size library_name1<>0 && ok2
//		= (True,library_name1,library_symbols,n_library_symbols,files2,names_table1);

	| size library_name1==0
		= (False,"",EmptyLibrarySymbolsList,0,files2,names_table1);
	| ok2
		= (True,library_name1,library_symbols,n_library_symbols,files2,names_table1);

		= (False,"",EmptyLibrarySymbolsList,0,files2,names_table1);
	{}{
		read_library_symbols :: Int *File *NamesTable -> (!LibrarySymbolsList,!Int,!*File,!*NamesTable);
		read_library_symbols symbol_n file0 names_table0
			# (symbol_name,file1)=freadline file0;
			| size symbol_name==0
				= (EmptyLibrarySymbolsList,symbol_n,file1,names_table0);
			| symbol_name .[size symbol_name-1]<>'\n'
				= (LibrarySymbol symbol_name library_symbols,symbol_n1,file2,names_table2);
				{
					(library_symbols,symbol_n1,file2,names_table2) = read_library_symbols (symbol_n+2) file1 names_table1;
					names_table1 = insert_symbol_in_symbol_table ("."+++symbol_name) symbol_n library_n names_table0;
				}
			| size symbol_name==1
				= read_library_symbols symbol_n file1 names_table0;
				= (LibrarySymbol symbol_name1 library_symbols,symbol_n1,file2,names_table2);
				{
					(library_symbols,symbol_n1,file2,names_table2) = read_library_symbols (symbol_n+2) file1 names_table1;
					names_table1 = insert_symbol_in_symbol_table ("."+++symbol_name1) symbol_n library_n names_table0;
					symbol_name1 = symbol_name % (0,size symbol_name-2);
				}
	}

/*
KAN WEG
insert_exported_symbol_in_toc_table :: Int Int Int Int Int Int *{!Symbol} *{#Int} !*TocTable -> (!*{!Symbol},!*TocTable, *{#Int});
insert_exported_symbol_in_toc_table file_symbol_index symbol_module_n virtual_module_offset first_relocation_n relocation_symbol_n relocation_symbol_offset symbol_a=:{[relocation_symbol_n]=relocation_symbol} offset_a toc_table0
	= case relocation_symbol of {
		ImportedLabel {implab_file_n=imported_file_n,implab_symbol_n=symbol_n}
			| imported_file_n<0
				#! (s_offset_a,offset_a)
					= usize offset_a;
				#! (first_file_n,offset_a)
					= offset_a![s_offset_a + imported_file_n];
				->	insert_symbol_in_toc_table (first_file_n + symbol_n) relocation_symbol_offset symbol_a toc_table0 offset_a;
				
				#! (first_file_n,offset_a)
					= offset_a![imported_file_n];
				->	insert_symbol_in_toc_table (first_file_n + symbol_n) relocation_symbol_offset symbol_a toc_table0 offset_a;

		ImportedLabelPlusOffset {implaboffs_file_n=imported_file_n,implaboffs_symbol_n=symbol_n,implaboffs_offset=offset}
			#! (first_file_n,offset_a)
				= offset_a![imported_file_n];
			->	insert_symbol_in_toc_table (first_file_n+symbol_n) (relocation_symbol_offset+offset) symbol_a toc_table0 offset_a;

		Module {module_offset=offset}
			->	insert_symbol_in_toc_table (file_symbol_index+relocation_symbol_n) (relocation_symbol_offset-offset) symbol_a toc_table0 offset_a;
		Label {label_offset=offset}
			->	insert_symbol_in_toc_table (file_symbol_index+relocation_symbol_n) (relocation_symbol_offset-offset) symbol_a toc_table0 offset_a;
		ImportedFunctionDescriptor {implab_file_n,implab_symbol_n}
			->	({symbol_a & [symbol_module_n] = ImportedFunctionDescriptorTocModule {
					imptoc_offset = virtual_module_offset,imptoc_file_n=implab_file_n,imptoc_symbol_n=implab_symbol_n
				  }},toc_table0,offset_a);

	  }
	{
	/* read_long */
		insert_symbol_in_toc_table :: Int Int *SymbolArray *TocTable *{#Int} -> (!*SymbolArray,!*TocTable,*{#Int});			
		insert_symbol_in_toc_table new_symbol_n new_offset symbol_a0 EmptyTocTable offset_a
			=	(symbol_a0,Toc {global_module_n=file_symbol_index+symbol_module_n,symbol_n=new_symbol_n,offset=new_offset} EmptyTocTable EmptyTocTable,offset_a);
		insert_symbol_in_toc_table new_symbol_n new_offset symbol_a0 t=:(Toc toc_elem=:{TocElem | symbol_n,offset} left right) offset_a
			| new_symbol_n<symbol_n
				#	(symbol_a1,left1,offset_a) = insert_symbol_in_toc_table new_symbol_n new_offset symbol_a0 left offset_a;
				=	(symbol_a1,Toc toc_elem left1 right,offset_a);
			| new_symbol_n>symbol_n
				#	(symbol_a1,right1,offset_a) = insert_symbol_in_toc_table new_symbol_n new_offset symbol_a0 right offset_a;
				=	(symbol_a1,Toc toc_elem left right1,offset_a);
			| new_offset==offset
				=	({symbol_a0 & [symbol_module_n]=AliasModule {
						alias_module_offset = virtual_module_offset,
						alias_first_relocation_n = first_relocation_n,
						alias_global_module_n = toc_elem.global_module_n
					  }},
//					  t
					  Toc toc_elem left right,
					  offset_a
					  );
			| new_offset<offset
				#	(symbol_a1,left1,offset_a) = insert_symbol_in_toc_table new_symbol_n new_offset symbol_a0 left offset_a;
				=	(symbol_a1,Toc toc_elem left1 right, offset_a);
				#	(symbol_a1,right1,offset_a) = insert_symbol_in_toc_table new_symbol_n new_offset symbol_a0 right offset_a;
				=	(symbol_a1,Toc toc_elem left right1,offset_a);

	}
*/
	
xcoff_list_to_array :: !Int ![*Xcoff] -> !{#*Xcoff};
xcoff_list_to_array n_xcoff_files xcoff_list
	= fill_array 0 xcoff_list { empty_xcoff \\ i <- [1..n_xcoff_files] };
{		
	fill_array file_n [] xcoff_a
		= xcoff_a;
	fill_array file_n [xcoff:xcoff_list] xcoff_a
		= fill_array (inc file_n) xcoff_list {xcoff_a & [file_n]=xcoff};
}

