implementation module mach_o_linker2;

import StdInt,StdBool,StdString,StdChar,StdArray,StdFile,StdClass,StdMisc;
import StdStrictLists,StdOverloadedList;

swap_bytes i :== i;
//swap_bytes i = ((i>>24) bitand 0xff) bitor ((i>>8) bitand 0xff00) bitor ((i<<8) bitand 0xff0000) bitor (i<<24);

::	*SymbolArray :== SSymbolArray;
::	SSymbolArray :== {!Symbol};

::	Symbol
	= Module !Int !Int !Int !Int !IndirectSymbol !Int !String	// section_n length virtual_address file_offset indirect_symbol n_relocations relocations
	| Label !Int !Int !Int										// section_n offset module_n
	| SectionLabel !Int !Int									// section_n offset
	| ImportLabel !String										// label_name
	| ImportedLabel !Int !Int 									// file_n symbol_n
	| ImportedLabelPlusOffset !Int !Int !Int					// file_n symbol_n offset
	| UndefinedLabel !Int
	| EmptySymbol;

::	IndirectSymbol = NoIndirectSymbol | IndirectSymbol !Int !String;

::	SymbolIndexList = SymbolIndex !Int !SymbolIndexList | EmptySymbolIndex;

::	*NamesTable :== SNamesTable;
::	SNamesTable :== {!NamesTableElement};

::	NamesTableElement
	= NamesTableElement !String !Int !Int !NamesTableElement	// symbol_name symbol_n file_n symbol_list
	| EmptyNamesTableElement;

::	LibraryList = Library !String !LibrarySymbolsList !Int !LibraryList | EmptyLibraryList;

::	LibrarySymbolsList = LibrarySymbol !String !LibrarySymbolsList | EmptyLibrarySymbolsList;

::	*Xcoff :== *SXcoff;
:: SXcoff ={
		file_name			:: !String,
		symbol_table		:: !.SSymbolTable,
		n_symbols			:: !Int
	};

::	*SymbolTable :== *SSymbolTable;
:: SSymbolTable ={
		symbols			:: !.SSymbolArray,
		text_symbols	:: !SymbolIndexList,
		data_symbols	:: !SymbolIndexList,
		bss_symbols		:: !SymbolIndexList,
		stub_symbols	:: !SymbolIndexList,
		lazy_pointer_symbols :: !SymbolIndexList,
		non_lazy_pointer_symbols :: !SymbolIndexList,
		imported_symbols:: !SymbolIndexList,
		section_symbol_ns::!.{#Int},
		section_offsets	:: !{#SectionAddressAndSymbolN}
	};

::	SectionAddressAndSymbolN = { section_address :: !Int, section_symbol_n :: !Int};

:: XcoffArray :== {#SXcoff};

n_symbols_of_xcoff_list :: !Int ![Xcoff] -> (!Int,![Xcoff]);
n_symbols_of_xcoff_list n_symbols0 []
	= (n_symbols0,[]);
n_symbols_of_xcoff_list n_symbols0 [xcoff=:{n_symbols}:xcoff_list0]
	# (n_symbols1,xcoff_list1)=n_symbols_of_xcoff_list (n_symbols0+n_symbols) xcoff_list0;
	= (n_symbols1,[xcoff:xcoff_list1]);

(FWI) infixl;
(FWI) f i = fwritei (swap_bytes i) f;

(FWS) infixl;
(FWS) f s :== fwrites s f;

(FWC) infixl;
(FWC) f c :== fwritec c f;

(FWB) infixl;
(FWB) f i :== fwritec (toChar i) f;

S_REGULAR:==0;
S_ZEROFILL:==1;
S_NON_LAZY_SYMBOL_POINTERS:==6;
S_LAZY_SYMBOL_POINTERS:==7;
S_SYMBOL_STUBS:==8;

PPC_RELOC_VANILLA:==0;
PPC_RELOC_PAIR:==1;
PPC_RELOC_BR14:==2;
PPC_RELOC_BR24:==3;
PPC_RELOC_HI16:==4;
PPC_RELOC_LO16:==5;
PPC_RELOC_HA16:==6;
PPC_RELOC_LO14:==7;
PPC_RELOC_SECTDIFF:==8;
PPC_RELOC_PB_LA_PTR:==9;
PPC_RELOC_HI16_SECTDIFF:==10;
PPC_RELOC_LO16_SECTDIFF:==11;
PPC_RELOC_HA16_SECTDIFF:==12;
PPC_RELOC_JBSR:==13;
PPC_RELOC_LO14_SECTDIFF:==14;
PPC_RELOC_LOCAL_SECTDIFF:==15;

write_mach_o_headers :: !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !*File -> *File;
write_mach_o_headers text_section_size_align_4 data_section_size_align_4 bss_section_size_align_4 stubs_section_size_align_4 lazy_pointers_section_size_align_4 non_lazy_pointers_section_size_align_4
					n_code_relocations n_data_relocations n_stub_relocations n_lazy_pointers_relocations n_non_lazy_pointers_relocations
					first_lazy_pointer_symbol_n first_non_lazy_pointer_symbol_n n_indirect_symbols
					n_exported_symbols n_undefined_symbols string_table_size file
	# file = file
			FWC '\xfe' FWC '\xed' FWC '\xfa' FWC '\xce'
			FWI CPU_TYPE_POWERPC
			FWI 0
			FWI MH_OBJECT
			FWI 3
			FWI (464+24+80)
			FWI 0;

	# text_file_offset=28+464+24+80;
	# data_file_offset=text_file_offset+text_section_size_align_4;
	# stubs_file_offset=data_file_offset+data_section_size_align_4;
	# lazy_pointers_file_offset=stubs_file_offset+stubs_section_size_align_4;
	# non_lazy_pointers_file_offset=lazy_pointers_file_offset+lazy_pointers_section_size_align_4;
	# text_relocations_file_offset=non_lazy_pointers_file_offset+non_lazy_pointers_section_size_align_4;
	# data_relocations_file_offset=text_relocations_file_offset+n_code_relocations*SIZE_OF_RELOCATION;
	# stub_relocations_file_offset=data_relocations_file_offset+n_data_relocations*SIZE_OF_RELOCATION;
	# lazy_pointers_relocations_file_offset=stub_relocations_file_offset+n_stub_relocations*SIZE_OF_RELOCATION;
	# non_lazy_pointers_relocations_file_offset=lazy_pointers_relocations_file_offset+n_lazy_pointers_relocations*SIZE_OF_RELOCATION;
	# indirect_symbol_table_file_offset=non_lazy_pointers_relocations_file_offset+n_non_lazy_pointers_relocations*SIZE_OF_RELOCATION;	
	# symbol_table_file_offset=indirect_symbol_table_file_offset+(n_indirect_symbols<<2);

	# bss_offset=text_section_size_align_4+data_section_size_align_4;
	# stubs_offset=bss_offset+bss_section_size_align_4;
	# lazy_pointers_offset=stubs_offset+stubs_section_size_align_4;
	# non_lazy_pointers_offset=lazy_pointers_offset+lazy_pointers_section_size_align_4;

	# n_symbols=n_exported_symbols+n_undefined_symbols;

	# file = file
			FWI	LC_SEGMENT
			FWI	464
			FWS "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
			FWI 0
			FWI (text_section_size_align_4+data_section_size_align_4)
			FWI 0
			FWI 0
			FWI 7
			FWI 7
			FWI 6
			FWI 0;
	# file = file
			FWS "__text\0\0\0\0\0\0\0\0\0\0"
			FWS "__TEXT\0\0\0\0\0\0\0\0\0\0"
			FWI 0
			FWI text_section_size_align_4
			FWI text_file_offset
			FWI 0
			FWI text_relocations_file_offset
			FWI n_code_relocations
			FWI (0x80000400 bitor S_REGULAR)
			FWI 0
			FWI 0;
	# file = file
			FWS "__data\0\0\0\0\0\0\0\0\0\0"
			FWS "__DATA\0\0\0\0\0\0\0\0\0\0"
			FWI text_section_size_align_4
			FWI data_section_size_align_4
			FWI data_file_offset
			FWI 0
			FWI data_relocations_file_offset
			FWI n_data_relocations
			FWI S_REGULAR
			FWI 0
			FWI 0;
	# file = file
			FWS "__bss\0\0\0\0\0\0\0\0\0\0\0"
			FWS "__DATA\0\0\0\0\0\0\0\0\0\0"
			FWI bss_offset
			FWI bss_section_size_align_4
			FWI 0
			FWI 0
			FWI 2
			FWI 0
			FWI S_ZEROFILL
			FWI 0
			FWI 0;
	# file = file
			FWS "__picsymbol_stub"
			FWS "__TEXT\0\0\0\0\0\0\0\0\0\0"
			FWI stubs_offset
			FWI stubs_section_size_align_4
			FWI stubs_file_offset
			FWI 2
			FWI stub_relocations_file_offset
			FWI n_stub_relocations
			FWI (0x80000400 bitor S_SYMBOL_STUBS)
			FWI 0
			FWI STUB_SIZE;
	# file = file
			FWS "__la_symbol_ptr\0"
			FWS "__DATA\0\0\0\0\0\0\0\0\0\0"
			FWI lazy_pointers_offset
			FWI lazy_pointers_section_size_align_4
			FWI lazy_pointers_file_offset
			FWI 2
			FWI lazy_pointers_relocations_file_offset
			FWI n_lazy_pointers_relocations
			FWI S_LAZY_SYMBOL_POINTERS
			FWI first_lazy_pointer_symbol_n
			FWI 0;
	# file = file
			FWS "__nl_symbol_ptr\0"
			FWS "__DATA\0\0\0\0\0\0\0\0\0\0"
			FWI non_lazy_pointers_offset
			FWI non_lazy_pointers_section_size_align_4
			FWI non_lazy_pointers_file_offset
			FWI 2
			FWI non_lazy_pointers_relocations_file_offset
			FWI n_non_lazy_pointers_relocations
			FWI S_NON_LAZY_SYMBOL_POINTERS
			FWI first_non_lazy_pointer_symbol_n
			FWI 0;
	# file = file
			FWI LC_SYMTAB
			FWI 24
			FWI symbol_table_file_offset
			FWI n_symbols
			FWI (symbol_table_file_offset+n_symbols*SIZE_OF_SYMBOL)
			FWI string_table_size;
	# file = file
			FWI LC_DYSYMTAB
			FWI 80
			FWI 0
			FWI 0
			FWI 0
			FWI n_exported_symbols
			FWI n_exported_symbols
			FWI n_undefined_symbols
			FWI 0
			FWI 0
			FWI 0
			FWI 0
			FWI 0
			FWI 0
			FWI indirect_symbol_table_file_offset
			FWI n_indirect_symbols
			FWI 0
			FWI 0
			FWI 0
			FWI 0;
	= file;

SIZE_OF_HEADER:==28;
SIZE_OF_SECTION_HEADER:==68;
SIZE_OF_SYMBOL:==12;
SIZE_OF_RELOCATION:==8;

TEXT_SECTION:==1;
DATA_SECTION:==2;
BSS_SECTION:==3;
STUBS_SECTION:==4;
LAZY_POINTERS_SECTION:==5;
NON_LAZY_POINTERS_SECTION:==6;

(CHAR) string i :== string.[i];

(BYTE) string i :== toInt (string.[i]);

(WORD) string i = (string BYTE i<<8) bitor (string BYTE (i+1));

(IWORD) string i
//little	= (string BYTE (i+1)<<8) bitor (string BYTE i);
	= (string BYTE i<<8) bitor (string BYTE (i+1));

(ILONG) string i
//little	= (string BYTE (i+3)<<24) bitor (string BYTE (i+2)<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE i);
	= (string BYTE i<<24) bitor (string BYTE (i+1)<<16) bitor (string BYTE (i+2)<<8) bitor (string BYTE (i+3));

(ITBYTE) string i
//little	 = (string BYTE (i+2)<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE i);
	 = (string BYTE i<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE (i+2));

SYMBOL_TABLE_SIZE:==4096;
SYMBOL_TABLE_SIZE_MASK:==4095;

create_names_table :: NamesTable;
create_names_table = createArray SYMBOL_TABLE_SIZE EmptyNamesTableElement;

insert_symbol_in_symbol_table :: !String Int Int !NamesTable -> NamesTable;
insert_symbol_in_symbol_table symbol_name symbol_n file_n names_table
	# symbol_hash=symbol_name_hash symbol_name;
	# (symbol_list,names_table) = names_table![symbol_hash];
	#! names_table=names_table;
	| symbol_in_symbol_table_list symbol_list
		= names_table;
		= { names_table & [symbol_hash] = NamesTableElement symbol_name symbol_n file_n symbol_list};
	where {
		symbol_in_symbol_table_list EmptyNamesTableElement
			= False;
		symbol_in_symbol_table_list (NamesTableElement string  _ _ symbol_table_list)
			| string==symbol_name
				= True;
				= symbol_in_symbol_table_list symbol_table_list;
	}

find_symbol_in_symbol_table :: !String !NamesTable -> (!NamesTableElement,!NamesTable);
find_symbol_in_symbol_table symbol_name names_table
	# symbol_hash=symbol_name_hash symbol_name;
	# (symbol_list,names_table) = names_table![symbol_hash];
	#! names_table=names_table;
	=	(symbol_in_symbol_table_list symbol_list,names_table);
	{
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
::	SortElement = { index::!Int, offset::!Int,size::!Int };
/*
sort_symbols :: !SymbolIndexList !SymbolArray -> (!SymbolIndexList,!SymbolArray);
sort_symbols symbols symbol_array0
	=	(array_to_list sorted_array 0,symbol_array1);
	{
		sorted_array=heap_sort n_elements array;
		(array,symbol_array1)=fill_array new_array 0 symbols symbol_array0;
		new_array=createArray n_elements {index=0,offset=0};
		n_elements=length_of_symbol_index_list symbols 0;
		
		fill_array :: *SortArray Int SymbolIndexList SymbolArray -> (!*SortArray,!SymbolArray);
		fill_array a i EmptySymbolIndex symbol_array
			= (a,symbol_array);
		fill_array a i (SymbolIndex index l) symbol_array=:{[index]=m}
			= c a i m symbol_array;
			{
				c :: *SortArray Int Symbol SymbolArray -> (!*SortArray,!SymbolArray);
				c a i (Module _ offset _ _ _ _ _) symbol_array
					= fill_array {a & [i]={index=index,offset=offset}} (inc i) l symbol_array;
			};
		
		array_to_list :: SortArray Int -> SymbolIndexList;
		array_to_list a i
			| i<n_elements
				= SymbolIndex a.[i].index (array_to_list a (inc i));
				= EmptySymbolIndex;
	}
*/

heap_sort :: Int *SortArray -> *SortArray;
heap_sort n_elements a
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
			heap_sort1 a i j max_index ir
				# (a_j,a) = a![j];
				# (a_j_1,a) = a![j1];
				#! a=a
				= heap_sort1 a_j a_j_1 a i j max_index ir;
			{
				heap_sort1 :: !SortElement !SortElement !*SortArray !Int !Int !Int !SortElement -> *SortArray;
				heap_sort1 a_j a_j_1 a i j max_index ir
				| a_j.offset < a_j_1.offset || (a_j.offset==a_j_1.offset && a_j.size<a_j_1.size)
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
				| ir.offset<a_j.offset || (ir.offset==a_j.offset && ir.size<a_j.size)
					= heap_sort_lp {a & [i] = a_j} j (inc (j+j)) max_index ir;
	   				= {a & [i] = ir};
	   		}
		}
}

length_of_symbol_index_list EmptySymbolIndex length
	= length;
length_of_symbol_index_list (SymbolIndex _ l) length
	= length_of_symbol_index_list l (inc length);

/*
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
*/

reverse_and_sort_symbols :: !SymbolIndexList !SymbolArray -> (!SymbolIndexList,!SymbolArray);
reverse_and_sort_symbols symbols symbol_array
//	| symbols_are_sorted reversed_symbols symbol_array
		= (reversed_symbols,symbol_array);
//		= sort_symbols reversed_symbols symbol_array;
//	| symbols_are_sorted sorted_symbols symbol_array1
//		= (sorted_symbols,symbol_array1);
	{}{
//		(sorted_symbols,symbol_array1) = sort_symbols reversed_symbols symbol_array;
		reversed_symbols=reverse_symbols symbols;
	}

reverse_symbols l = reverse_symbols l EmptySymbolIndex;
{
	reverse_symbols EmptySymbolIndex t = t;
	reverse_symbols (SymbolIndex i l) t = reverse_symbols l (SymbolIndex i t);
}
/*
	symbol_index_less_or_equal :: Int Int {!Symbol} -> Bool;
	symbol_index_less_or_equal i1 i2 {[i1]=m1,[i2]=m2}
		= case (m1,m2) of {
			(Module _ offset1 _ _ _ _ _,Module _ offset2 _ _ _ _ _)
				-> offset1<=offset2; 
		};
*/

sort_modules :: !*SXcoff -> .SXcoff;
sort_modules xcoff=:{symbol_table=symbol_table=:{text_symbols,data_symbols,bss_symbols,stub_symbols,lazy_pointer_symbols,non_lazy_pointer_symbols,symbols}}
	# (text_symbols,symbols)=reverse_and_sort_symbols text_symbols symbols;
	  (data_symbols,symbols)=reverse_and_sort_symbols data_symbols symbols;
	  (bss_symbols,symbols)=reverse_and_sort_symbols bss_symbols symbols;
	  (stub_symbols,symbols)=reverse_and_sort_symbols stub_symbols symbols;
	  (lazy_pointer_symbols,symbols)=reverse_and_sort_symbols lazy_pointer_symbols symbols;
	  (non_lazy_pointer_symbols,symbols)=reverse_and_sort_symbols non_lazy_pointer_symbols symbols;
	= { xcoff & symbol_table = 
		{ symbol_table &
			text_symbols=text_symbols,data_symbols=data_symbols,bss_symbols=bss_symbols,
			stub_symbols=stub_symbols,lazy_pointer_symbols=lazy_pointer_symbols,non_lazy_pointer_symbols=non_lazy_pointer_symbols,
			symbols=symbols
		}
	  };
 
read_symbol_and_string_table :: !Int !Int !Int !Int !*File -> (!Bool,!String,!String,!*File);
read_symbol_and_string_table symbol_table_offset n_symbols string_table_offset string_table_size file
	# (fseek_ok,file)=fseek file symbol_table_offset FSeekSet;
	| not fseek_ok
		= error file;
	#	symbol_table_size=n_symbols*SIZE_OF_SYMBOL;
		(symbol_table_string,file)=freads file symbol_table_size;
	| not (size symbol_table_string==symbol_table_size)
		= (False,"","",file);
	# (fseek_ok,file)=fseek file string_table_offset FSeekSet;
	| not fseek_ok
		= error file;
	# (string_table_string,file)=freads file string_table_size;
	| not (size string_table_string==string_table_size)
		= (False,"","",file);
		= (True,symbol_table_string,string_table_string,file);
	{}{
		error file=(False,"","",file);
	}

N_STAB:==0xe0;
N_PEXT:==0x10;
N_TYPE:==0x0e;
N_EXT:==0x01;

N_UNDF:==0x0;
N_ABS:==2;
N_SECT:==0xe;

:: Section = {
		section_segment_n			::!Int,
		section_virtual_address		::!Int,
		section_size				::!Int,
		section_data_offset			::!Int,
		section_relocations_offset	::!Int,
		section_n_relocations		::!Int,
		section_indirect_symbol_table_index ::!Int,
		section_stub_size			::!Int,
		section_relocations			::!String
	};

sort_module_offsets module_offsets = SortByM (\ {module_offset=x} {module_offset=y} -> x<y) module_offsets;

SortByM less_f l
	:== HdM (msort (pair l));
{
	pair [|x1,x2:xs]
		| less_f x2 x1
			= [[|x2,x1]:pair xs];
			= [[|x1,x2]:pair xs];
	pair x = [|x];

	msort [|x1,x2:xs] = msort (merge_stage [|x1,x2:xs]);
	msort x	= x;

	merge_stage [|xs1,xs2:xxs] = [mergeBy less_f xs1 xs2 : merge_stage xxs];
	merge_stage x = x;

	mergeBy less_f [|] y = y;
	mergeBy less_f f=:[|x:xs] [|] = f;
	mergeBy less_f f=:[|x:xs] s=:[|y:ys]
		| less_f y x
			= [|y:mergeBy less_f f ys];
			= [|x:mergeBy less_f xs s];
}

:: SymbolNumberAndOffset = { symbol_n::!Int, module_offset::!Int};

define_symbols :: Int Int Int String String {!Section} String Int NamesTable -> (!NamesTable,!SymbolTable);
define_symbols n_sections n_symbols n_section_symbols symbol_table_string string_table sections indirect_symbols file_n names_table
	# (names_table,symbol_table,text_module_offsets,data_module_offsets) = define_symbols_lp 0 names_table empty_symbol_table [|] [|];
	# text_module_offsets = sort_module_offsets text_module_offsets;
	# data_module_offsets = sort_module_offsets data_module_offsets;
	# n_text_module_offsets = LengthM text_module_offsets;
	# n_data_module_offsets = LengthM data_module_offsets;
//	# section_offsets=createArray n_section_symbols {section_address=0,section_symbol_n=0};
	# section_offsets=createArray (n_section_symbols+(if (n_text_module_offsets==0) 0 (n_text_module_offsets-1))+(if (n_data_module_offsets==0) 0 (n_data_module_offsets-1))) {section_address=0,section_symbol_n=0};
	# sorted_sections = heap_sort n_sections {{index=i,offset=section_virtual_address,size=section_size} \\ {section_virtual_address,section_size} <-: sections & i<-[0..]};
	# symbol_table = define_module_symbols n_symbols sorted_sections sections text_module_offsets data_module_offsets section_offsets symbol_table;
	= (names_table,symbol_table);
	{
		empty_symbol_table = {
								symbols=createArray (n_symbols+n_section_symbols) EmptySymbol,
								text_symbols=EmptySymbolIndex,data_symbols=EmptySymbolIndex,bss_symbols=EmptySymbolIndex,
								stub_symbols=EmptySymbolIndex,lazy_pointer_symbols=EmptySymbolIndex,non_lazy_pointer_symbols=EmptySymbolIndex,
								imported_symbols=EmptySymbolIndex,
								section_symbol_ns=createArray (n_sections+1) (-1),
								section_offsets={}
							 };

		define_symbols_lp :: Int NamesTable SymbolTable [!SymbolNumberAndOffset!] [!SymbolNumberAndOffset!] -> (!NamesTable,!SymbolTable,![!SymbolNumberAndOffset!],![!SymbolNumberAndOffset!]);
		define_symbols_lp symbol_n names_table symbol_table text_module_offsets data_module_offsets
			# offset=SIZE_OF_SYMBOL*symbol_n;
			| offset==size symbol_table_string
				= (names_table,symbol_table,text_module_offsets,data_module_offsets);
			# n_name = symbol_table_string ILONG offset;
			  n_type = symbol_table_string BYTE (offset+4);
			  n_sect = symbol_table_string BYTE (offset+5);
			  n_value = symbol_table_string ILONG (offset+8);
			| n_type bitand N_STAB<>0
				= define_symbols_lp_ignore symbol_n names_table symbol_table text_module_offsets data_module_offsets;
			| n_type bitand N_TYPE==N_UNDF && n_sect==0
				| n_value==0
					# name_of_symbol = string_table % (n_name,dec (first_zero_char n_name string_table));
					# symbol_table = {symbol_table & 
							symbols={symbol_table.symbols & [symbol_n]= ImportLabel name_of_symbol},
							imported_symbols= SymbolIndex symbol_n symbol_table.imported_symbols												
							};
					= define_symbols_lp (symbol_n+1) names_table symbol_table text_module_offsets data_module_offsets;
				| n_type bitand N_EXT<>0
					# name_of_symbol = string_table % (n_name,dec (first_zero_char n_name string_table));
					# names_table=insert_symbol_in_symbol_table name_of_symbol symbol_n file_n names_table;
					# symbol_table= {symbol_table &
												symbols = {symbol_table.symbols & [symbol_n]= Module BSS_SECTION n_value 0 0 NoIndirectSymbol 0 ""},
												bss_symbols = SymbolIndex symbol_n symbol_table.bss_symbols
						  					};
					= define_symbols_lp (symbol_n+1) names_table symbol_table text_module_offsets data_module_offsets;
					= abort "define_symbols_lp";
			| n_type bitand N_TYPE==N_SECT
				| n_type bitand N_EXT<>0
					# name_of_symbol = string_table % (n_name,dec (first_zero_char n_name string_table));
					# names_table=insert_symbol_in_symbol_table name_of_symbol symbol_n file_n names_table;
					# symbol_table = {symbol_table & symbols = {symbol_table.symbols & [symbol_n]=SectionLabel n_sect n_value} };
					= define_symbols_lp (symbol_n+1) names_table symbol_table text_module_offsets data_module_offsets;
					# symbol_table = {symbol_table & symbols = {symbol_table.symbols & [symbol_n]=SectionLabel n_sect n_value} };
					| string_table.[n_name]=='_' && string_table.[n_name+1]=='_'
						| string_table.[n_name+2]=='T' && string_table.[n_name+3]=='E' &&
						  string_table.[n_name+4]=='X' && string_table.[n_name+5]=='T' &&
						  string_table.[n_name+6]=='.'
//						  && trace_t (string_table % (n_name,dec (first_zero_char n_name string_table))+++" ")						
						# text_module_offsets = [|{symbol_n=symbol_n,module_offset=n_value}:text_module_offsets];
						= define_symbols_lp (symbol_n+1) names_table symbol_table text_module_offsets data_module_offsets;
						| string_table.[n_name+2]=='D' && string_table.[n_name+3]=='A' &&
						  string_table.[n_name+4]=='T' && string_table.[n_name+5]=='A' &&
						  string_table.[n_name+6]=='.'
//						  && trace_t (string_table % (n_name,dec (first_zero_char n_name string_table))+++" ")						
						# data_module_offsets = [|{symbol_n=symbol_n,module_offset=n_value}:data_module_offsets];
						= define_symbols_lp (symbol_n+1) names_table symbol_table text_module_offsets data_module_offsets;
						= define_symbols_lp (symbol_n+1) names_table symbol_table text_module_offsets data_module_offsets;
					= define_symbols_lp (symbol_n+1) names_table symbol_table text_module_offsets data_module_offsets;
			| n_type bitand N_TYPE==N_ABS
				= define_symbols_lp (symbol_n+1) names_table symbol_table text_module_offsets data_module_offsets;
//			= define_symbols_lp_ignore symbol_n names_table symbol_table;
		where {
				define_symbols_lp_ignore :: Int NamesTable SymbolTable [!SymbolNumberAndOffset!] [!SymbolNumberAndOffset!] -> (!NamesTable,!SymbolTable,![!SymbolNumberAndOffset!],![!SymbolNumberAndOffset!]);
				define_symbols_lp_ignore symbol_n names_table symbol_table text_module_offsets data_module_offsets
//					| trace_tn ("define_symbols_lp: ignored symbol "+++toString symbol_n)
//						= define_symbols_lp (symbol_n+1) names_table symbol_table text_module_offsets data_module_offsets;
						= define_symbols_lp (symbol_n+1) names_table symbol_table text_module_offsets data_module_offsets;
		}

		first_zero_char offset symbol_table_string
			| symbol_table_string CHAR offset=='\0'
				= offset;
				= first_zero_char (offset+1) symbol_table_string;

		define_module_symbols symbol_n sorted_sections sections text_module_offsets data_module_offsets section_offsets symbol_table
			= define_module_symbols 0 0 symbol_n section_offsets symbol_table;
		{
			define_module_symbols :: Int Int Int *{#SectionAddressAndSymbolN} *SSymbolTable -> .SSymbolTable;
			define_module_symbols sorted_section_n section_symbol_n symbol_n section_offsets symbol_table
				| sorted_section_n>=n_sections
					= {symbol_table & section_offsets=section_offsets};
					# section_n = sorted_sections.[sorted_section_n].index;
					# {section_segment_n,section_virtual_address,section_size,section_data_offset,section_relocations_offset,section_n_relocations,section_indirect_symbol_table_index,section_stub_size,section_relocations}
						= sections.[section_n];
					# sorted_section_n_1 = sorted_section_n+1;
					# section_offsets = {section_offsets & [section_symbol_n]={section_address=section_virtual_address,section_symbol_n=symbol_n}};
					| section_segment_n==TEXT_SECTION
						= case text_module_offsets of {
							[|]
								# symbol_table= {symbol_table &
														symbols.[symbol_n]= Module TEXT_SECTION section_size section_virtual_address section_data_offset NoIndirectSymbol section_n_relocations section_relocations,
														text_symbols = SymbolIndex symbol_n symbol_table.text_symbols,
														section_symbol_ns.[sorted_section_n_1]=symbol_n
								  					};
								-> define_module_symbols sorted_section_n_1 (section_symbol_n+1) (symbol_n+1) section_offsets symbol_table;
							_
								# (next_section_symbol_n,section_offsets) = add_section_offsets text_module_offsets section_symbol_n section_offsets;
								# n_modules = next_section_symbol_n-section_symbol_n;
								# (n_relocations_in_a_module,section_offsets) = count_relocations_in_a_text_or_data_module 0 section_n_relocations section_symbol_n next_section_symbol_n section_relocations section_virtual_address (createArray n_modules 0) section_offsets;
								# relocations_of_modules = { createArray (s*SIZE_OF_RELOCATION) '\0' \\ s<-:n_relocations_in_a_module };
								# (relocations_of_modules,section_offsets) = fill_relocations_of_text_or_data_modules 0 section_n_relocations section_symbol_n next_section_symbol_n section_relocations section_virtual_address (createArray n_modules 0) relocations_of_modules section_offsets;
								
								#! first_symbol_n = section_offsets.[section_symbol_n].section_symbol_n;
								# symbol_table= {symbol_table & section_symbol_ns.[sorted_section_n_1]=first_symbol_n };
								
								# (section_symbol_n,section_offsets,symbol_table)
										= create_module_text_section_symbols_of_section 0 section_symbol_n section_offsets symbol_table;
									with {
										create_module_text_section_symbols_of_section :: Int Int *{#SectionAddressAndSymbolN} *SSymbolTable -> (!Int,!*{#SectionAddressAndSymbolN},!*SSymbolTable);
										create_module_text_section_symbols_of_section module_n section_symbol_n section_offsets symbol_table
											| module_n==n_modules
												= (section_symbol_n,section_offsets,symbol_table);
												# ({section_address,section_symbol_n=symbol_n},section_offsets) = section_offsets![section_symbol_n];
												#! next_section_address = if (section_symbol_n+1<next_section_symbol_n) section_offsets.[section_symbol_n+1].section_address (section_virtual_address+section_size);
												# symbol_table= {symbol_table &
																		symbols.[symbol_n]= Module TEXT_SECTION (next_section_address-section_address) section_address (section_data_offset+(section_address-section_virtual_address)) NoIndirectSymbol n_relocations_in_a_module.[module_n] relocations_of_modules.[module_n],
																		text_symbols = SymbolIndex symbol_n symbol_table.text_symbols
								  								};
												= create_module_text_section_symbols_of_section (module_n+1) (section_symbol_n+1) section_offsets symbol_table;
									}
								-> define_module_symbols sorted_section_n_1 next_section_symbol_n symbol_n section_offsets symbol_table;
						  };
					| section_segment_n==DATA_SECTION
						= case data_module_offsets of {
							[|]
								# symbol_table= {symbol_table &
														symbols.[symbol_n]= Module DATA_SECTION section_size section_virtual_address section_data_offset NoIndirectSymbol section_n_relocations section_relocations,
														data_symbols = SymbolIndex symbol_n symbol_table.data_symbols,
														section_symbol_ns.[sorted_section_n_1]=symbol_n
								  					};
								-> define_module_symbols sorted_section_n_1 (section_symbol_n+1) (symbol_n+1) section_offsets symbol_table;
							_
								# (next_section_symbol_n,section_offsets) = add_section_offsets data_module_offsets section_symbol_n section_offsets;
								# n_modules = next_section_symbol_n-section_symbol_n;
								# (n_relocations_in_a_module,section_offsets) = count_relocations_in_a_text_or_data_module 0 section_n_relocations section_symbol_n next_section_symbol_n section_relocations section_virtual_address (createArray n_modules 0) section_offsets;
								# relocations_of_modules = { createArray (s*SIZE_OF_RELOCATION) '\0' \\ s<-:n_relocations_in_a_module };
								# (relocations_of_modules,section_offsets) = fill_relocations_of_text_or_data_modules 0 section_n_relocations section_symbol_n next_section_symbol_n section_relocations section_virtual_address (createArray n_modules 0) relocations_of_modules section_offsets;
								
								#! first_symbol_n = section_offsets.[section_symbol_n].section_symbol_n;
								# symbol_table= {symbol_table & section_symbol_ns.[sorted_section_n_1]=first_symbol_n };
								
								# (section_symbol_n,section_offsets,symbol_table)
										= create_module_data_section_symbols_of_section 0 section_symbol_n section_offsets symbol_table;
									with {
										create_module_data_section_symbols_of_section :: Int Int *{#SectionAddressAndSymbolN} *SSymbolTable -> (!Int,!*{#SectionAddressAndSymbolN},!*SSymbolTable);
										create_module_data_section_symbols_of_section module_n section_symbol_n section_offsets symbol_table
											| module_n==n_modules
												= (section_symbol_n,section_offsets,symbol_table);
												# ({section_address,section_symbol_n=symbol_n},section_offsets) = section_offsets![section_symbol_n];
												#! next_section_address = if (section_symbol_n+1<next_section_symbol_n) section_offsets.[section_symbol_n+1].section_address (section_virtual_address+section_size);
												# symbol_table= {symbol_table &
																		symbols.[symbol_n]= Module DATA_SECTION (next_section_address-section_address) section_address (section_data_offset+(section_address-section_virtual_address)) NoIndirectSymbol n_relocations_in_a_module.[module_n] relocations_of_modules.[module_n],
																		data_symbols = SymbolIndex symbol_n symbol_table.data_symbols
								  								};
												= create_module_data_section_symbols_of_section (module_n+1) (section_symbol_n+1) section_offsets symbol_table;
									}
								-> define_module_symbols sorted_section_n_1 next_section_symbol_n symbol_n section_offsets symbol_table;
						};
					| section_segment_n==BSS_SECTION
						# symbol_table= {symbol_table &
												symbols.[symbol_n]= Module BSS_SECTION section_size section_virtual_address section_data_offset NoIndirectSymbol section_n_relocations section_relocations,
												bss_symbols = SymbolIndex symbol_n symbol_table.bss_symbols,
												section_symbol_ns.[sorted_section_n_1]=symbol_n
						  					};
						= define_module_symbols sorted_section_n_1 (section_symbol_n+1) (symbol_n+1) section_offsets symbol_table;
					| section_segment_n==STUBS_SECTION
						# n_modules = section_size/section_stub_size;
						| n_modules==0
							# symbol_table= {symbol_table &
													symbols.[symbol_n]= Module STUBS_SECTION section_size section_virtual_address section_data_offset NoIndirectSymbol section_n_relocations section_relocations,
													stub_symbols = SymbolIndex symbol_n symbol_table.stub_symbols,
													section_symbol_ns.[sorted_section_n_1]=symbol_n
							  					};
							= define_module_symbols sorted_section_n_1 (section_symbol_n+1) (symbol_n+1) section_offsets symbol_table;
						# n_relocations_in_a_module = count_relocation_in_a_module 0 section_n_relocations section_stub_size section_relocations (createArray n_modules 0);
						# relocations_of_modules = { createArray (s*SIZE_OF_RELOCATION) '\0' \\ s<-:n_relocations_in_a_module };
						# relocations_of_modules = fill_relocations_of_modules 0 section_n_relocations section_stub_size section_relocations (createArray section_n_relocations 0) relocations_of_modules;
	
						# symbol_table= {symbol_table & section_symbol_ns.[sorted_section_n_1]=symbol_n };
						# (section_symbol_n,symbol_n,section_offsets,symbol_table)
								= create_module_stub_section_symbols_of_section 0 section_symbol_n symbol_n section_offsets symbol_table;
							with {
								create_module_stub_section_symbols_of_section :: Int Int Int *{#SectionAddressAndSymbolN} *SSymbolTable -> (!Int,!Int,!*{#SectionAddressAndSymbolN},!*SSymbolTable);
								create_module_stub_section_symbols_of_section module_n section_symbol_n symbol_n section_offsets symbol_table
									# offset=module_n*section_stub_size;
									| offset>=section_size
										= (section_symbol_n,symbol_n,section_offsets,symbol_table);
										# section_offsets = {section_offsets & [section_symbol_n]={section_address=section_virtual_address+offset,section_symbol_n=symbol_n}};
										# indirect_symbol_n = indirect_symbols ILONG ((section_indirect_symbol_table_index+module_n)<<2);
	
										# indirect_symbol_name_offset = symbol_table_string ILONG (SIZE_OF_SYMBOL*indirect_symbol_n);
										# indirect_symbol_name = string_table % (indirect_symbol_name_offset,dec (first_zero_char indirect_symbol_name_offset string_table));
										# indirect_symbol = IndirectSymbol indirect_symbol_n indirect_symbol_name;
	
										# symbol_table= {symbol_table &
																symbols.[symbol_n]= Module STUBS_SECTION section_stub_size (section_virtual_address+offset) (section_data_offset+offset) indirect_symbol n_relocations_in_a_module.[module_n] relocations_of_modules.[module_n],
																stub_symbols = SymbolIndex symbol_n symbol_table.stub_symbols
						  								};
										= create_module_stub_section_symbols_of_section (module_n+1) (section_symbol_n+1) (symbol_n+1) section_offsets symbol_table;
							}
						= define_module_symbols sorted_section_n_1 section_symbol_n symbol_n section_offsets symbol_table;
					| section_segment_n==LAZY_POINTERS_SECTION
						# n_modules = section_size>>2;
						| n_modules==0
							# symbol_table= {symbol_table &
													symbols.[symbol_n]= Module LAZY_POINTERS_SECTION section_size section_virtual_address section_data_offset NoIndirectSymbol section_n_relocations section_relocations,
													lazy_pointer_symbols = SymbolIndex symbol_n symbol_table.lazy_pointer_symbols,
													section_symbol_ns.[sorted_section_n_1]=symbol_n
							  					};
		
							= define_module_symbols sorted_section_n_1 (section_symbol_n+1) (symbol_n+1) section_offsets symbol_table;
						# n_relocations_in_a_module = count_relocation_in_a_pointer_module 0 section_n_relocations section_relocations (createArray n_modules 0);
						# relocations_of_modules = { createArray (s*SIZE_OF_RELOCATION) '\0' \\ s<-:n_relocations_in_a_module };
						# relocations_of_modules = fill_relocations_of_pointer_modules 0 section_n_relocations section_relocations (createArray section_n_relocations 0) relocations_of_modules;
	
						# symbol_table= {symbol_table & section_symbol_ns.[sorted_section_n_1]=symbol_n };
						# (section_symbol_n,symbol_n,section_offsets,symbol_table)
								= create_module_lazy_pointers_section_symbols_of_section 0 section_symbol_n symbol_n section_offsets symbol_table;
							with {
								create_module_lazy_pointers_section_symbols_of_section :: Int Int Int *{#SectionAddressAndSymbolN} *SSymbolTable -> (!Int,!Int,!*{#SectionAddressAndSymbolN},!*SSymbolTable);
								create_module_lazy_pointers_section_symbols_of_section module_n section_symbol_n symbol_n section_offsets symbol_table
									# offset=module_n<<2;
									| offset>=section_size
										= (section_symbol_n,symbol_n,section_offsets,symbol_table);
										# section_offsets = {section_offsets & [section_symbol_n]={section_address=section_virtual_address+offset,section_symbol_n=symbol_n}};
										# indirect_symbol_n = indirect_symbols ILONG ((section_indirect_symbol_table_index+module_n)<<2);
	
										# indirect_symbol_name_offset = symbol_table_string ILONG (SIZE_OF_SYMBOL*indirect_symbol_n);
										# indirect_symbol_name = string_table % (indirect_symbol_name_offset,dec (first_zero_char indirect_symbol_name_offset string_table));
										# indirect_symbol = IndirectSymbol indirect_symbol_n indirect_symbol_name;
	
										# symbol_table= {symbol_table &
																symbols.[symbol_n]= Module LAZY_POINTERS_SECTION 4 (section_virtual_address+offset) (section_data_offset+offset) indirect_symbol n_relocations_in_a_module.[module_n] relocations_of_modules.[module_n],
																lazy_pointer_symbols = SymbolIndex symbol_n symbol_table.lazy_pointer_symbols
						  								};
										= create_module_lazy_pointers_section_symbols_of_section (module_n+1) (section_symbol_n+1) (symbol_n+1) section_offsets symbol_table;
							}
						= define_module_symbols sorted_section_n_1 section_symbol_n symbol_n section_offsets symbol_table;
					| section_segment_n==NON_LAZY_POINTERS_SECTION
						# n_modules = section_size>>2;
						| n_modules==0
							# symbol_table= {symbol_table &
													symbols.[symbol_n]= Module NON_LAZY_POINTERS_SECTION section_size section_virtual_address section_data_offset NoIndirectSymbol section_n_relocations section_relocations,
													non_lazy_pointer_symbols = SymbolIndex symbol_n symbol_table.non_lazy_pointer_symbols,
													section_symbol_ns.[sorted_section_n_1]=symbol_n
							  					};
							= define_module_symbols sorted_section_n_1 (section_symbol_n+1) (symbol_n+1) section_offsets symbol_table;
						# n_relocations_in_a_module = count_relocation_in_a_pointer_module 0 section_n_relocations section_relocations (createArray n_modules 0);
						# relocations_of_modules = { createArray (s*SIZE_OF_RELOCATION) '\0' \\ s<-:n_relocations_in_a_module };
						# relocations_of_modules = fill_relocations_of_pointer_modules 0 section_n_relocations section_relocations (createArray section_n_relocations 0) relocations_of_modules;
	
						# symbol_table= {symbol_table & section_symbol_ns.[sorted_section_n_1]=symbol_n };
						# (section_symbol_n,symbol_n,section_offsets,symbol_table)
								= create_module_non_lazy_pointers_section_symbols_of_section 0 section_symbol_n symbol_n section_offsets symbol_table;
							with {
								create_module_non_lazy_pointers_section_symbols_of_section :: Int Int Int *{#SectionAddressAndSymbolN} *SSymbolTable -> (Int,Int,!*{#SectionAddressAndSymbolN},!*SSymbolTable);
								create_module_non_lazy_pointers_section_symbols_of_section module_n section_symbol_n symbol_n section_offsets symbol_table
									# offset=module_n<<2;
									| offset>=section_size
										= (section_symbol_n,symbol_n,section_offsets,symbol_table);
										# section_offsets = {section_offsets & [section_symbol_n]={section_address=section_virtual_address+offset,section_symbol_n=symbol_n}};
										# indirect_symbol_n = indirect_symbols ILONG ((section_indirect_symbol_table_index+module_n)<<2);
																			
										# indirect_symbol_name_offset = symbol_table_string ILONG (SIZE_OF_SYMBOL*indirect_symbol_n);
										# indirect_symbol_name = string_table % (indirect_symbol_name_offset,dec (first_zero_char indirect_symbol_name_offset string_table));
										# indirect_symbol = IndirectSymbol indirect_symbol_n indirect_symbol_name;
										
										# symbol_table= {symbol_table &
																symbols.[symbol_n]= Module NON_LAZY_POINTERS_SECTION 4 (section_virtual_address+offset) (section_data_offset+offset) indirect_symbol n_relocations_in_a_module.[module_n] relocations_of_modules.[module_n],
																non_lazy_pointer_symbols = SymbolIndex symbol_n symbol_table.non_lazy_pointer_symbols
						  								};
										= create_module_non_lazy_pointers_section_symbols_of_section (module_n+1) (section_symbol_n+1) (symbol_n+1) section_offsets symbol_table;
							}
						= define_module_symbols sorted_section_n_1 section_symbol_n symbol_n section_offsets symbol_table;
	
						= define_module_symbols sorted_section_n_1 (section_symbol_n+1) (symbol_n+1) section_offsets symbol_table;
			}
	}

add_section_offsets [|] section_symbol_n section_offsets
	= (section_symbol_n,section_offsets);
add_section_offsets [|{symbol_n,module_offset}:module_offsets] section_symbol_n section_offsets
	# section_offsets = {section_offsets & [section_symbol_n]={section_address=module_offset,section_symbol_n=symbol_n}};
	= add_section_offsets module_offsets (section_symbol_n+1) section_offsets;

next_relocation_address :: Int {#Char} -> (!Int,!Int);
next_relocation_address relocation_n section_relocations
	# relocation_index=relocation_n*SIZE_OF_RELOCATION;
	| section_relocations BYTE relocation_index bitand 0x80<>0 // r_scattered
		# r_kind = section_relocations BYTE relocation_index;
		# r_type=r_kind bitand 0xf;
		| r_type==PPC_RELOC_LO16_SECTDIFF || r_type==PPC_RELOC_HA16_SECTDIFF || r_type==PPC_RELOC_SECTDIFF || r_type==PPC_RELOC_LOCAL_SECTDIFF || r_type==PPC_RELOC_LO16 || r_type==PPC_RELOC_HA16
			= (section_relocations ITBYTE (relocation_index+1),2);
		| r_type==PPC_RELOC_BR24 || r_type==PPC_RELOC_BR14 || (r_type==PPC_RELOC_VANILLA && r_kind bitand 0x30==0x20)
			= (section_relocations ITBYTE (relocation_index+1),1);
			= abort "next_relocation_address";				
		# r_kind = section_relocations BYTE (relocation_index+7);
		# r_type=r_kind bitand 0xf;
		| r_type==PPC_RELOC_BR24 || r_type==PPC_RELOC_BR14 || (r_type==PPC_RELOC_VANILLA && r_kind bitand 0x60==0x40)
			= (section_relocations ILONG (relocation_index),1);
		| r_type==PPC_RELOC_LO16 || r_type==PPC_RELOC_HA16
			= (section_relocations ILONG (relocation_index),2);
			= abort "next_relocation_address";

determine_section_n :: !Int !Int !Int !{#SectionAddressAndSymbolN} -> Int;
determine_section_n begin_index end_index offset section_offsets
	| end_index-begin_index<2
		= begin_index;
	# middle_index=(begin_index+end_index)>>1;
	| offset>=section_offsets.[middle_index].section_address
		= determine_section_n middle_index end_index offset section_offsets;
		= determine_section_n begin_index middle_index offset section_offsets;

count_relocations_in_a_text_or_data_module :: Int Int Int Int {#Char} Int *{#Int} !*{#SectionAddressAndSymbolN} -> (!*{#Int},!*{#SectionAddressAndSymbolN});
count_relocations_in_a_text_or_data_module relocation_n section_n_relocations first_section_symbol_n limit_section_symbol_n section_relocations section_virtual_address n_relocations_in_a_module section_offsets
	| relocation_n==section_n_relocations
		= (n_relocations_in_a_module,section_offsets);
		# (r_address,n_relocation_entries) = next_relocation_address relocation_n section_relocations;
		#! module_index = determine_section_n first_section_symbol_n limit_section_symbol_n (section_virtual_address+r_address) section_offsets - first_section_symbol_n;
		#! n_relocations_in_module = n_relocations_in_a_module.[module_index];
		# n_relocations_in_a_module = { n_relocations_in_a_module & [module_index]=n_relocations_in_module+n_relocation_entries};
		= count_relocations_in_a_text_or_data_module (relocation_n+n_relocation_entries) section_n_relocations first_section_symbol_n limit_section_symbol_n section_relocations section_virtual_address n_relocations_in_a_module section_offsets;

count_relocation_in_a_module :: Int Int Int {#Char} *{#Int} -> *{#Int};
count_relocation_in_a_module relocation_n section_n_relocations section_stub_size section_relocations n_relocations_in_a_module
	| relocation_n==section_n_relocations
		= n_relocations_in_a_module;
		# (r_address,n_relocation_entries) = next_relocation_address relocation_n section_relocations;
		# module_index=r_address/section_stub_size;
		#! n_relocations_in_module = n_relocations_in_a_module.[module_index];
		# n_relocations_in_a_module = { n_relocations_in_a_module & [module_index]=n_relocations_in_module+n_relocation_entries};
		= count_relocation_in_a_module (relocation_n+n_relocation_entries) section_n_relocations section_stub_size section_relocations n_relocations_in_a_module;

count_relocation_in_a_pointer_module :: Int Int {#Char} *{#Int} -> *{#Int};
count_relocation_in_a_pointer_module relocation_n section_n_relocations section_relocations n_relocations_in_a_module
	| relocation_n==section_n_relocations
		= n_relocations_in_a_module;
		# (r_address,n_relocation_entries) = next_relocation_address relocation_n section_relocations;
		# module_index=r_address>>2;
		#! n_relocations_in_module = n_relocations_in_a_module.[module_index];
		# n_relocations_in_a_module = { n_relocations_in_a_module & [module_index]=n_relocations_in_module+n_relocation_entries};
		= count_relocation_in_a_pointer_module (relocation_n+n_relocation_entries) section_n_relocations section_relocations n_relocations_in_a_module;

copy_scattered_relocation module_index next_relocation_offset relocation_index r_address section_relocations relocations_of_modules
	= {relocations_of_modules &
		[module_index].[next_relocation_offset] = section_relocations.[relocation_index],
		[module_index].[next_relocation_offset+1] = toChar (r_address>>16),
		[module_index].[next_relocation_offset+2] = toChar (r_address>>8),
		[module_index].[next_relocation_offset+3] = toChar r_address,
		[module_index].[next_relocation_offset+4] = section_relocations.[relocation_index+4],
		[module_index].[next_relocation_offset+5] = section_relocations.[relocation_index+5],
		[module_index].[next_relocation_offset+6] = section_relocations.[relocation_index+6],
		[module_index].[next_relocation_offset+7] = section_relocations.[relocation_index+7]
	};

copy_scattered_relocation_with_pair module_index next_relocation_offset relocation_index r_address section_relocations relocations_of_modules
	= {relocations_of_modules &
		[module_index].[next_relocation_offset] = section_relocations.[relocation_index],
		[module_index].[next_relocation_offset+1] = toChar (r_address>>16),
		[module_index].[next_relocation_offset+2] = toChar (r_address>>8),
		[module_index].[next_relocation_offset+3] = toChar r_address,
		[module_index].[next_relocation_offset+4] = section_relocations.[relocation_index+4],
		[module_index].[next_relocation_offset+5] = section_relocations.[relocation_index+5],
		[module_index].[next_relocation_offset+6] = section_relocations.[relocation_index+6],
		[module_index].[next_relocation_offset+7] = section_relocations.[relocation_index+7],
		[module_index].[next_relocation_offset+8] = section_relocations.[relocation_index+8],
		[module_index].[next_relocation_offset+9] = section_relocations.[relocation_index+9],
		[module_index].[next_relocation_offset+10] = section_relocations.[relocation_index+10],
		[module_index].[next_relocation_offset+11] = section_relocations.[relocation_index+11],
		[module_index].[next_relocation_offset+12] = section_relocations.[relocation_index+12],
		[module_index].[next_relocation_offset+13] = section_relocations.[relocation_index+13],
		[module_index].[next_relocation_offset+14] = section_relocations.[relocation_index+14],
		[module_index].[next_relocation_offset+15] = section_relocations.[relocation_index+15]
	};

copy_relocation module_index next_relocation_offset relocation_index r_address section_relocations relocations_of_modules
	= {relocations_of_modules &
		[module_index].[next_relocation_offset] = toChar (r_address>>24),
		[module_index].[next_relocation_offset+1] = toChar (r_address>>16),
		[module_index].[next_relocation_offset+2] = toChar (r_address>>8),
		[module_index].[next_relocation_offset+3] = toChar r_address,
		[module_index].[next_relocation_offset+4] = section_relocations.[relocation_index+4],
		[module_index].[next_relocation_offset+5] = section_relocations.[relocation_index+5],
		[module_index].[next_relocation_offset+6] = section_relocations.[relocation_index+6],
		[module_index].[next_relocation_offset+7] = section_relocations.[relocation_index+7]
	};

copy_relocation_with_pair module_index next_relocation_offset relocation_index r_address section_relocations relocations_of_modules
	= {relocations_of_modules &
		[module_index].[next_relocation_offset] = toChar (r_address>>24),
		[module_index].[next_relocation_offset+1] = toChar (r_address>>16),
		[module_index].[next_relocation_offset+2] = toChar (r_address>>8),
		[module_index].[next_relocation_offset+3] = toChar r_address,
		[module_index].[next_relocation_offset+4] = section_relocations.[relocation_index+4],
		[module_index].[next_relocation_offset+5] = section_relocations.[relocation_index+5],
		[module_index].[next_relocation_offset+6] = section_relocations.[relocation_index+6],
		[module_index].[next_relocation_offset+7] = section_relocations.[relocation_index+7],
		[module_index].[next_relocation_offset+8] = section_relocations.[relocation_index+8],
		[module_index].[next_relocation_offset+9] = section_relocations.[relocation_index+9],
		[module_index].[next_relocation_offset+10] = section_relocations.[relocation_index+10],
		[module_index].[next_relocation_offset+11] = section_relocations.[relocation_index+11],
		[module_index].[next_relocation_offset+12] = section_relocations.[relocation_index+12],
		[module_index].[next_relocation_offset+13] = section_relocations.[relocation_index+13],
		[module_index].[next_relocation_offset+14] = section_relocations.[relocation_index+14],
		[module_index].[next_relocation_offset+15] = section_relocations.[relocation_index+15]
	};

determine_module_index_and_new_r_address :: Int Int Int Int *{#SectionAddressAndSymbolN} -> (!Int,!Int,!*{#SectionAddressAndSymbolN});
determine_module_index_and_new_r_address r_address first_section_symbol_n limit_section_symbol_n section_virtual_address section_offsets
	#! section_n = determine_section_n first_section_symbol_n limit_section_symbol_n (section_virtual_address+r_address) section_offsets
	#! section_address=section_offsets.[section_n].section_address
	= (section_n - first_section_symbol_n,r_address-(section_address-section_virtual_address),section_offsets);

fill_relocations_of_text_or_data_modules :: Int Int Int Int {#Char} Int *{#Int} *{#*{#Char}} *{#SectionAddressAndSymbolN} -> (!*{#*{#Char}},!*{#SectionAddressAndSymbolN});
fill_relocations_of_text_or_data_modules relocation_n section_n_relocations first_section_symbol_n limit_section_symbol_n section_relocations section_virtual_address next_relocation_offsets relocations_of_modules section_offsets
	| relocation_n==section_n_relocations
		= (relocations_of_modules,section_offsets);
		# relocation_index=relocation_n*SIZE_OF_RELOCATION;
		| section_relocations BYTE relocation_index bitand 0x80<>0 // r_scattered
			# r_kind = section_relocations BYTE relocation_index;
			# r_type=r_kind bitand 0xf;
			| r_type==PPC_RELOC_LO16_SECTDIFF || r_type==PPC_RELOC_HA16_SECTDIFF || r_type==PPC_RELOC_SECTDIFF || r_type==PPC_RELOC_LOCAL_SECTDIFF || r_type==PPC_RELOC_LO16 || r_type==PPC_RELOC_HA16
				# r_address = section_relocations ITBYTE (relocation_index+1);
				# (module_index,r_address,section_offsets) = determine_module_index_and_new_r_address r_address first_section_symbol_n limit_section_symbol_n section_virtual_address section_offsets;
				#! next_relocation_offset = next_relocation_offsets.[module_index];				
				# next_relocation_offsets = { next_relocation_offsets & [module_index]=next_relocation_offset+(SIZE_OF_RELOCATION<<1)};
				# relocations_of_modules = copy_scattered_relocation_with_pair module_index next_relocation_offset relocation_index r_address section_relocations relocations_of_modules;
				= fill_relocations_of_text_or_data_modules (relocation_n+2) section_n_relocations first_section_symbol_n limit_section_symbol_n section_relocations section_virtual_address next_relocation_offsets relocations_of_modules section_offsets
			| r_type==PPC_RELOC_BR24 || r_type==PPC_RELOC_BR14 || (r_type==PPC_RELOC_VANILLA && r_kind bitand 0x30==0x20)
				# r_address = section_relocations ITBYTE (relocation_index+1);
				# (module_index,r_address,section_offsets) = determine_module_index_and_new_r_address r_address first_section_symbol_n limit_section_symbol_n section_virtual_address section_offsets;
				#! next_relocation_offset = next_relocation_offsets.[module_index];				
				# next_relocation_offsets = { next_relocation_offsets & [module_index]=next_relocation_offset+SIZE_OF_RELOCATION};
				# relocations_of_modules = copy_scattered_relocation module_index next_relocation_offset relocation_index r_address section_relocations relocations_of_modules;
				= fill_relocations_of_text_or_data_modules (relocation_n+1) section_n_relocations first_section_symbol_n limit_section_symbol_n section_relocations section_virtual_address next_relocation_offsets relocations_of_modules section_offsets
				= abort "fill_relocations_of_text_or_data_modules";				
			# r_kind = section_relocations BYTE (relocation_index+7);
			# r_type=r_kind bitand 0xf;
			| r_type==PPC_RELOC_BR24 || r_type==PPC_RELOC_BR14 || (r_type==PPC_RELOC_VANILLA && r_kind bitand 0x60==0x40)
				# r_address=section_relocations ILONG (relocation_index);
				# (module_index,r_address,section_offsets) = determine_module_index_and_new_r_address r_address first_section_symbol_n limit_section_symbol_n section_virtual_address section_offsets;				
				#! next_relocation_offset = next_relocation_offsets.[module_index];
				# next_relocation_offsets = { next_relocation_offsets & [module_index]=next_relocation_offset+SIZE_OF_RELOCATION};
				# relocations_of_modules = copy_relocation module_index next_relocation_offset relocation_index r_address section_relocations relocations_of_modules;
				= fill_relocations_of_text_or_data_modules (relocation_n+1) section_n_relocations first_section_symbol_n limit_section_symbol_n section_relocations section_virtual_address next_relocation_offsets relocations_of_modules section_offsets
			| r_type==PPC_RELOC_LO16 || r_type==PPC_RELOC_HA16
				# r_address=section_relocations ILONG (relocation_index);
				# (module_index,r_address,section_offsets) = determine_module_index_and_new_r_address r_address first_section_symbol_n limit_section_symbol_n section_virtual_address section_offsets;				
				#! next_relocation_offset = next_relocation_offsets.[module_index];
				# next_relocation_offsets = { next_relocation_offsets & [module_index]=next_relocation_offset+(SIZE_OF_RELOCATION<<1)};
				# relocations_of_modules = copy_relocation_with_pair module_index next_relocation_offset relocation_index r_address section_relocations relocations_of_modules;
				= fill_relocations_of_text_or_data_modules (relocation_n+2) section_n_relocations first_section_symbol_n limit_section_symbol_n section_relocations section_virtual_address next_relocation_offsets relocations_of_modules section_offsets
				= abort "fill_relocations_of_text_or_data_modules";

fill_relocations_of_modules :: Int Int Int {#Char} *{#Int} *{#*{#Char}} -> *{#*{#Char}};
fill_relocations_of_modules relocation_n section_n_relocations section_stub_size section_relocations next_relocation_offsets relocations_of_modules
	| relocation_n==section_n_relocations
		= relocations_of_modules;
		# relocation_index=relocation_n*SIZE_OF_RELOCATION;
		| section_relocations BYTE relocation_index bitand 0x80<>0 // r_scattered
			# r_kind = section_relocations BYTE relocation_index;
			# r_type=r_kind bitand 0xf;
			| r_type==PPC_RELOC_LO16_SECTDIFF || r_type==PPC_RELOC_HA16_SECTDIFF || r_type==PPC_RELOC_SECTDIFF || r_type==PPC_RELOC_LOCAL_SECTDIFF
				# r_address = section_relocations ITBYTE (relocation_index+1);
				# module_index=r_address/section_stub_size;
				# r_address=r_address-module_index*section_stub_size;
				# (next_relocation_offset,next_relocation_offsets) = next_relocation_offsets![module_index];				
				# relocations_of_modules = copy_scattered_relocation_with_pair module_index next_relocation_offset relocation_index r_address section_relocations relocations_of_modules;
				# next_relocation_offsets = { next_relocation_offsets & [module_index]=next_relocation_offset+(SIZE_OF_RELOCATION<<1)};
				= fill_relocations_of_modules (relocation_n+2) section_n_relocations section_stub_size section_relocations next_relocation_offsets relocations_of_modules;
				= abort "fill_relocations_of_modules";
			# r_kind = section_relocations BYTE (relocation_index+7);
			# r_type=r_kind bitand 0xf;
			| r_type==PPC_RELOC_BR24 || (r_type==PPC_RELOC_VANILLA && r_kind bitand 0x60==0x40)
				# r_address=section_relocations ILONG (relocation_index);
				# module_index=r_address/section_stub_size;
				# r_address=r_address-module_index*section_stub_size;
				# (next_relocation_offset,next_relocation_offsets) = next_relocation_offsets![module_index];
				# relocations_of_modules = copy_relocation module_index next_relocation_offset relocation_index r_address section_relocations relocations_of_modules;
				# next_relocation_offsets = { next_relocation_offsets & [module_index]=next_relocation_offset+SIZE_OF_RELOCATION};
				= fill_relocations_of_modules (relocation_n+1) section_n_relocations section_stub_size section_relocations next_relocation_offsets relocations_of_modules;
				= abort "fill_relocations_of_modules";

fill_relocations_of_pointer_modules :: Int Int {#Char} *{#Int} *{#*{#Char}} -> *{#*{#Char}};
fill_relocations_of_pointer_modules relocation_n section_n_relocations section_relocations next_relocation_offsets relocations_of_modules
	| relocation_n==section_n_relocations
		= relocations_of_modules;
		# relocation_index=relocation_n*SIZE_OF_RELOCATION;
		| section_relocations BYTE relocation_index bitand 0x80<>0 // r_scattered
			# r_kind = section_relocations BYTE relocation_index;
			# r_type=r_kind bitand 0xf;
			| r_type==PPC_RELOC_LO16_SECTDIFF || r_type==PPC_RELOC_HA16_SECTDIFF || r_type==PPC_RELOC_SECTDIFF || r_type==PPC_RELOC_LOCAL_SECTDIFF
				# r_address = section_relocations ITBYTE (relocation_index+1);
				# module_index=r_address>>2;
				# r_address=r_address-(module_index<<2);
				# (next_relocation_offset,next_relocation_offsets) = next_relocation_offsets![module_index];
				# relocations_of_modules = copy_scattered_relocation_with_pair module_index next_relocation_offset relocation_index r_address section_relocations relocations_of_modules;
				# next_relocation_offsets = { next_relocation_offsets & [module_index]=next_relocation_offset+(SIZE_OF_RELOCATION<<1)};
				= fill_relocations_of_pointer_modules (relocation_n+2) section_n_relocations section_relocations next_relocation_offsets relocations_of_modules;
				= abort "fill_relocations_of_pointer_modules";
			# r_kind = section_relocations BYTE (relocation_index+7);
			# r_type=r_kind bitand 0xf;
			| r_type==PPC_RELOC_BR24 || (r_type==PPC_RELOC_VANILLA && r_kind bitand 0x60==0x40)
				# r_address=section_relocations ILONG (relocation_index);
				# module_index=r_address>>2;
				# r_address=r_address-(module_index<<2);
				# (next_relocation_offset,next_relocation_offsets) = next_relocation_offsets![module_index];
				# relocations_of_modules = copy_relocation module_index next_relocation_offset relocation_index r_address section_relocations relocations_of_modules;
				# next_relocation_offsets = { next_relocation_offsets & [module_index]=next_relocation_offset+SIZE_OF_RELOCATION};
				= fill_relocations_of_pointer_modules (relocation_n+1) section_n_relocations section_relocations next_relocation_offsets relocations_of_modules;
				= abort "fill_relocations_of_pointer_modules";

MH_OBJECT:==1;

CPU_TYPE_POWERPC:==18;

read_mach_o_header :: *File -> (!Bool,!Int,!Int,!Int,*File);
read_mach_o_header file
	# (header_string,file) = freads file SIZE_OF_HEADER;
	| not (size header_string==SIZE_OF_HEADER && header_string.[0]=='\xfe' && header_string.[1]=='\xed' && header_string.[2]=='\xfa' && header_string.[3]=='\xce')
		= error file;
	# cputype	= header_string ILONG 4;
//	# cpusubtype= header_string ILONG 8;
    # filetype	= header_string ILONG 12;
    | not (cputype==CPU_TYPE_POWERPC && filetype==MH_OBJECT)
    	= error file;
	# ncmds		= header_string ILONG 16;
	# sizeofcmds= header_string ILONG 20;
	# flags		= header_string ILONG 24;
	= (True,ncmds,sizeofcmds,flags,file);
	{}{
		error file = (False,0,0,0,file);
	}

LC_SEGMENT:==1;
LC_SYMTAB:==2;
LC_DYSYMTAB:==11;

read_load_commands 0 segment_command symtab_command dysymtab_command file
	= (True,segment_command,symtab_command,dysymtab_command,file);
read_load_commands ncmds segment_command symtab_command dysymtab_command file
	# (ok,cmd,file) = freadi file;
	| not ok
		= (False,segment_command,symtab_command,dysymtab_command,file);
	# (ok,cmd_size,file) = freadi file;
	# cmd_size=cmd_size-8;
	| not ok || cmd_size<0
		= (False,segment_command,symtab_command,dysymtab_command,file);
	# (command_string,file) = freads file cmd_size;
	| size command_string<>cmd_size
		= (False,segment_command,symtab_command,dysymtab_command,file);
	| cmd==LC_SEGMENT
		| size segment_command==0
			= read_load_commands (ncmds-1) command_string symtab_command dysymtab_command file;
			= (False,segment_command,symtab_command,dysymtab_command,file);
	| cmd==LC_SYMTAB
		| size symtab_command==0
			= read_load_commands (ncmds-1) segment_command command_string dysymtab_command file;
			= (False,segment_command,symtab_command,dysymtab_command,file);
	| cmd==LC_DYSYMTAB
		| size dysymtab_command==0
			= read_load_commands (ncmds-1) segment_command symtab_command command_string file;
			= (False,segment_command,symtab_command,dysymtab_command,file);
		= read_load_commands (ncmds-1) segment_command symtab_command dysymtab_command file;

parse_section_headers :: Int Int Int {#Char} *{!Section} -> (!Bool,!Int,!*{!Section});
parse_section_headers section_n n_section_symbols n_sections segment_command sections
	| section_n>=n_sections
		= (True,n_section_symbols,sections);
	# section_offset=48+section_n*SIZE_OF_SECTION_HEADER;

	# segname_offset=section_offset+16;
	| segment_command.[segname_offset  ]=='_' && segment_command.[segname_offset+1]=='_' && segment_command.[segname_offset+2]=='T' &&
	  segment_command.[segname_offset+3]=='E' && segment_command.[segname_offset+4]=='X' && segment_command.[segname_offset+5]=='T' && 
	  segment_command.[segname_offset+6]=='\0'
		# addr=segment_command ILONG (section_offset+32);
		  size=segment_command ILONG (section_offset+36);
		  offset=segment_command ILONG (section_offset+40);
//		  align=segment_command ILONG (section_offset+44);
		  reloff=segment_command ILONG (section_offset+48);
		  nreloc=segment_command ILONG (section_offset+52);
		  flags=segment_command ILONG (section_offset+56);
		| flags bitand 0xff==S_SYMBOL_STUBS
		 	# reserved1=segment_command ILONG (section_offset+60);
		 	# reserved2=segment_command ILONG (section_offset+64);
			# new_section= {	section_segment_n=STUBS_SECTION,section_virtual_address=addr,section_size=size,
								section_data_offset=offset,section_relocations_offset=reloff,section_n_relocations=nreloc,
								section_indirect_symbol_table_index=reserved1,section_stub_size=reserved2,section_relocations=""
						  };
			| size<=reserved2
				= parse_section_headers (section_n+1) (n_section_symbols+1) n_sections segment_command {sections & [section_n]=new_section };
				= parse_section_headers (section_n+1) (n_section_symbols+size/reserved2) n_sections segment_command {sections & [section_n]=new_section };

			# new_section= {	section_segment_n=TEXT_SECTION,section_virtual_address=addr,section_size=size,
								section_data_offset=offset,section_relocations_offset=reloff,section_n_relocations=nreloc,
								section_indirect_symbol_table_index=(-1),section_stub_size=0,section_relocations=""
						  };
			= parse_section_headers (section_n+1) (n_section_symbols+1) n_sections segment_command {sections & [section_n]=new_section };;

	| segment_command.[segname_offset  ]=='_' && segment_command.[segname_offset+1]=='_' && segment_command.[segname_offset+2]=='D' &&
	  segment_command.[segname_offset+3]=='A' && segment_command.[segname_offset+4]=='T' && segment_command.[segname_offset+5]=='A' && 
	  segment_command.[segname_offset+6]=='\0' 
		# addr=segment_command ILONG (section_offset+32);
		  size=segment_command ILONG (section_offset+36);
		  offset=segment_command ILONG (section_offset+40);
//		  align=segment_command ILONG (section_offset+44);
		  reloff=segment_command ILONG (section_offset+48);
		  nreloc=segment_command ILONG (section_offset+52);
		  flags=segment_command ILONG (section_offset+56);
		| flags bitand 0xff==S_LAZY_SYMBOL_POINTERS
		 	# reserved1=segment_command ILONG (section_offset+60);
			# new_section= {	section_segment_n=LAZY_POINTERS_SECTION,section_virtual_address=addr,section_size=size,
								section_data_offset=offset,section_relocations_offset=reloff,section_n_relocations=nreloc,
								section_indirect_symbol_table_index=reserved1,section_stub_size=0,section_relocations=""
						  };
			| size<=4
				= parse_section_headers (section_n+1) (n_section_symbols+1) n_sections segment_command {sections & [section_n]=new_section };
				= parse_section_headers (section_n+1) (n_section_symbols+(size>>2)) n_sections segment_command {sections & [section_n]=new_section };

		| flags bitand 0xff==S_NON_LAZY_SYMBOL_POINTERS
		 	# reserved1=segment_command ILONG (section_offset+60);
			# new_section= {	section_segment_n=NON_LAZY_POINTERS_SECTION,section_virtual_address=addr,section_size=size,
								section_data_offset=offset,section_relocations_offset=reloff,section_n_relocations=nreloc,
								section_indirect_symbol_table_index=reserved1,section_stub_size=0,section_relocations=""
						  };
			| size<=4
				= parse_section_headers (section_n+1) (n_section_symbols+1) n_sections segment_command {sections & [section_n]=new_section };
				= parse_section_headers (section_n+1) (n_section_symbols+(size>>2)) n_sections segment_command {sections & [section_n]=new_section };

		| flags bitand 0xff==S_ZEROFILL
			# new_section= {	section_segment_n=BSS_SECTION,section_virtual_address=addr,section_size=size,
								section_data_offset=offset,section_relocations_offset=reloff,section_n_relocations=nreloc,
								section_indirect_symbol_table_index=(-1),section_stub_size=0,section_relocations=""
						  };
			= parse_section_headers (section_n+1) (n_section_symbols+1) n_sections segment_command {sections & [section_n]=new_section };

			# new_section= {	section_segment_n=DATA_SECTION,section_virtual_address=addr,section_size=size,
								section_data_offset=offset,section_relocations_offset=reloff,section_n_relocations=nreloc,
								section_indirect_symbol_table_index=(-1),section_stub_size=0,section_relocations=""
						  };
			= parse_section_headers (section_n+1) (n_section_symbols+1) n_sections segment_command {sections & [section_n]=new_section };
	
		= parse_section_headers (section_n+1) (n_section_symbols+1) n_sections segment_command sections;

read_relocations section_n n_sections sections file
	| section_n>=n_sections
		= (True,sections,file);
	| sections.[section_n].section_n_relocations<=0
		= read_relocations (section_n+1) n_sections sections file;
	# (sections_section_n,sections) = sections![section_n];
	  (fseek_ok,file)=fseek file sections_section_n.section_relocations_offset FSeekSet;
	| not fseek_ok
		= (False,sections,file);
	# relocation_size=sections_section_n.section_n_relocations * SIZE_OF_RELOCATION;
	  (relocation_string,file) = freads file relocation_size;
	| size relocation_string<>relocation_size
		= (False,sections,file);
		= read_relocations (section_n+1) n_sections {sections & [section_n]={sections_section_n & section_relocations=relocation_string} } file;

read_indirect_symbols indirectsymoff 0 file
	= (True,"",file);
read_indirect_symbols indirectsymoff nindirectsyms file
	# (fseek_ok,file)=fseek file indirectsymoff FSeekSet;
	| not fseek_ok
		= (False,"",file);
	# indirect_symbols_size = nindirectsyms<<2;
	# (indirect_symbols,file) = freads file indirect_symbols_size;
	| size indirect_symbols<>indirect_symbols_size
		= (False,"",file);
		= (True,indirect_symbols,file);

read_mach_o_file :: !String NamesTable Bool !Files Int -> (![String],!*String,!*String,!Xcoff,!NamesTable,!Files);
read_mach_o_file file_name names_table0 one_pass_link files file_n
	# (ok,file,files) = fopen file_name FReadData files;
	| not ok
		= error ("Cannot open file \""+++file_name+++"\"") file files;
	# (ok,ncmds,sizeofcmds,header_flags,file) = read_mach_o_header file;
	| not ok
		= error ("Not a Mach-O file: \""+++file_name+++"\"") file files;
	# (ok,segment_command,symtab_command,dysymtab_command,file) = read_load_commands ncmds "" "" "" file;
	| not ok || size segment_command<48 || size symtab_command<>16 || size dysymtab_command==0
		= error ("Error in load command of Mach-O file: \""+++file_name+++"\"") file files;
		
	# n_sections=segment_command ILONG 40;
	# sections = createArray n_sections {	section_segment_n= -1,section_virtual_address=0,section_size= -1,
											section_data_offset=0,section_relocations_offset=0,section_n_relocations=0,
											section_indirect_symbol_table_index=(-1),section_stub_size=0,section_relocations=""
										  };
	# (ok,n_section_symbols,sections) = parse_section_headers 0 0 n_sections segment_command sections;
	| not ok
		= error "Error in section header" file files;
	# (ok,sections,file) = read_relocations 0 n_sections sections file;
	| not ok
		= error "Error in relocations" file files;

	# indirectsymoff = dysymtab_command ILONG 48;
	# nindirectsyms = dysymtab_command ILONG 52;
	# (ok,indirect_symbols,file) = read_indirect_symbols indirectsymoff nindirectsyms file;
	| not ok
		= error "Error in indirect symbol table" file files;

	# text_section = {};
	  data_section = {};

	# n_symbols=symtab_command ILONG 4;
	  symbol_table_offset=symtab_command ILONG 0;
	  string_table_size=symtab_command ILONG 12;
	  string_table_offset=symtab_command ILONG 8;

	  (ok,symbol_table_string,string_table,file) = read_symbol_and_string_table symbol_table_offset n_symbols string_table_offset string_table_size file;
	| not ok
		= error ("Error in symbol table "+++file_name) file files;
		# (names_table1,symbol_table0)
				= define_symbols n_sections n_symbols n_section_symbols symbol_table_string string_table sections indirect_symbols file_n names_table0;
		  xcoff_file={file_name=file_name,symbol_table=symbol_table0,n_symbols=n_symbols+n_section_symbols };
		= ([],text_section,data_section,xcoff_file,names_table1,close_file file files);
	{}{
		close_file file files
			# (_,files2)=fclose file files;
			= files2;

		error :: String !*File !*Files -> (![String],!*String,!*String,!Xcoff,!NamesTable,!Files);
		error error_string file files
			= ([error_string],empty_section_string,empty_section_string,empty_xcoff,names_table0,close_file file files);
	}

empty_section_string :: .String;
empty_section_string = createArray 0 ' ';

empty_xcoff ::.SXcoff;
empty_xcoff
	= { file_name="",symbol_table=empty_symbol_table,n_symbols=0 };
	{
		empty_symbol_table = {
			symbols={},text_symbols=EmptySymbolIndex,data_symbols=EmptySymbolIndex,bss_symbols=EmptySymbolIndex,
			stub_symbols=EmptySymbolIndex,lazy_pointer_symbols=EmptySymbolIndex,non_lazy_pointer_symbols=EmptySymbolIndex,imported_symbols=EmptySymbolIndex,
			section_symbol_ns={},section_offsets={}
		};
	};
