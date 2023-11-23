implementation module elf_linker2;

import StdInt,StdBool,StdString,StdChar,StdArray,StdFile,StdClass,StdMisc;
import elf_linker_types,elf_relocations;

swap_bytes i :== i;
//swap_bytes i = ((i>>24) bitand 0xff) bitor ((i>>8) bitand 0xff00) bitor ((i<<8) bitand 0xff0000) bitor (i<<24);

::	*NamesTable :== SNamesTable;
::	SNamesTable :== {!NamesTableElement};

::	NamesTableElement
	= NamesTableElement !String !Int !Int !NamesTableElement	// symbol_name symbol_n file_n symbol_list
	| EmptyNamesTableElement;

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

write_elf_headers :: !Int !Int !Int !Int !Int !Int !Int !*File -> *File;
write_elf_headers text_section_size data_section_size bss_section_size n_code_relocations n_data_relocations n_symbols string_table_size file
	#	file = write_elf_header file;

		file = file
			FWI 0
			FWI 0
			FWP 0
			FWP 0
			FWP 0
			FWP 0
			FWI 0
			FWI 0
			FWP 0
			FWP 0;
		offset = SIZE_OF_HEADER + 9 * SIZE_OF_SECTION_HEADER;

		file = file
			FWI 1
			FWI SHT_STRTAB
			FWP 0
			FWP 0
			FWP offset
			FWP shstrtab_size
			FWI 0
			FWI 0
			FWP 1
			FWP 0;
		offset=offset+shstrtab_size;

		file=file
			FWI 11
			FWI SHT_PROGBITS
			FWP (SHF_ALLOC bitor SHF_EXECINSTR)
			FWP 0
			FWP offset
			FWP text_section_size
			FWI 0
			FWI 0
			FWP 8 // 4
			FWP 0;
		offset=offset+(text_section_size+3 ) bitand -4;

		file=file
			FWI 17
			FWI SHT_PROGBITS
			FWP (SHF_ALLOC bitor SHF_WRITE)
			FWP 0
			FWP offset
			FWP data_section_size
			FWI 0
			FWI 0
			FWP DATA_SECTION_ALIGN
			FWP 0;
		offset=offset+(data_section_size+3) bitand -4;

		file=file
			FWI 23
			FWI SHT_NOBITS
			FWP (SHF_ALLOC bitor SHF_WRITE)
			FWP 0
			FWP offset
			FWP bss_section_size
			FWI 0
			FWI 0
			FWP 32
			FWP 0;

		file=file
			FWI 28
			FWI SHT_relocations
			FWP 0
			FWP 0
			FWP offset
			FWP (SIZE_OF_RELOCATION*n_code_relocations)
			FWI 7
			FWI 2
			FWP 4
			FWP SIZE_OF_RELOCATION;
		offset=offset+SIZE_OF_RELOCATION*n_code_relocations;

		file=file
			FWI shstrtab_data_relocations_section_name_offset
			FWI SHT_relocations
			FWP 0
			FWP 0
			FWP offset
			FWP (SIZE_OF_RELOCATION*n_data_relocations)
			FWI 7
			FWI 3
			FWP 4
			FWP SIZE_OF_RELOCATION;
		offset=offset+SIZE_OF_RELOCATION*n_data_relocations;

		file=file
			FWI shstrtab_symbol_table_section_name_offset
			FWI SHT_SYMTAB
			FWP 0
			FWP 0
			FWP offset
			FWP (SIZE_OF_SYMBOL*n_symbols)
			FWI 8
			FWI 4
			FWP 4
			FWP SIZE_OF_SYMBOL;
		offset=offset+SIZE_OF_SYMBOL*n_symbols;

		file=file
			FWI shstrtab_string_table_section_name_offset
			FWI SHT_STRTAB
			FWP 0
			FWP 0
			FWP offset
			FWP string_table_size
			FWI 0
			FWI 0
			FWP 0
			FWP 0;

		file=file
			FWC '\000'
			FWS ".shstrtab\000"
			FWS ".text\000"
			FWS ".data\000"
			FWS ".bss\000";
		file = write_shstrtab_end file;
	= file;

N_ABS:==0xffff;
N_UNDEF:==0;
TEXT_SECTION:==1;
DATA_SECTION:==2;
BSS_SECTION:==3;

(CHAR) string i :== string.[i];

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
::	SortElement = { index::!Int, offset::!Int };

sort_symbols :: !SymbolIndexList !SymbolArray -> (!SymbolIndexList,!SymbolArray);
sort_symbols symbols symbol_array0
	=	(array_to_list sorted_array 0,symbol_array1);
	{
		sorted_array=heap_sort array;
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
				c a i (Module _ offset _ _ _ _ _ _) symbol_array
					= fill_array {a & [i]={index=index,offset=offset}} (inc i) l symbol_array;
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
					heap_sort1 a i j max_index ir
						# (a_j,a) = a![j];
						# (a_j_1,a) = a![j1];
						#! a=a
						= heap_sort1 a_j a_j_1 a i j max_index ir;
					{
						heap_sort1 :: !SortElement !SortElement !*SortArray !Int !Int !Int !SortElement -> *SortArray;
						heap_sort1 a_j a_j_1 a i j max_index ir
						| a_j.offset < a_j_1.offset
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

reverse_and_sort_symbols :: !SymbolIndexList !SymbolArray -> (!SymbolIndexList,!SymbolArray);
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

reverse_symbols l = reverse_symbols l EmptySymbolIndex;
{
	reverse_symbols EmptySymbolIndex t = t;
	reverse_symbols (SymbolIndex i l) t = reverse_symbols l (SymbolIndex i t);
}

	symbol_index_less_or_equal :: Int Int {!Symbol} -> Bool;
	symbol_index_less_or_equal i1 i2 {[i1]=m1,[i2]=m2}
		= case (m1,m2) of {
			(Module _ offset1 _ _ _ _ _ _,Module _ offset2 _ _ _ _ _ _)
				-> offset1<=offset2; 
		};

sort_modules :: !*SXcoff -> .SXcoff;
sort_modules xcoff
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
		
		({symbol_table}) = xcoff;
		({text_symbols,data_symbols,bss_symbols,symbols=symbols0}) = symbol_table;
	}

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

STT_NOTYPE:==0;
STT_OBJECT:==1;
STT_FUNC:==2;
STT_SECTION:==3;
STT_FILE:==4;

STB_LOCAL:==0;
STB_GLOBAL:==1;

SHN_COMMON:==0xfff2;

define_symbols :: Int Int String String {!Section} NamesTable Int -> (!NamesTable,!SymbolTable);
define_symbols n_sections n_symbols symbol_table_string string_table sections names_table file_n
	= define_symbols_lp 0 names_table empty_symbol_table;
	{
		empty_symbol_table = {	text_symbols=EmptySymbolIndex,
								data_symbols=EmptySymbolIndex,
								bss_symbols=EmptySymbolIndex,
								imported_symbols=EmptySymbolIndex,
								section_symbol_ns=createArray (n_sections+1) (-1),
								symbols=createArray n_symbols EmptySymbol
							 };

		define_symbols_lp :: Int NamesTable SymbolTable -> (!NamesTable,!SymbolTable);
		define_symbols_lp symbol_n names_table symbol_table
			# offset=SIZE_OF_SYMBOL*symbol_n;
			| offset==size symbol_table_string
				= (names_table,symbol_table);
			# st_info = symbol_table_string BYTE (offset+ST_INFO_OFFSET);
			  st_other = symbol_table_string BYTE (offset+ST_OTHER_OFFSET);
			  st_shndx = symbol_table_string WORD (offset+ST_SHNDX);
			  st_name = symbol_table_string LONG offset;
			  st_value = symbol_table_string POINTER (offset+ST_VALUE_OFFSET);
			  st_size = symbol_table_string POINTER (offset+ST_SIZE_OFFSET);
			  st_type= st_info bitand 0xf;
			  st_bind= st_info >> 4;
			| st_type==STT_NOTYPE
				| st_shndx==0
					| st_bind==STB_GLOBAL
						//	&& trace_tn (toString symbol_n+++" "+++toString st_name)
						# name_of_symbol = string_table % (st_name,dec (first_zero_char st_name string_table));
						# symbol_table = {symbol_table & 
								symbols={symbol_table.symbols & [symbol_n]= ImportLabel name_of_symbol},
								imported_symbols= SymbolIndex symbol_n symbol_table.imported_symbols												
								};
						= define_symbols_lp (symbol_n+1) names_table symbol_table;
					| st_bind==STB_LOCAL
						= define_symbols_lp (symbol_n+1) names_table symbol_table;
					= define_symbols_lp_ignore symbol_n names_table symbol_table;
				| st_shndx<0xff00 && sections.[st_shndx].section_segment_n>0
					| st_bind==STB_LOCAL
						# symbol_table = {symbol_table & symbols = {symbol_table.symbols & [symbol_n]=SectionLabel st_shndx st_value} };
						= define_symbols_lp (symbol_n+1) names_table symbol_table;
					| st_bind==STB_GLOBAL
						# name_of_symbol = string_table % (st_name,dec (first_zero_char st_name string_table));
						# names_table=insert_symbol_in_symbol_table name_of_symbol symbol_n file_n names_table;						
						# symbol_table = {symbol_table & symbols = {symbol_table.symbols & [symbol_n]=SectionLabel st_shndx st_value} };
						= define_symbols_lp (symbol_n+1) names_table symbol_table;
					= define_symbols_lp_ignore symbol_n names_table symbol_table;
				| st_shndx==SHN_COMMON
					# symbol_table= {symbol_table &
												symbols = {symbol_table.symbols & [symbol_n]= Module BSS_SECTION 0 st_size 0 0 0 "" (if (st_value<>0) st_value 1)},
												bss_symbols = SymbolIndex symbol_n symbol_table.bss_symbols
						  					};
					= define_symbols_lp (symbol_n+1) names_table symbol_table;
				= define_symbols_lp_ignore symbol_n names_table symbol_table;
			| st_type==STT_FUNC || st_type==STT_OBJECT
				| st_bind==STB_GLOBAL
					# name_of_symbol = string_table % (st_name,dec (first_zero_char st_name string_table));
					| st_shndx<0xff00 && sections.[st_shndx].section_segment_n>0
						# names_table=insert_symbol_in_symbol_table name_of_symbol symbol_n file_n names_table;
						# symbol_table = {symbol_table & symbols = {symbol_table.symbols & [symbol_n]=SectionLabel st_shndx st_value} };
						= define_symbols_lp (symbol_n+1) names_table symbol_table;
					| st_shndx==SHN_COMMON
						# names_table=insert_symbol_in_symbol_table name_of_symbol symbol_n file_n names_table;
						# symbol_table= {symbol_table &
													symbols = {symbol_table.symbols & [symbol_n]= Module BSS_SECTION 0 st_size 0 0 0 "" (if (st_value<>0) st_value 1)},
													bss_symbols = SymbolIndex symbol_n symbol_table.bss_symbols
							  					};
						= define_symbols_lp (symbol_n+1) names_table symbol_table;
					| st_shndx==0
						# symbol_table = {symbol_table &
								symbols={symbol_table.symbols & [symbol_n]= ImportLabel name_of_symbol},
								imported_symbols= SymbolIndex symbol_n symbol_table.imported_symbols
								};
						= define_symbols_lp (symbol_n+1) names_table symbol_table;
					= define_symbols_lp_ignore symbol_n names_table symbol_table;
				| st_bind==STB_LOCAL
					| st_shndx<0xff00 && sections.[st_shndx].section_segment_n>0
						# symbol_table = {symbol_table & symbols = {symbol_table.symbols & [symbol_n]=SectionLabel st_shndx st_value} };
						= define_symbols_lp (symbol_n+1) names_table symbol_table;
					| st_shndx==SHN_COMMON
						# symbol_table= {symbol_table &
													symbols = {symbol_table.symbols & [symbol_n]= Module BSS_SECTION 0 st_size 0 0 0 "" (if (st_value<>0) st_value 1)},
													bss_symbols = SymbolIndex symbol_n symbol_table.bss_symbols
							  					};
						= define_symbols_lp (symbol_n+1) names_table symbol_table;
					= define_symbols_lp_ignore symbol_n names_table symbol_table;
				= define_symbols_lp_ignore symbol_n names_table symbol_table;
			| st_type==STT_SECTION && st_bind==STB_LOCAL
				# ({section_segment_n,section_n_relocations,section_relocations,section_size,section_virtual_address,section_data_offset,section_align}) = sections.[st_shndx];
				| section_segment_n==TEXT_SECTION
					# symbol_table = {symbol_table &
						symbols     = {symbol_table.symbols & [symbol_n]=Module TEXT_SECTION 0 section_size section_virtual_address section_data_offset section_n_relocations section_relocations section_align},
						text_symbols= SymbolIndex symbol_n symbol_table.text_symbols,
						section_symbol_ns = {symbol_table.section_symbol_ns & [st_shndx]=symbol_n}
					  };
					= define_symbols_lp (symbol_n+1) names_table symbol_table;
				| section_segment_n==DATA_SECTION
					# symbol_table = {symbol_table &
						symbols     ={symbol_table.symbols & [symbol_n]=Module DATA_SECTION 0 section_size section_virtual_address section_data_offset section_n_relocations section_relocations section_align},
						data_symbols= SymbolIndex symbol_n symbol_table.data_symbols,
						section_symbol_ns = {symbol_table.section_symbol_ns & [st_shndx]=symbol_n}
				 	  };
					= define_symbols_lp (symbol_n+1) names_table symbol_table;
				| section_segment_n==BSS_SECTION
					# symbol_table = {symbol_table &
						symbols     = {symbol_table.symbols & [symbol_n]= Module BSS_SECTION 0 section_size 0 0 section_n_relocations section_relocations section_align},
						bss_symbols= SymbolIndex symbol_n symbol_table.bss_symbols,
						section_symbol_ns = {symbol_table.section_symbol_ns & [st_shndx]=symbol_n}
					  };
					= define_symbols_lp (symbol_n+1) names_table symbol_table;
				= define_symbols_lp_ignore symbol_n names_table symbol_table;
			| st_type==STT_FILE
				= define_symbols_lp (symbol_n+1) names_table symbol_table;				
			= define_symbols_lp_ignore symbol_n names_table symbol_table;
		where {
				first_zero_char offset symbol_table_string
					| symbol_table_string CHAR offset=='\0'
						= offset;
						= first_zero_char (offset+1) symbol_table_string;

				define_symbols_lp_ignore :: Int NamesTable SymbolTable -> (!NamesTable,!SymbolTable);
				define_symbols_lp_ignore symbol_n names_table symbol_table
//					| trace_tn ("define_symbols_lp: ignored symbol "+++toString symbol_n)
//						= define_symbols_lp (symbol_n+1) names_table symbol_table;
						= define_symbols_lp (symbol_n+1) names_table symbol_table;
		}
	}

read_elf_header :: *File -> (!Bool,!Int,!Int,!Int,!Int,*File);
read_elf_header file
	#	(header_string,file) = freads file SIZE_OF_HEADER;
	| not (size header_string==SIZE_OF_HEADER && header_string.[0]=='\177' && header_string.[1]=='E' && header_string.[2]=='L' && header_string.[3]=='F')
		= error file;
	# e_shoff=header_string POINTER E_SHOFF_OFFSET;
	 e_shentsize=header_string WORD E_SHENTSIZE_OFFSET;
	 e_shnum=header_string WORD E_SHNUM_OFFSET;
	 e_shstrndx=header_string WORD E_SHSTRNDX_OFFSET;
	= (True,e_shoff,e_shentsize,e_shnum,e_shstrndx,file);
	{}{
		error file = (False,0,0,0,0,file);
	}

:: Section = {
		section_segment_n			::!Int,
		section_virtual_address		::!Int,
		section_size				::!Int,
		section_data_offset			::!Int,
		section_relocations_offset	::!Int,
		section_n_relocations		::!Int,
		section_relocations			::!String,
		section_align				::!Int
	};

SHT_PROGBITS:==1;
SHT_SYMTAB:==2;
SHT_STRTAB:==3;
SHT_NOBITS:==8;

SHF_WRITE:==1;
SHF_ALLOC:==2;
SHF_EXECINSTR:==4;

read_section_headers :: Int Int Int Int Int *{!Section} *File -> (!Bool,!Int,!Int,*{!Section},!*File);
read_section_headers section_n n_sections e_shstrndx symtab_section_n strtab_section_n sections file
	| section_n>=n_sections
		= (True,symtab_section_n,strtab_section_n,sections,file);
	# (header_string,file) = freads file SIZE_OF_SECTION_HEADER;
	| size header_string<>SIZE_OF_SECTION_HEADER
		= (False,symtab_section_n,strtab_section_n,sections,file);
	| section_n==e_shstrndx
		= read_section_headers (inc section_n) n_sections e_shstrndx symtab_section_n strtab_section_n sections file;
	# s_type=header_string LONG 4;
	| s_type==SHT_PROGBITS
		# sh_flags=header_string POINTER SH_FLAGS_OFFSET;
		# sh_addralign=header_string POINTER SH_ADDRALIGN_OFFSET;
		# sections = {sections &
							[section_n].section_segment_n =if ((sh_flags bitand SHF_EXECINSTR)<>0) TEXT_SECTION DATA_SECTION,
							[section_n].section_virtual_address = header_string POINTER SH_ADDR_OFFSET,
							[section_n].section_size = header_string POINTER SH_SIZE_OFFSET,
							[section_n].section_data_offset = header_string POINTER SH_OFFSET_OFFSET,
							[section_n].section_align = if (sh_addralign<>0) sh_addralign 1
						};
		= read_section_headers (inc section_n) n_sections e_shstrndx symtab_section_n strtab_section_n sections file;
	| s_type==SHT_relocations
		# sh_info=header_string LONG SH_INFO_OFFSET;
		# sh_size=header_string POINTER SH_SIZE_OFFSET;
		# sh_offset=header_string POINTER SH_OFFSET_OFFSET;
		# sections = {sections &
							[sh_info].section_n_relocations=sh_size / SIZE_OF_RELOCATION,
							[sh_info].section_relocations_offset=sh_offset,
							[section_n].section_size=sh_size,
							[section_n].section_data_offset =sh_offset
						};
		= read_section_headers (inc section_n) n_sections e_shstrndx symtab_section_n strtab_section_n sections file;
	| s_type==SHT_NOBITS
		# sh_addralign = header_string POINTER SH_ADDRALIGN_OFFSET;
		# sections = {sections &
							[section_n].section_segment_n = BSS_SECTION,
							[section_n].section_virtual_address = header_string POINTER SH_ADDR_OFFSET,
							[section_n].section_size = header_string POINTER SH_SIZE_OFFSET,
							[section_n].section_data_offset = header_string POINTER SH_OFFSET_OFFSET,
							[section_n].section_align = if (sh_addralign<>0) sh_addralign 1
						};
		= read_section_headers (inc section_n) n_sections e_shstrndx symtab_section_n strtab_section_n sections file;		
	| s_type==SHT_SYMTAB
		| symtab_section_n>=0
			= abort "Too many symbol tables in object file";
		# sh_link=header_string LONG SH_LINK_OFFSET;
		# symtab_section_n=section_n;
		# strtab_section_n=sh_link;
		# sections = {sections &
							[section_n].section_size = header_string POINTER SH_SIZE_OFFSET,
							[section_n].section_data_offset = header_string POINTER SH_OFFSET_OFFSET
						};
		= read_section_headers (inc section_n) n_sections e_shstrndx symtab_section_n strtab_section_n sections file;	
	| s_type==SHT_STRTAB
		# sections = {sections &
							[section_n].section_size = header_string POINTER SH_SIZE_OFFSET,
							[section_n].section_data_offset = header_string POINTER SH_OFFSET_OFFSET
						};
		= read_section_headers (inc section_n) n_sections e_shstrndx symtab_section_n strtab_section_n sections file;
		= read_section_headers (inc section_n) n_sections e_shstrndx symtab_section_n strtab_section_n sections file;

read_relocations :: Int Int *{!Section} *File -> (!Bool,!*{!Section},!*File);
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

read_xcoff_file :: !String NamesTable Bool !Files Int -> (![String],!*String,!*String,!Xcoff,!NamesTable,!Files);
read_xcoff_file file_name names_table0 one_pass_link files file_n
	# (ok,file,files) = fopen file_name FReadData files;
	| not ok
		= error ("Cannot open file \""+++file_name+++"\"") file files;
	# (ok,e_shoff,e_shentsize,e_shnum,e_shstrndx,file) = read_elf_header file;
	| not ok
		= error ("Not an ELF file: \""+++file_name+++"\"") file files;

	# n_sections=e_shnum;

	# (fseek_ok,file)=fseek file e_shoff FSeekSet;
	| not fseek_ok
		= error ("Not an ELF file: \""+++file_name+++"\"") file files;

	# sections = createArray n_sections {	section_segment_n= -1,section_virtual_address=0,section_size= -1,
											section_data_offset=0,section_relocations_offset=0,section_n_relocations=0,
											section_relocations="",section_align=1
										  };
	  (ok,symtab_section_n,strtab_section_n,sections,file) = read_section_headers 0 n_sections e_shstrndx -1 -1 sections file;
	| not ok
		= error "Error in section header" file files;
	| strtab_section_n<0
		= error "String table not found" file files;
	| symtab_section_n<0
		= error "Symbol table not found" file files;
	# (ok,sections,file) = read_relocations 0 n_sections sections file;
	| not ok
		= error "Error in relocations" file files;
	# text_section = {};
	  data_section = {};

	# (symtab_section,sections)=sections![symtab_section_n];
	  n_symbols=symtab_section.section_size / SIZE_OF_SYMBOL;
	  symbol_table_offset=symtab_section.section_data_offset;

	# (strtab_section,sections)=sections![strtab_section_n];
	  string_table_size=strtab_section.section_size;
	  string_table_offset=strtab_section.section_data_offset;

	  (ok,symbol_table_string,string_table,file) = read_symbol_and_string_table symbol_table_offset n_symbols string_table_offset string_table_size file;
	| not ok
		= error ("Error in symbol table "+++file_name) file files;
		# (names_table1,symbol_table0)
				=define_symbols n_sections n_symbols symbol_table_string string_table sections names_table0 file_n;
		  xcoff_file={file_name=file_name,symbol_table=symbol_table0,n_symbols=n_symbols };
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
			text_symbols=EmptySymbolIndex,data_symbols=EmptySymbolIndex,bss_symbols=EmptySymbolIndex,
			imported_symbols=EmptySymbolIndex,symbols={},section_symbol_ns={}
		};
	};

