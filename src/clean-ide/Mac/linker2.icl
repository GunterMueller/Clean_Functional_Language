implementation module linker2;

import StdInt,StdBool,StdString,StdChar,StdArray,StdFile,StdClass,StdMisc;
import UtilNewlinesFile;

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

::	NamesTable :== {!NamesTableElement};

::	NamesTableElement
	= NamesTableElement !String !Int !Int !NamesTableElement	// symbol_name symbol_n file_n symbol_list
	| EmptyNamesTableElement;

::	LibraryList = Library !String !LibrarySymbolsList !Int !LibraryList | EmptyLibraryList;

::	LibrarySymbolsList = LibrarySymbol !String !LibrarySymbolsList | EmptyLibrarySymbolsList;

:: Xcoff ={
		header				:: !XcoffHeader,
		symbol_table		:: !.SymbolTable,
		text_relocations	:: !String,
		data_relocations	:: !String,
		n_text_relocations	:: !Int,
		n_data_relocations	:: !Int,
		n_symbols			:: !Int
	};

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

:: SymbolsArray :== {!SymbolArray};

n_symbols_of_xcoff_list :: !Int ![*Xcoff] -> (!Int,![*Xcoff]);
n_symbols_of_xcoff_list n_symbols0 []
	= (n_symbols0,[]);
n_symbols_of_xcoff_list n_symbols0 [xcoff=:{n_symbols}:xcoff_list0]
	= (n_symbols1,[xcoff:xcoff_list1]);
	{
		(n_symbols1,xcoff_list1)=n_symbols_of_xcoff_list (n_symbols0+n_symbols) xcoff_list0;
	}

(FWI) infixl;
(FWI) f i :== fwritei i f;

(FWS) infixl;
(FWS) f s :== fwrites s f;

(FWC) infixl;
(FWC) f c :== fwritec c f;

create_xcoff_file :: !String !Int !Int !Int !Int !Int !*Files -> *(*File,*Files);
create_xcoff_file xcoff_file_name text_section_size data_section_size bss_section_size loader_section_size main_offset files0
	| ok
		= (file5,files1);
	{}{
		(ok,file0,files1) = fopen xcoff_file_name FWriteData /*(FWriteData + 16384)*/ files0;

		file1 = file0
			FWI 0x01df0004 FWI 0 FWI 0 FWI 0 FWI 0x00481003
			FWI 0x010b0001 FWI text_section_size FWI data_section_size FWI bss_section_size FWI main_offset FWI 0 FWI 0 FWI 0
			FWI 0x00020001 FWI 0x00020002 FWI 0x00040003 FWI 0x00020002 FWI (((toInt '1'<<8)bitor (toInt 'L'))<<16)
			FWI 0 FWI 0 FWI 0 FWI 0 FWI 0;
		
		file2 = file1
			FWS ".text\000\000\000" FWI 0 FWI 0 FWI text_section_size FWI 252 FWI 0 FWI 0 FWI 0 FWI 0x20;
		file3 = file2
			FWS ".data\000\000\000" FWI 0 FWI 0 FWI data_section_size FWI (252+text_section_size) FWI 0 FWI 0 FWI 0 FWI 0x40;
		file4 = file3
			FWS ".bss\000\000\000\000" FWI data_section_size FWI data_section_size FWI bss_section_size FWI 0 FWI 0 FWI 0 FWI 0 FWI 0x80;
		file5 = file4
			FWS ".loader\000" FWI 0 FWI 0 FWI loader_section_size FWI (252+text_section_size+data_section_size) FWI 0 FWI 0 FWI 0 FWI 0x1000;
	}


SIZE_OF_HEADER:==20;
SIZE_OF_SECTION_HEADER:==40;
SIZE_OF_SYMBOL:==18;
SIZE_OF_RELOCATION:==10;

C_EXT:==2;
C_STAT:==3;
C_HIDEXT:==107;
C_FILE:==103;

XTY_ER:==0;
XTY_SD:==1;
XTY_LD:==2;
XTY_CM:==3;

N_UNDEF:==0;
TEXT_SECTION:==1;
DATA_SECTION:==2;
BSS_SECTION:==3;
TOC_SECTION:==4;

XMC_PR:==0;
XMC_RO:==1;
XMC_TC:==3;
XMC_RW:==5;
XMC_GL:==6;
XMC_BS:==9;
XMC_DS:==10;
XMC_TC0:==15;

R_POS:==0;
R_TOC:==3;
R_TRL:==0x12; // 4;
R_BR:==10;
R_REF:==15;

R_MW_POS:==32;
R_MW_BR:==42;
R_MW_TOC:==35;

// RWS (CHAR);
(CHAR) string i :== string.[i];

// RWS (BYTE);
(BYTE) string i :== toInt (string.[i]);

(WORD) :: !String !Int -> Int;
(WORD) string i = (string BYTE i<<8) bitor (string BYTE (i+1));

// RWS (LONG);
(LONG) string i
	= (string BYTE i<<24) bitor (string BYTE (i+1)<<16) bitor (string BYTE (i+2)<<8) bitor (string BYTE (i+3));

SYMBOL_TABLE_SIZE:==4096;
SYMBOL_TABLE_SIZE_MASK:==4095;

create_names_table :: *NamesTable;
create_names_table = createArray SYMBOL_TABLE_SIZE EmptyNamesTableElement;

insert_symbol_in_symbol_table :: !String Int Int !*NamesTable -> *NamesTable;
insert_symbol_in_symbol_table symbol_name symbol_n file_n names_table/*=:{[symbol_hash]=symbol_list}*/
	#!	symbol_list=names_table.[symbol_hash];
	| symbol_in_symbol_table_list symbol_list
		= names_table;
	= { names_table & [symbol_hash] = NamesTableElement symbol_name symbol_n file_n symbol_list};
	{};{
		symbol_hash=symbol_name_hash symbol_name;
		
		
		symbol_in_symbol_table_list EmptyNamesTableElement
			= False;
		symbol_in_symbol_table_list (NamesTableElement string  _ _ symbol_table_list)
			| string==symbol_name
				= True;
				= symbol_in_symbol_table_list symbol_table_list;
	}

find_symbol_in_symbol_table :: !String !*NamesTable -> (!NamesTableElement,!*NamesTable);
find_symbol_in_symbol_table symbol_name names_table/*=:{[symbol_hash]=symbol_list}*/
	#!	symbol_list=names_table.[symbol_hash];
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

::	SortArray :== {#SortElement};
::	SortElement = { index::!Int, offset::!Int };

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
					= heap_sort1 a i j (inc j) max_index ir;
				{
					heap_sort1 :: !*SortArray !Int !Int !Int !Int !SortElement -> *SortArray;
					heap_sort1 a=:{[j]=a_j,[j1]=a_j_1} i j j1 max_index ir
						= heap_sort1 a_j a_j_1 a i j max_index ir;
					{
						heap_sort1 :: !SortElement !SortElement !*SortArray !Int !Int !Int !SortElement -> *SortArray;
						heap_sort1 a_j a_j_1 a i j max_index ir
						| a_j.offset < a_j_1.offset
							= heap_sort2 a i (inc j) max_index ir;
							= heap_sort2 a i j max_index ir;
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
						| ir.offset<a_j.offset
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

	symbol_index_less_or_equal :: Int Int {!Symbol} -> Bool;
	symbol_index_less_or_equal i1 i2 {[i1]=m1,[i2]=m2}
		= case (m1,m2) of {
			(Module {module_offset=offset1},Module {module_offset=offset2})
				-> offset1<=offset2; 
		};

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
//		{text_symbols,data_symbols,bss_symbols,symbols=symbols0} = symbol_table;
		text_symbols	= symbol_table.text_symbols;
		data_symbols	= symbol_table.data_symbols;
		bss_symbols		= symbol_table.bss_symbols;
		symbols0		= symbol_table.symbols;
	}

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
	# (ok1,library_file0,files1) = fopen library_file_name FReadData files0;
	| not ok1
		= (False,"",EmptyLibrarySymbolsList,0,files1,names_table0);
	# (library_name0,library_file1) = readLine library_file0;
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
			# (symbol_name,file1)=readLine file0;
			| size symbol_name==0
				= debug ("libsym: Empty") (EmptyLibrarySymbolsList,symbol_n,file1,names_table0);
			| symbol_name .[size symbol_name-1]<>'\n'
				= debug ("libsym (notn): "+++symbol_name) (LibrarySymbol symbol_name library_symbols,symbol_n1,file2,names_table2);
				{
					(library_symbols,symbol_n1,file2,names_table2) = read_library_symbols (symbol_n+2) file1 names_table1;
					names_table1 = insert_symbol_in_symbol_table ("."+++symbol_name) symbol_n library_n names_table0;
				}
			| size symbol_name==1
				= debug ("libsym: size 1") read_library_symbols symbol_n file1 names_table0;
				= debug ("libsym (isn): "+++symbol_name1) (LibrarySymbol symbol_name1 library_symbols,symbol_n1,file2,names_table2);
				{
					(library_symbols,symbol_n1,file2,names_table2) = read_library_symbols (symbol_n+2) file1 names_table1;
					names_table1 = insert_symbol_in_symbol_table ("."+++symbol_name1) symbol_n library_n names_table0;
					symbol_name1 = symbol_name % (0,size symbol_name-2);
				}
	}

	read_string_table :: *File -> (!Bool,!String,!*File);
	read_string_table file0
		| not ok
			= error file1;
		| string_table_size==0
			= (True,"",file1);
		| string_table_size<4
			= error file1;
		| not (size string_table_string==string_table_size2)
			= error file2;
			= (True,string_table_string,file2);
		{}{
			error file=(False,"",file);
			(string_table_string,file2)=freads file1 string_table_size2;
			string_table_size2=string_table_size-4;
			(ok,string_table_size,file1)=freadi file0;
		}

	read_symbols :: Int *File -> (!Bool,!String,!String,!*File);
	read_symbols n_symbols file0
		# symbol_table_size=n_symbols*SIZE_OF_SYMBOL;
		  (symbol_table_string,file1)=freads file0 symbol_table_size;
		| not (size symbol_table_string==symbol_table_size)
			= (False,"","",file1);
			= (ok,symbol_table_string,string_table,file2);
			{
				(ok,string_table,file2)=read_string_table file1;
			}

read_symbol_table :: !Int !Int !*File -> (!Bool,!String,!String,!*File);
read_symbol_table symbol_table_offset n_symbols file0
	| not fseek_ok
		= error file1;
		= read_symbols n_symbols file1;
	{}{
		(fseek_ok,file1)=fseek file0 symbol_table_offset FSeekSet;
		error file=(False,"","",file);
	}

/*
PRINT_INT i 	| !error = i; {}{ (error,_)=ferror (fwritec ' ' (fwritei i stderr)); }

PRINT_RELOCATION r=:EmptyRelocation | !error = r; {}{ (error,_)=ferror (fwritec ' ' (fwritei 0 stderr)); }
PRINT_RELOCATION r=:(CodeRelocation _ _) | !error = r; {}{ (error,_)=ferror (fwritec ' ' (fwritei 1 stderr)); }
PRINT_RELOCATION r=:(DataRelocation _ _) | !error = r; {}{ (error,_)=ferror (fwritec ' ' (fwritei 2 stderr)); }
PRINT_RELOCATION r=:(DeltaRelocation _ _) | !error = r; {}{ (error,_)=ferror (fwritec ' ' (fwritei 3 stderr)); }
*/


compute_pef_loader_relocations :: ![Xcoff] {#Bool} {#Int} {#Int} SymbolsArray Int -> *LoaderRelocations;
compute_pef_loader_relocations xcoffs marked_bool_a module_offset_a marked_offset_a symbols_a n_imported_symbols
	= compute_loader_relocations_of_files xcoffs xcoffs 0 marked_bool_a module_offset_a marked_offset_a symbols_a (n_imported_symbols<<2) (imported_symbol_relocations n_imported_symbols);
{
	imported_symbol_relocations 0
		= EmptyRelocation;
	imported_symbol_relocations n_imported_symbols
		| n_imported_symbols<=512
			= ImportedSymbolsRelocation n_imported_symbols EmptyRelocation;
			= ImportedSymbolsRelocation 512 (imported_symbol_relocations (n_imported_symbols-512));
	
	compute_loader_relocations_of_files :: ![Xcoff] ![Xcoff] Int {#Bool} {#Int} {#Int} SymbolsArray Int !*LoaderRelocations -> *LoaderRelocations;
	compute_loader_relocations_of_files [] xcoffs first_symbol_n marked_bool_a module_offset_a marked_offset_a xcoff_a relocation_offset0 relocations0
		= compute_data_relocations_of_files xcoffs 0 marked_bool_a module_offset_a marked_offset_a xcoff_a relocation_offset0 relocations0;
	compute_loader_relocations_of_files [xcoff=:{n_symbols,symbol_table={toc_symbols,symbols},data_relocations}:xcoff_list] xcoffs first_symbol_n marked_bool_a module_offset_a marked_offset_a xcoff_a relocation_offset0 relocations0
		= compute_loader_relocations_of_files xcoff_list xcoffs (first_symbol_n+n_symbols) marked_bool_a module_offset_a marked_offset_a xcoff_a relocation_offset1 relocations1; {
			(relocation_offset1,relocations1)
				= compute_loader_relocations_of_file toc_symbols symbols first_symbol_n data_relocations marked_bool_a module_offset_a marked_offset_a xcoff_a relocation_offset0 relocations0;
			}

	compute_data_relocations_of_files :: ![Xcoff] Int {#Bool} {#Int} {#Int} SymbolsArray Int !*LoaderRelocations -> *LoaderRelocations;
	compute_data_relocations_of_files [] first_symbol_n marked_bool_a module_offset_a marked_offset_a xcoff_a relocation_offset0 relocations0
		= relocations0;
	compute_data_relocations_of_files [xcoff=:{n_symbols,symbol_table={data_symbols,symbols},data_relocations}:xcoff_list] first_symbol_n marked_bool_a module_offset_a marked_offset_a xcoff_a relocation_offset0 relocations0
		= compute_data_relocations_of_files xcoff_list (first_symbol_n+n_symbols) marked_bool_a module_offset_a marked_offset_a xcoff_a relocation_offset1 relocations1; {
			(relocation_offset1,relocations1)
				= compute_loader_relocations_of_file data_symbols symbols first_symbol_n data_relocations marked_bool_a module_offset_a marked_offset_a xcoff_a relocation_offset0 relocations0;
			}

	compute_loader_relocations_of_file :: SymbolIndexList SymbolArray Int String {#Bool} {#Int} {#Int} SymbolsArray Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
	compute_loader_relocations_of_file EmptySymbolIndex symbol_table first_symbol_n data_relocations marked_bool_a module_offset_a marked_offset_a0 xcoff_a relocation_offset0 relocations0
		= (relocation_offset0,relocations0);
	compute_loader_relocations_of_file (SymbolIndex module_n symbol_list) symbol_table=:{[module_n] = symbol} first_symbol_n data_relocations marked_bool_a module_offset_a marked_offset_a0 xcoff_a relocation_offset0 relocations0
		| not (marked_bool_a.[first_symbol_n+module_n])
			= compute_loader_relocations_of_file symbol_list symbol_table first_symbol_n data_relocations marked_bool_a module_offset_a marked_offset_a0 xcoff_a relocation_offset0 relocations0;
			= compute_loader_relocations_of_file symbol_list symbol_table first_symbol_n data_relocations marked_bool_a module_offset_a marked_offset_a0 xcoff_a relocation_offset1 relocations1;
		{
			(relocation_offset1,relocations1)
				= compute_data_loader_relocations symbol module_offset_a marked_offset_a0 xcoff_a relocation_offset0 relocations0;

			compute_data_loader_relocations :: Symbol {#Int} {#Int} SymbolsArray Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
			compute_data_loader_relocations (Module {section_n,module_offset=virtual_module_offset,first_relocation_n,end_relocation_n})
					module_offset_a marked_offset_a0 xcoff_a relocation_offset0 relocations0
				| section_n==DATA_SECTION || section_n==TOC_SECTION
					= compute_loader_relocations first_relocation_n end_relocation_n virtual_module_offset real_module_offset data_relocations
												 first_symbol_n marked_offset_a0 symbol_table xcoff_a relocation_offset0 relocations0;
				{}{
					real_module_offset = module_offset_a.[first_symbol_n+module_n];
				}
			compute_data_loader_relocations (AliasModule _)
					module_offset_a marked_offset_a0 symbols_a relocation_offset0 relocations0
				= (relocation_offset0,relocations0);
			compute_data_loader_relocations (ImportedFunctionDescriptorTocModule _)
					module_offset_a marked_offset_a0 symbols_a relocation_offset0 relocations0
				= (relocation_offset0,relocations0);
		}

	compute_loader_relocations :: Int Int Int Int String Int {#Int} {!Symbol} SymbolsArray Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
	compute_loader_relocations relocation_n end_relocation_n virtual_module_offset real_module_offset text_relocations
		first_symbol_n marked_offset_a0 symbol_a xcoff_a relocation_offset0 relocations0
	| relocation_n==end_relocation_n
		= (relocation_offset0,relocations0);
		= compute_loader_relocations (inc relocation_n) end_relocation_n virtual_module_offset real_module_offset text_relocations
									first_symbol_n marked_offset_a0 symbol_a xcoff_a relocation_offset1 relocations1;
	{		
		(relocation_offset1,relocations1) = compute_relocation relocation_type symbol_a marked_offset_a0 xcoff_a relocation_offset0 relocations0;
		
		compute_relocation :: Int {!Symbol} {#Int} SymbolsArray Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
		compute_relocation R_POS symbol_a marked_offset_a0 xcoff_a relocation_offset0 relocations0
			| relocation_size==0x1f
				= compute_loader_relocation symbol_a.[relocation_symbol_n] offset first_symbol_n symbol_a marked_offset_a0 xcoff_a relocation_offset0 relocations0;
				{
					offset = real_module_offset+(relocation_offset-virtual_module_offset);
				}
		compute_relocation R_MW_POS symbol_a marked_offset_a0 xcoff_a relocation_offset0 relocations0
			| relocation_size==0x1f
				# offset = real_module_offset+(relocation_offset-virtual_module_offset);
				= compute_loader_relocation symbol_a.[relocation_symbol_n] offset first_symbol_n symbol_a marked_offset_a0 xcoff_a relocation_offset0 relocations0;
		
		relocation_type=text_relocations BYTE (relocation_index+9);
		relocation_size=text_relocations BYTE (relocation_index+8);
		relocation_symbol_n=(inc (text_relocations LONG (relocation_index+4))) >> 1;
		relocation_offset=text_relocations LONG relocation_index;

		relocation_index=relocation_n * SIZE_OF_RELOCATION;
	}

	compute_loader_relocation :: Symbol Int Int {!Symbol} {#Int} SymbolsArray Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
	compute_loader_relocation (Module {section_n}) offset first_symbol_n symbol_a marked_offset_a0 xcoff_a relocation_offset0 relocations0
		= loader_relocation section_n offset relocation_offset0 relocations0;
	compute_loader_relocation (Label {label_section_n}) offset first_symbol_n symbol_a marked_offset_a0 xcoff_a relocation_offset0 relocations0
		= loader_relocation label_section_n offset relocation_offset0 relocations0;
	compute_loader_relocation (ImportedLabel {implab_file_n,implab_symbol_n}) offset first_symbol_n symbol_a marked_offset_a0 xcoff_a relocation_offset0 relocations0
		| implab_file_n<0
			=	loader_code_relocation offset relocation_offset0 relocations0;
			=	compute_loader_relocation symbol_a.[implab_symbol_n] offset first_symbol_n symbol_a marked_offset_a0 xcoff_a relocation_offset0 relocations0;
			{
				first_symbol_n = marked_offset_a0.[implab_file_n];
				symbol_a=xcoff_a.[implab_file_n];		
			}
	compute_loader_relocation (ImportedLabelPlusOffset {implaboffs_file_n,implaboffs_symbol_n}) offset first_symbol_n symbol_a marked_offset_a0 xcoff_a relocation_offset0 relocations0
		=	compute_loader_relocation symbol_a.[implaboffs_symbol_n] offset first_symbol_n symbol_a marked_offset_a0 xcoff_a relocation_offset0 relocations0;
		{
			first_symbol_n = marked_offset_a0.[implaboffs_file_n];
			symbol_a=xcoff_a.[implaboffs_file_n];		
		}

	loader_relocation :: Int Int Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
	loader_relocation section_n offset relocation_offset0 relocations0
		| section_n==TEXT_SECTION
			= loader_code_relocation offset relocation_offset0 relocations0;
		| section_n==DATA_SECTION || section_n==BSS_SECTION || section_n==TOC_SECTION
			= loader_data_relocation offset relocation_offset0 relocations0;

	loader_code_relocation :: Int Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
	loader_code_relocation offset relocation_offset0 (CodeRelocation n relocations)
		| offset==relocation_offset0 && n<512
			= (offset+4,CodeRelocation (inc n) relocations);
	loader_code_relocation offset relocation_offset0 relocations0
		= (offset+4,CodeRelocation 1 (loader_delta_relocations (offset-relocation_offset0) relocations0));

	loader_data_relocation :: Int Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
	loader_data_relocation offset relocation_offset0 (DataRelocation n relocations)
		| offset==relocation_offset0 && n<512
			= (offset+4,DataRelocation (inc n) relocations);
	loader_data_relocation offset relocation_offset0 relocations0
		| displacement>0 && displacement<1024 && (displacement bitand 3)==0
			= (offset+4,DeltaDataRelocation displacement 1 relocations0);
			= (offset+4,DataRelocation 1 (loader_delta_relocations displacement relocations0));
		{}{
			displacement=offset-relocation_offset0;
		}

	loader_delta_relocations 0 relocations
		= relocations;
	loader_delta_relocations offset relocations
		| offset<=4096
			= DeltaRelocation offset relocations;
			= loader_delta_relocations (offset-4096) (DeltaRelocation 4096 relocations);
}

compute_xcoff_loader_relocations :: ![Xcoff] {#Bool} {#Int} {#Int} SymbolsArray -> *LoaderRelocations;
compute_xcoff_loader_relocations xcoffs marked_bool_a module_offset_a marked_offset_a symbols_a
	= compute_loader_relocations_of_files xcoffs xcoffs 0 marked_bool_a module_offset_a marked_offset_a symbols_a EmptyRelocation;
{
	compute_loader_relocations_of_files :: ![Xcoff] ![Xcoff] Int {#Bool} {#Int} {#Int} SymbolsArray !*LoaderRelocations -> *LoaderRelocations;
	compute_loader_relocations_of_files [] xcoffs first_symbol_n marked_bool_a module_offset_a marked_offset_a symbols_a relocations0
		= compute_data_relocations_of_files xcoffs 0 marked_bool_a module_offset_a marked_offset_a symbols_a relocations0;
	compute_loader_relocations_of_files [xcoff=:{n_symbols,symbol_table={toc_symbols,symbols},data_relocations}:xcoff_list] xcoffs first_symbol_n marked_bool_a module_offset_a marked_offset_a symbols_a relocations0
		= compute_loader_relocations_of_files xcoff_list xcoffs (first_symbol_n+n_symbols) marked_bool_a module_offset_a marked_offset_a symbols_a relocations1;
	{
		relocations1 = compute_loader_relocations_of_file toc_symbols symbols first_symbol_n data_relocations marked_bool_a module_offset_a marked_offset_a symbols_a relocations0;
	}
	
	compute_data_relocations_of_files :: ![Xcoff] Int {#Bool} {#Int} {#Int} SymbolsArray !*LoaderRelocations -> *LoaderRelocations;
	compute_data_relocations_of_files [] first_symbol_n marked_bool_a module_offset_a marked_offset_a symbols_a relocations0
		= relocations0;
	compute_data_relocations_of_files [xcoff=:{n_symbols,symbol_table={data_symbols,symbols},data_relocations}:xcoff_list] first_symbol_n marked_bool_a module_offset_a marked_offset_a symbols_a relocations0
		= compute_data_relocations_of_files xcoff_list (first_symbol_n+n_symbols) marked_bool_a module_offset_a marked_offset_a symbols_a relocations1; {
			relocations1 = compute_loader_relocations_of_file data_symbols symbols first_symbol_n data_relocations marked_bool_a module_offset_a marked_offset_a symbols_a relocations0;
			}

	compute_loader_relocations_of_file :: SymbolIndexList SymbolArray Int String {#Bool} {#Int} {#Int} SymbolsArray *LoaderRelocations -> *LoaderRelocations;
	compute_loader_relocations_of_file EmptySymbolIndex symbol_table first_symbol_n data_relocations marked_bool_a module_offset_a marked_offset_a0 symbols_a relocations0
		= relocations0;
	compute_loader_relocations_of_file (SymbolIndex module_n symbol_list) symbol_table=:{[module_n] = symbol} first_symbol_n data_relocations marked_bool_a module_offset_a marked_offset_a0 symbols_a relocations0
		| not marked_bool_a.[first_symbol_n+module_n]
			= compute_loader_relocations_of_file symbol_list symbol_table first_symbol_n data_relocations marked_bool_a module_offset_a marked_offset_a0 symbols_a relocations0;
			= compute_loader_relocations_of_file symbol_list symbol_table first_symbol_n data_relocations marked_bool_a module_offset_a marked_offset_a0 symbols_a relocations1;
			{
				relocations1 = compute_data_loader_relocations symbol module_offset_a marked_offset_a0 symbols_a relocations0;

				compute_data_loader_relocations :: Symbol {#Int} {#Int} SymbolsArray *LoaderRelocations -> *LoaderRelocations;
				compute_data_loader_relocations (Module {section_n,module_offset=virtual_module_offset,first_relocation_n,end_relocation_n})
						module_offset_a marked_offset_a0 symbols_a relocations0
					| section_n==DATA_SECTION || section_n==TOC_SECTION
						= compute_loader_relocations first_relocation_n end_relocation_n virtual_module_offset real_module_offset data_relocations
												 first_symbol_n marked_offset_a0 symbol_table symbols_a relocations0;
					{}{
						real_module_offset = module_offset_a.[first_symbol_n+module_n];
					}
				compute_data_loader_relocations (AliasModule _) 
						module_offset_a marked_offset_a0 symbols_a relocations0
					= relocations0;
				compute_data_loader_relocations (ImportedFunctionDescriptorTocModule _) 
						module_offset_a marked_offset_a0 symbols_a relocations0
					= relocations0;
			}

	compute_loader_relocations :: Int Int Int Int String Int {#Int} {!Symbol} SymbolsArray *LoaderRelocations -> *LoaderRelocations;
	compute_loader_relocations relocation_n end_relocation_n virtual_module_offset real_module_offset text_relocations
			first_symbol_n marked_offset_a0 symbol_a symbols_a relocations0
		| relocation_n==end_relocation_n
			= relocations0;
			= compute_loader_relocations (inc relocation_n) end_relocation_n virtual_module_offset real_module_offset text_relocations
										first_symbol_n marked_offset_a0 symbol_a symbols_a relocations1;
		{
			relocations1 = compute_relocation relocation_type symbol_a marked_offset_a0 symbols_a relocations0;
		
			compute_relocation :: Int {!Symbol} {#Int} SymbolsArray *LoaderRelocations -> *LoaderRelocations;
			compute_relocation R_POS symbol_a marked_offset_a0 symbols_a relocations0
				| relocation_size==0x1f
					= compute_loader_relocation symbol_a.[relocation_symbol_n] offset marked_offset_a0 symbols_a relocations0;
					{
						offset = real_module_offset+(relocation_offset-virtual_module_offset);
					}

			relocation_type=text_relocations BYTE (relocation_index+9);
			relocation_size=text_relocations BYTE (relocation_index+8);
			relocation_symbol_n=(inc (text_relocations LONG (relocation_index+4))) >> 1;
			relocation_offset=text_relocations LONG relocation_index;

			relocation_index=relocation_n * SIZE_OF_RELOCATION;
		}

		compute_loader_relocation :: Symbol Int {#Int} SymbolsArray *LoaderRelocations -> *LoaderRelocations;
		compute_loader_relocation (Module {section_n}) offset marked_offset_a0 symbols_a relocations0
			= loader_relocation section_n offset relocations0;
		compute_loader_relocation (Label {label_section_n}) offset marked_offset_a0 symbols_a relocations0
			= loader_relocation label_section_n offset relocations0;
		compute_loader_relocation (ImportedLabel {implab_file_n,implab_symbol_n}) offset marked_offset_a0 symbols_a relocations0
			| implab_file_n<0
				=	CodeRelocation offset relocations0;
				=	compute_loader_relocation symbols_a.[implab_file_n,implab_symbol_n] offset marked_offset_a0 symbols_a relocations0;
		compute_loader_relocation (ImportedLabelPlusOffset {implaboffs_file_n,implaboffs_symbol_n}) offset marked_offset_a0 symbols_a relocations0
			=	compute_loader_relocation symbols_a.[implaboffs_file_n,implaboffs_symbol_n] offset marked_offset_a0 symbols_a relocations0;

		loader_relocation :: Int Int *LoaderRelocations -> *LoaderRelocations;
		loader_relocation section_n offset relocations0
			| section_n==TEXT_SECTION
				= CodeRelocation offset relocations0;
			| section_n==DATA_SECTION || section_n==BSS_SECTION || section_n==TOC_SECTION
				= DataRelocation offset relocations0;
	}

count_and_reverse_relocations :: !*LoaderRelocations -> (!Int,!*LoaderRelocations);
count_and_reverse_relocations relocation
	= count_relocations relocation 0 EmptyRelocation;
{
	count_relocations :: !*LoaderRelocations !Int !*LoaderRelocations -> (!Int,!*LoaderRelocations);
	count_relocations (CodeRelocation i r) n result
		= count_relocations r (inc n) (CodeRelocation i result);
	count_relocations (DataRelocation i r) n result
		= count_relocations r (inc n) (DataRelocation i result);
	count_relocations (DeltaDataRelocation d i r) n result
		= count_relocations r (inc n) (DeltaDataRelocation d i result);
	count_relocations (DeltaRelocation i r) n result
		= count_relocations r (inc n) (DeltaRelocation i result);
	count_relocations (ImportedSymbolsRelocation i r) n result
		= count_relocations r (inc n) (ImportedSymbolsRelocation i result);
	count_relocations EmptyRelocation n result
		= (n,result);
}

write_pef_loader_relocations :: !LoaderRelocations !*File -> *File;
write_pef_loader_relocations EmptyRelocation pef_file0
	= pef_file0;
write_pef_loader_relocations (CodeRelocation i relocations) pef_file0
	= write_pef_loader_relocations relocations (fwritec (toChar deci) (fwritec (toChar (0x40+(deci>>8))) pef_file0));
	{
		deci =  dec i;
	}
write_pef_loader_relocations (DataRelocation i relocations) pef_file0
	= write_pef_loader_relocations relocations (fwritec (toChar deci) (fwritec (toChar (0x42+(deci>>8))) pef_file0));
	{
		deci =  dec i;
	}

write_xcoff_loader_relocations :: !LoaderRelocations !*File -> *File;
write_xcoff_loader_relocations EmptyRelocation xcoff_file0
	= xcoff_file0;
write_xcoff_loader_relocations (CodeRelocation i relocations) xcoff_file0
	= write_xcoff_loader_relocations relocations (xcoff_file0 FWI i FWI 0 FWI 0x1f000002);
write_xcoff_loader_relocations (DataRelocation i relocations) xcoff_file0
	= write_xcoff_loader_relocations relocations (xcoff_file0 FWI i FWI 1 FWI 0x1f000002);

define_symbols :: Int String String *NamesTable Int -> (!*NamesTable,!*SymbolTable);
define_symbols n_symbols symbol_table_string string_table names_table file_n
	= define_symbols_lp 0 names_table empty_symbol_table;
	{

		empty_symbol_table = {	text_symbols=EmptySymbolIndex,
								data_symbols=EmptySymbolIndex,
								toc_symbols=EmptySymbolIndex,
								bss_symbols=EmptySymbolIndex,
								toc0_symbol=EmptySymbolIndex,
								imported_symbols=EmptySymbolIndex,
								symbols=createArray n_symbols EmptySymbol
							 };

		define_symbols_lp :: !Int !*NamesTable !*SymbolTable -> (!*NamesTable,!*SymbolTable);
		define_symbols_lp symbol_n names_table0 symbol_table0
		| offset==size symbol_table_string
			= (names_table0,symbol_table0);
			= case (symbol_table_string BYTE (offset+16)) of {
					C_HIDEXT
						-> define_symbols_lp (symbol_n+1+n_numaux) names_table0 (new_symbol_table symbol_table0 n_value);
					C_EXT
						| n_scnum==N_UNDEF
							| x_sm_typ_t==XTY_ER
								-> define_symbols_lp (symbol_n+1+n_numaux) names_table0 symbol_table1;
								{
									symbol_table1 = {symbol_table0 & 
													symbols={symbol_table0.symbols & [symbol_n_2] = ImportLabel name_of_symbol},
													imported_symbols=SymbolIndex symbol_n_2 symbol_table0.imported_symbols												
													};
								}
								-> abort "error in EXT symbol";
							-> define_symbols_lp (symbol_n+1+n_numaux) names_table1 (new_symbol_table symbol_table0 n_value);
							{
								names_table1=insert_symbol_in_symbol_table name_of_symbol symbol_n_2 file_n names_table0;
							}
					C_FILE
						-> define_symbols_lp (symbol_n+1+n_numaux) names_table0 symbol_table0;
					C_STAT
						-> define_symbols_lp (symbol_n+1+n_numaux) names_table0 symbol_table0;
					unknown
						-> abort ("unknown symbol type in linker: " +++ toString unknown +++ ".\n")
				};
			{
				new_symbol_table :: *SymbolTable Int -> .SymbolTable;
				new_symbol_table symbol_table0 n_value
					| x_sm_typ_t==XTY_SD
						= symbol_table_with_csect symbol_table0;
					| x_sm_typ_t==XTY_LD
						= symbol_table_with_label symbol_table0;
					| x_sm_typ_t==XTY_CM
						= symbol_table_with_common symbol_table0 n_value;
				
				symbol_table_with_csect symbol_table0
					| n_scnum==TEXT_SECTION && (x_smclass==XMC_PR || x_smclass==XMC_GL)
						= {symbol_table0 & 
							symbols     = {symbol_table0.symbols & [symbol_n_2]=
											Module {section_n=TEXT_SECTION,
													module_offset=n_value,length=x_scnlen,
													first_relocation_n=0,end_relocation_n=0,
													align=x_sm_align}},
							text_symbols= SymbolIndex symbol_n_2 symbol_table0.text_symbols
						  };
					| n_scnum==DATA_SECTION
						=	if (x_smclass==XMC_RW || x_smclass==XMC_RO)
								{ symbol_table0 &
									symbols     ={symbol_table0.symbols & [symbol_n_2]=
													Module {section_n=DATA_SECTION,
															module_offset=n_value,length=x_scnlen,
															first_relocation_n=0,end_relocation_n=0,
															align=x_sm_align}},
									data_symbols= SymbolIndex symbol_n_2 symbol_table0.data_symbols
					 			}
					 		(if (x_smclass==XMC_TC || x_smclass==XMC_DS)
					 			{ symbol_table0 &
									symbols     ={symbol_table0.symbols & [symbol_n_2]=
													Module {section_n=TOC_SECTION,
															module_offset=n_value,length=x_scnlen,
															first_relocation_n=0,end_relocation_n=0,
															align=x_sm_align}},
									data_symbols= SymbolIndex symbol_n_2 symbol_table0.data_symbols
					 			}
					 		(if (x_smclass==XMC_TC0)
					 			{ symbol_table0 &
									symbols     ={symbol_table0.symbols & [symbol_n_2]=
													Module {section_n=TOC_SECTION,
															module_offset=n_value,length=x_scnlen,
															first_relocation_n=0,end_relocation_n=0,
															align=x_sm_align}},
									toc0_symbol	= SymbolIndex symbol_n_2 symbol_table0.toc0_symbol
					 			}
					 			(abort "Error in symbol table")
					 		));

				symbol_table_with_label symbol_table0
					| n_scnum==TEXT_SECTION && x_smclass==XMC_PR
						= {symbol_table0 & 
							symbols     = {symbol_table0.symbols & [symbol_n_2]=
											Label {label_section_n=TEXT_SECTION,label_offset=n_value,label_module_n=x_scnlen_2}}
						  };
					| n_scnum==DATA_SECTION
						= case (x_smclass) of {
							XMC_RW
								-> {symbol_table0 &
									symbols     ={symbol_table0.symbols & [symbol_n_2]=
													Label {label_section_n=DATA_SECTION,label_offset=n_value,label_module_n=x_scnlen_2}}
						 		};
							XMC_TC
								-> symbol_table1;
							XMC_DS
								-> symbol_table1;
							XMC_TC0
								-> symbol_table1;
						};
						{
							symbol_table1
								=> {symbol_table0 &
									symbols     ={symbol_table0.symbols & [symbol_n_2]=
													Label {label_section_n=TOC_SECTION,label_offset=n_value,label_module_n=x_scnlen_2}}
						 		}
						};
					{
						x_scnlen_2 = (inc x_scnlen) >> 1;
					};
				
				symbol_table_with_common symbol_table0 n_value
					| n_scnum==BSS_SECTION && (x_smclass==XMC_BS || x_smclass==XMC_RW)
						= {symbol_table0 & 
							symbols     = {symbol_table0.symbols & [symbol_n_2]=
											Module {section_n=BSS_SECTION,
													module_offset=n_value,length=x_scnlen,
													first_relocation_n=0,end_relocation_n=0,
													align=x_sm_align}},
							bss_symbols= SymbolIndex symbol_n_2 symbol_table0.bss_symbols
						  };

				name_of_symbol :: {#Char}; // to help the typechecker
				name_of_symbol
					| first_chars==0
						= string_table % (string_table_offset,dec (first_zero_char_offset_or_max string_table string_table_offset (size string_table)));
						{
							string_table_offset = (symbol_table_string LONG (offset+4))-4;
						}
						= symbol_table_string % (offset,dec (first_zero_char_offset_or_max symbol_table_string offset (offset+8)));
					{}{
						first_chars = symbol_table_string LONG offset;
						
						first_zero_char_offset_or_max string offset max
							| offset>=max || string CHAR offset=='\0'
								= offset;
								= first_zero_char_offset_or_max string (offset+1) max;
					}

				x_sm_typ_t=x_smtyp bitand 7;
				x_sm_align=x_smtyp >> 3;
				
				x_scnlen=symbol_table_string LONG last_aux_offset;
				x_smtyp=symbol_table_string BYTE (last_aux_offset+10);
				x_smclass=symbol_table_string BYTE (last_aux_offset+11);

				last_aux_offset=offset+SIZE_OF_SYMBOL*n_numaux;
				
				n_value=symbol_table_string LONG (offset+8);
				n_scnum=symbol_table_string WORD (offset+12);
				n_numaux=symbol_table_string BYTE (offset+17);
			}
		{
			symbol_n_2 = (inc symbol_n) >> 1;
			offset=SIZE_OF_SYMBOL*symbol_n;
		}
	}


read_other_section_headers :: Int *File -> (!Bool,!*File);
read_other_section_headers n_sections file0
	| n_sections==2
		= (True,file0);
	| not (size header_string==SIZE_OF_SECTION_HEADER)
		= (False,file1);
		= read_other_section_headers (dec n_sections) file1;
	{}{
		(header_string,file1) = freads file0 SIZE_OF_SECTION_HEADER;
	}

read_xcoff_text_or_data_section_header :: String *File -> (!Bool,!Int,!Int,!Int,!Int,!Int,!*File);
read_xcoff_text_or_data_section_header section_name file0
	| (size header_string==SIZE_OF_SECTION_HEADER && header_string % (0,4)==section_name && header_string CHAR 5=='\0')
		= (True,s_relptr,s_nreloc,s_scnptr,s_size,s_vaddr,file1);{
			s_vaddr=header_string LONG 12;
			s_size=header_string LONG 16;
			s_scnptr=header_string LONG 20;
			s_relptr=header_string LONG 24;
			s_nreloc=header_string WORD 32;
		}
		= (False,0,0,0,0,0,file1);
	{}{
		(header_string,file1) = freads file0 SIZE_OF_SECTION_HEADER;
	}
	
parse_xcoff_header :: String *File -> (!Bool,!Int,!Int,!Int,!*File);
parse_xcoff_header header_string file
	# f_nscns=header_string WORD 2;
	| not (header_string WORD 0==0x01DF && f_nscns>=2)
		= error file;
	# f_symptr=header_string LONG 8;
	  f_nsyms=header_string LONG 12;
	  f_opthdr=header_string WORD 16;
	| f_opthdr==0
		= (True,f_nscns,f_symptr,f_nsyms,file);
		# (fseek_ok,file)=fseek file f_opthdr FSeekCur;
		| fseek_ok
			= (True,f_nscns,f_symptr,f_nsyms,file)
			= (error file);
	{}{		
		error file = (False,0,0,0,file);
	}

read_relocations :: !Int !Int !*File -> (!Bool,!String,!*File);
read_relocations offset n_relocations file0
	| n_relocations==0
		= (True,"",file0)
	| not fseek_ok	
		= (False,"",file1);
		= (size relocation_string==relocation_size,relocation_string,file2);
	{}{
		(relocation_string,file2) = freads file1 relocation_size;
		relocation_size=n_relocations * SIZE_OF_RELOCATION;
		(fseek_ok,file1)=fseek file0 offset FSeekSet;
	}

read_text_section :: Bool Int Int *File -> (!Bool,!*String,!*File);
read_text_section one_pass_link offset section_size file0
	| one_pass_link && section_size > 2048
		= (True,empty_section_string,file0);
		= read_section one_pass_link offset section_size file0;

read_section :: Bool Int Int *File -> (!Bool,!*String,!*File);
read_section one_pass_link offset section_size file0
	| not one_pass_link || section_size==0
		= (True,empty_section_string,file0)
	| not fseek_ok
		= (False,empty_section_string,file1);
	| size section_string==section_size
		= (True,section_string,file2);
		= (False,section_string,file2);
	{}{
		(section_string,file2) = freads file1 section_size;
		(fseek_ok,file1)=fseek file0 offset FSeekSet;
	}

open_file_and_read_xcoff_header :: !String !*Files -> (!Bool,!String,!*File,!*Files);
open_file_and_read_xcoff_header file_name files
	# (open_ok,file,files) = fopen file_name (FReadData + 0) files;
	| not open_ok
		= error ("Cannot open file \""+++file_name+++"\"") file files;
	# (header_string,file) = freads file SIZE_OF_HEADER;
	| size header_string<>SIZE_OF_HEADER
		= error ("Cannot read header of file \""+++file_name+++"\"") file files;
		= (True,header_string,file,files);
	{}{
		error error_message file files = (False,error_message,file,files);
	}

read_xcoff_file :: !String *NamesTable Bool !String !*File !*Files Int -> (![String],!*String,!*String,!*Xcoff,!*NamesTable,!*Files);
read_xcoff_file file_name names_table0 one_pass_link header_string file files1 file_n
	# (ok1,n_sections,symbol_table_offset,n_symbols,file) = parse_xcoff_header header_string file;
	| not ok1
		= error ("Not an xcoff file: \""+++file_name+++"\"") names_table0 file files1;
	#	(ok2,text_relocation_offset,n_text_relocations,text_section_offset,text_section_size,text_v_address,file)
			= read_xcoff_text_or_data_section_header ".text" file;
	| not ok2
		= error "Error in text section header" names_table0 file files1;
	#	(ok3,data_relocation_offset,n_data_relocations,data_section_offset,data_section_size,data_v_address,file)
			= read_xcoff_text_or_data_section_header ".data" file;
	| not ok3
		= error "Error in data section header" names_table0 file files1;
	#	(ok4,file)
			= read_other_section_headers n_sections file;
	| not ok4
		= error "Error in section header" names_table0 file files1;
	#	(ok5,text_section,file)
			= read_text_section one_pass_link text_section_offset text_section_size file;
	| not ok5
		= error "Error in text section" names_table0 file files1;
	#	(ok6,data_section,file)
			= read_section one_pass_link data_section_offset data_section_size file;
	| not ok6
		= error "Error in data section" names_table0 file files1;
	#	(ok7,text_relocations,file)
			= read_relocations text_relocation_offset n_text_relocations file;
	| not ok7
		= error "Error in text relocations" names_table0 file files1;
	#	(ok8,data_relocations,file)
			= read_relocations data_relocation_offset n_data_relocations file;
	| not ok8
		= error "Error in data relocations" names_table0 file files1;
	#	(ok9,symbol_table_string,string_table,file)
			= read_symbol_table symbol_table_offset n_symbols file;
	| not ok9
		= error ("Error in symbol table "+++file_name) names_table0 file files1;
		= ([],text_section,data_section,xcoff_file,names_table1,close_file file files1);
		{
			xcoff_file={header=header,symbol_table=symbol_table0,n_symbols=n_symbols_2,
						text_relocations=text_relocations,data_relocations=data_relocations,
						n_text_relocations=n_text_relocations,n_data_relocations=n_data_relocations};
			header={file_name=file_name,text_section_offset=text_section_offset,data_section_offset=data_section_offset,
					text_section_size=text_section_size,data_section_size=data_section_size,
					text_v_address=text_v_address,data_v_address=data_v_address};
			(names_table1,symbol_table0)
					=define_symbols n_symbols_2 symbol_table_string string_table names_table0 file_n;
			n_symbols_2						= (inc n_symbols) >> 1;
		}
	{	
		close_file file files1 = files2;
		{
			(_,files2)=fclose file files1;
		}

		error :: String !*NamesTable !*File *Files -> (![String],!*String,!*String,!*Xcoff,!*NamesTable,!*Files);
		error error_string names_table0 file files1
			= ([error_string],empty_section_string,empty_section_string,empty_xcoff,names_table0,close_file file files1);
	}

empty_section_string :: .String;
empty_section_string = createArray 0 ' ';

empty_xcoff ::.Xcoff;
empty_xcoff
	= {
		header=header,symbol_table=empty_symbol_table,n_symbols=0,
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

//import StdDebug;
//debug m f :== trace_n m f
debug _ f :== f
