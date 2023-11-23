implementation module linker3;

import StdFile,StdArray,StdClass,StdEnum,StdInt,StdBool,StdChar;
from StdMisc import abort;
from StdList import ++;
from StdString import class %, +++.,instance toString Int,instance +++ {#Char};

import linker2,linker_resources;
import xcoff_linker;

// RWS (!=);
(!=) a b :== a<>b;

u_char_array_slice :: !*{#Char} !Int !Int -> (!*{#Char},!*{#Char});
u_char_array_slice array begin_index end_index = code {
		push_a 0
	.d 1 2 ii
		jsr	sliceAC
	.o 1 0 
};

// RWS (CHAR);
(CHAR) string i :== string.[i];

// RWS (BYTE);
(BYTE) string i :== toInt (string.[i]);

// RWS (LONG);
(LONG) string i
	= (string BYTE i<<24) bitor (string BYTE (i+1)<<16) bitor (string BYTE (i+2)<<8) bitor (string BYTE (i+3));

read_long :: *{#Char} Int -> (!Int,!*{#Char});
read_long a i//=:{[i]=e0,[i1]=e1,[i2]=e2,[i3]=e3} i
	#! e0	= a.[i];
	   e1	= a.[i1];
	   e2	= a.[i2];
	   e3	= a.[i3];
	= ((toInt e0<<24) bitor (toInt e1<<16) bitor (toInt e2<<8) bitor (toInt e3),a);
{
	i1=i+1;
	i2=i+2;
	i3=i+3;
}

/*
PRINT_STRING s	| !error = s; {}{ (error,_)=ferror (fwrites s stderr); }
PRINT_INT i 	| !error = i; {}{ (error,_)=ferror (fwritec ' ' (fwritei i stderr)); }
*/

:: *Sections = Sections !*String !*String !Sections | EndSections;

create_xcoff_boolean_array :: Int Int Int Int LibraryList [*Xcoff] -> (!*{#Bool},!*{#Int},!*{#*Xcoff});
create_xcoff_boolean_array n_xcoff_files n_xcoff_symbols n_libraries n_library_symbols library_list list0
	=	(createArray (n_xcoff_symbols+n_library_symbols) False,offset_array1,xcoff_a);
	{
		(offset_array1,xcoff_a) = fill_offsets 0 0 list0 (createArray (n_xcoff_files+n_libraries) 0) (xcoff_array n_xcoff_files);

		xcoff_array :: Int -> *{#*Xcoff};
		xcoff_array n = { empty_xcoff \\ i<-[0..dec n]};
		
		fill_offsets :: Int Int [*Xcoff] *{#Int} *{#*Xcoff} -> (!*{#Int},!*{#*Xcoff});
		fill_offsets file_n offset [] offset_array xcoff_a
			= (fill_library_offsets library_list file_n offset offset_array,xcoff_a);
		fill_offsets file_n offset [xcoff=:{n_symbols}:xcoff_list] offset_array xcoff_a
			= fill_offsets (inc file_n) (offset+n_symbols) xcoff_list {offset_array & [file_n]=offset} {xcoff_a & [file_n]=xcoff};
		
		fill_library_offsets :: LibraryList Int Int *{#Int} -> *{#Int};
		fill_library_offsets EmptyLibraryList file_n offset offset_array
			= offset_array;
		fill_library_offsets (Library _ symbols n_symbols libraries) file_n offset offset_array
			= fill_library_offsets libraries (inc file_n) (offset+n_symbols) {offset_array & [file_n]=offset};
	}

:: OffsetArray :== {#Int};

/*
mark_toc0_symbols :: Int *{#Bool} [*Xcoff] -> (!*{#Bool},![*Xcoff]);
mark_toc0_symbols file_symbol_index marked_bool_a0 []
	= (marked_bool_a0,[]);
mark_toc0_symbols file_symbol_index marked_bool_a0 [xcoff_file0=:{symbol_table=:{toc0_symbol},n_symbols}:xcoff_files0]
	=	case toc0_symbol of {
			EmptySymbolIndex
				-> (marked_bool_a1,[xcoff_file0:xcoff_files1]);
			(SymbolIndex module_n EmptySymbolIndex)
				-> ({marked_bool_a1 & [file_symbol_index+module_n]=True},[xcoff_file0:xcoff_files1]);
		}
	{
		(marked_bool_a1,xcoff_files1) = mark_toc0_symbols (file_symbol_index+n_symbols) marked_bool_a0 xcoff_files0;
	}	
*/

:: *ModuleOffsets :== *{#Int};

compute_module_offsets :: Int [Xcoff] Int {#Bool} -> (!Int,!Int,!ModuleOffsets);
compute_module_offsets n_symbols xcoff_list toc_offset0 marked_bool_a
	= compute_files_module_offsets xcoff_list 0 toc_offset0 0 (createArray n_symbols 0);
	{
		compute_files_module_offsets :: [Xcoff] Int Int Int ModuleOffsets -> (!Int,!Int,!ModuleOffsets);
		compute_files_module_offsets [] text_offset0 toc_offset0 file_symbol_index module_offsets0
			= (text_offset0,toc_offset0,module_offsets0);
		compute_files_module_offsets [xcoff=:{n_symbols}:xcoff_list] text_offset0 toc_offset0 file_symbol_index module_offsets0
			= compute_files_module_offsets xcoff_list text_offset1 toc_offset1 (file_symbol_index+n_symbols) module_offsets3;
			{
				(text_offset1,module_offsets1)
					= compute_section_module_offsets file_symbol_index marked_bool_a symbol_table.text_symbols symbols text_offset0 module_offsets0;
				(toc_offset1,module_offsets2)
					= compute_data_section_module_offsets file_symbol_index symbol_table.toc_symbols symbols toc_offset0 module_offsets1;
				module_offsets3
					= compute_toc0_module_offset file_symbol_index symbol_table.toc0_symbol module_offsets2;
					
				symbol_table=xcoff.symbol_table;
				symbols=symbol_table.symbols;
			}
	}

	compute_toc0_module_offset file_symbol_index EmptySymbolIndex module_offsets
		=	module_offsets;
	compute_toc0_module_offset file_symbol_index (SymbolIndex module_n EmptySymbolIndex) module_offsets
		=	{module_offsets & [file_symbol_index+module_n] = 32768};

compute_bss_module_offsets :: [Xcoff] Int Int {#Bool} ModuleOffsets -> (!Int,!ModuleOffsets);
compute_bss_module_offsets [] bss_offset0 file_symbol_index marked_bool_a module_offsets0
	= (bss_offset0,module_offsets0);
compute_bss_module_offsets [xcoff=:{n_symbols}:xcoff_list] bss_offset0 file_symbol_index marked_bool_a module_offsets0
	= compute_bss_module_offsets xcoff_list bss_offset1 (file_symbol_index+n_symbols) marked_bool_a module_offsets1;
	{
		(bss_offset1,module_offsets1)
			= compute_section_module_offsets file_symbol_index marked_bool_a symbol_table.bss_symbols symbol_table.symbols bss_offset0 module_offsets0;
		symbol_table=xcoff.symbol_table;
	}

compute_data_module_offsets :: [Xcoff] Int Int ModuleOffsets -> (!Int,!ModuleOffsets);
compute_data_module_offsets [] data_offset0 file_symbol_index module_offsets0
	= (data_offset0,module_offsets0);
compute_data_module_offsets [xcoff=:{n_symbols}:xcoff_list] data_offset0 file_symbol_index module_offsets0
	= compute_data_module_offsets xcoff_list data_offset1 (file_symbol_index+n_symbols) module_offsets1;
	{
		(data_offset1,module_offsets1)
			= compute_data_section_module_offsets file_symbol_index symbol_table.data_symbols symbol_table.symbols data_offset0 module_offsets0;
		symbol_table=xcoff.symbol_table;
	}

	compute_section_module_offsets :: Int {#Bool} SymbolIndexList SymbolArray Int ModuleOffsets -> (!Int,!ModuleOffsets);
	compute_section_module_offsets file_symbol_index marked_bool_a EmptySymbolIndex symbol_array offset0 module_offsets0
		= (offset0,module_offsets0);
	compute_section_module_offsets file_symbol_index marked_bool_a (SymbolIndex module_n symbol_list) symbol_array=:{[module_n]=module_symbol} offset0 module_offsets0
		| not marked_bool_a.[file_symbol_index+module_n]
			= compute_section_module_offsets file_symbol_index marked_bool_a symbol_list symbol_array offset0 module_offsets0;
			= compute_section_module_offsets file_symbol_index marked_bool_a symbol_list symbol_array offset1 module_offsets1;
			{
				(offset1,module_offsets1)=compute_module_offset module_symbol module_n offset0 file_symbol_index module_offsets0;
			}

	compute_data_section_module_offsets :: Int SymbolIndexList SymbolArray Int ModuleOffsets -> (!Int,!ModuleOffsets);
	compute_data_section_module_offsets file_symbol_index EmptySymbolIndex symbol_array offset0 module_offsets0
		= (offset0,module_offsets0);
	compute_data_section_module_offsets file_symbol_index (SymbolIndex module_n symbol_list) symbol_array=:{[module_n]=module_symbol} offset0 module_offsets0
		= compute_data_section_module_offsets file_symbol_index symbol_list symbol_array offset1 module_offsets1;
		{
			(offset1,module_offsets1)=compute_module_offset module_symbol module_n offset0 file_symbol_index module_offsets0;	
		}

		compute_module_offset :: Symbol Int Int Int ModuleOffsets -> (!Int,!ModuleOffsets);
		compute_module_offset (Module {length,align=alignment}) module_n offset0 file_symbol_index module_offsets0
			= (aligned_offset0+length,{module_offsets0 & [file_symbol_index+module_n] = aligned_offset0});
			{
				aligned_offset0=(offset0+alignment_mask) bitand (bitnot alignment_mask);
				alignment_mask=dec (1<<alignment);
			}
		compute_module_offset (AliasModule _) module_n offset0 file_symbol_index module_offsets0
			= (offset0,module_offsets0);
		compute_module_offset (ImportedFunctionDescriptorTocModule _) module_n offset0 file_symbol_index module_offsets0
			= (offset0,module_offsets0);

::	TocTable = Toc !TocElem !.TocTable !.TocTable | EmptyTocTable;
::	TocElem = {global_module_n::!Int,symbol_n::!Int,offset::!Int};

insert_exported_symbol_in_toc_table :: Int Int Int Int Int Int *{!Symbol} {#Int} !*TocTable -> (!*{!Symbol},!*TocTable);
insert_exported_symbol_in_toc_table file_symbol_index symbol_module_n virtual_module_offset first_relocation_n relocation_symbol_n relocation_symbol_offset symbol_a=:{[relocation_symbol_n]=relocation_symbol} offset_a toc_table0
	= case relocation_symbol of {
		ImportedLabel {implab_file_n=imported_file_n,implab_symbol_n=symbol_n}
			| imported_file_n<0
				->	insert_symbol_in_toc_table (offset_a.[size offset_a+imported_file_n]+symbol_n) relocation_symbol_offset symbol_a toc_table0;
				->	insert_symbol_in_toc_table (offset_a.[imported_file_n]+symbol_n) relocation_symbol_offset symbol_a toc_table0;
		ImportedLabelPlusOffset {implaboffs_file_n=imported_file_n,implaboffs_symbol_n=symbol_n,implaboffs_offset=offset}
			->	insert_symbol_in_toc_table (offset_a.[imported_file_n]+symbol_n) (relocation_symbol_offset+offset) symbol_a toc_table0;
		Module {module_offset=offset}
			->	insert_symbol_in_toc_table (file_symbol_index+relocation_symbol_n) (relocation_symbol_offset-offset) symbol_a toc_table0;
		Label {label_offset=offset}
			->	insert_symbol_in_toc_table (file_symbol_index+relocation_symbol_n) (relocation_symbol_offset-offset) symbol_a toc_table0;
		ImportedFunctionDescriptor {implab_file_n,implab_symbol_n}
			->	({symbol_a & [symbol_module_n] = ImportedFunctionDescriptorTocModule {
					imptoc_offset = virtual_module_offset,imptoc_file_n=implab_file_n,imptoc_symbol_n=implab_symbol_n
				  }},toc_table0);

	  };
	{
		insert_symbol_in_toc_table :: Int Int *SymbolArray *TocTable -> (!*SymbolArray,!*TocTable);
		insert_symbol_in_toc_table new_symbol_n new_offset symbol_a0 EmptyTocTable
			=	(symbol_a0,Toc {global_module_n=file_symbol_index+symbol_module_n,symbol_n=new_symbol_n,offset=new_offset} EmptyTocTable EmptyTocTable);
		insert_symbol_in_toc_table new_symbol_n new_offset symbol_a0 t=:(Toc toc_elem=:{symbol_n,offset} left right)
			| new_symbol_n<symbol_n
				=	(symbol_a1,Toc toc_elem left1 right); {
					(symbol_a1,left1) = insert_symbol_in_toc_table new_symbol_n new_offset symbol_a0 left;
				}
			| new_symbol_n>symbol_n
				=	(symbol_a1,Toc toc_elem left right1); {
					(symbol_a1,right1) = insert_symbol_in_toc_table new_symbol_n new_offset symbol_a0 right;
				}
			| new_offset==offset
				=	({symbol_a0 & [symbol_module_n]=AliasModule {
						alias_module_offset = virtual_module_offset,
						alias_first_relocation_n = first_relocation_n,
						alias_global_module_n = toc_elem.global_module_n
					  }},
//					  t
					  Toc toc_elem left right
					  );
			| new_offset<offset
				=	(symbol_a1,Toc toc_elem left1 right); {
					(symbol_a1,left1) = insert_symbol_in_toc_table new_symbol_n new_offset symbol_a0 left;
				}
				=	(symbol_a1,Toc toc_elem left right1); {
					(symbol_a1,right1) = insert_symbol_in_toc_table new_symbol_n new_offset symbol_a0 right;
				}
	}

split_data_symbol_lists_of_files2 :: {#Int} {#Bool} Sections [*Xcoff] *TocTable -> (!Sections,![*Xcoff],!*TocTable);
split_data_symbol_lists_of_files2 offset_a marked_bool_a sections xcoff_list toc_table0
	=	split_data_symbol_lists_of_files2 0 sections xcoff_list toc_table0;
	{
		split_data_symbol_lists_of_files2 :: Int Sections [*Xcoff] *TocTable -> (!Sections,![*Xcoff],!*TocTable);
		split_data_symbol_lists_of_files2 file_symbol_index EndSections [] toc_table0
			= (EndSections,[],toc_table0);
		split_data_symbol_lists_of_files2 file_symbol_index (Sections text_section data_section0 sections0) [xcoff=:{n_symbols,symbol_table,data_relocations,header={data_v_address}}:xcoff_list0] toc_table0 
		= (	Sections text_section data_section1 sections1,
			[ {xcoff & symbol_table={symbol_table & toc_symbols=toc_symbols1,data_symbols=data_symbols1,symbols=symbol_table2 }} : xcoff_list1],
			toc_table2
	  	);
		{
			(toc_symbols1,data_symbols1,symbol_table1,data_section1,toc_table1)
				= split_data_symbol_list2 symbol_table.data_symbols symbol_table.symbols data_section0 toc_table0;
			(sections1,xcoff_list1,toc_table2)
				= split_data_symbol_lists_of_files2 (file_symbol_index+n_symbols) sections0 xcoff_list0 toc_table1;
			symbol_table2 = case symbol_table.toc0_symbol of {
				SymbolIndex toc0_index EmptySymbolIndex
					-> remove_unmarked_symbols (inc toc0_index) n_symbols file_symbol_index marked_bool_a
						(remove_unmarked_symbols 0 toc0_index file_symbol_index marked_bool_a symbol_table1);
				EmptySymbolIndex
					-> remove_unmarked_symbols 0 n_symbols file_symbol_index marked_bool_a symbol_table1;
			};

		split_data_symbol_list2 :: SymbolIndexList *SymbolArray *String *TocTable -> (!SymbolIndexList,!SymbolIndexList,!*SymbolArray,!*String,!*TocTable);
		split_data_symbol_list2 EmptySymbolIndex symbol_array0 data_section0 toc_table0
			= (EmptySymbolIndex,EmptySymbolIndex,symbol_array0,data_section0,toc_table0);
		split_data_symbol_list2 (SymbolIndex module_n symbol_list) symbol_array0=:{[module_n]=module_symbol} data_section0 toc_table0
			| not marked_bool_a.[file_symbol_index+module_n]
				= split_data_symbol_list2 symbol_list symbol_array0 data_section0 toc_table0;
				= case module_symbol of {
					Module {section_n=TOC_SECTION,module_offset=virtual_module_offset,length=4,first_relocation_n,end_relocation_n}
						| first_relocation_n+1==end_relocation_n && relocation_type==R_POS && relocation_size==0x1f
							-> (SymbolIndex module_n toc_symbols,data_symbols,symbol_array2,data_section2,toc_table2);
							{
								(toc_symbols,data_symbols,symbol_array2,data_section2,toc_table2)
									= split_data_symbol_list2 symbol_list symbol_array1 data_section1 toc_table1;
								(symbol_array1,toc_table1)
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
					Module {section_n=TOC_SECTION}
						-> (SymbolIndex module_n toc_symbols,data_symbols,symbol_array1,data_section1,toc_table1); {
							(toc_symbols,data_symbols,symbol_array1,data_section1,toc_table1)
								= split_data_symbol_list2 symbol_list symbol_array0 data_section0 toc_table0;
						}
					Module {section_n=DATA_SECTION}
						-> (toc_symbols,SymbolIndex module_n data_symbols,symbol_array1,data_section1,toc_table1); {
							(toc_symbols,data_symbols,symbol_array1,data_section1,toc_table1)
								= split_data_symbol_list2 symbol_list symbol_array0 data_section0 toc_table0;
						};
				};
		
			remove_unmarked_symbols :: !Int !Int !Int !{#Bool} !*SymbolArray -> *SymbolArray;
			remove_unmarked_symbols index n_symbols first_symbol_index marked_bool_a symbols
				| index>=n_symbols
					= symbols;
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

compute_imported_library_symbol_offsets :: LibraryList Int Int !{#Bool} *{#Int} -> (!LibraryList,!Int,!*{#Int});
compute_imported_library_symbol_offsets library_list text_offset symbol_n marked_bool_a module_offset_a
	# (library_list,text_offset,_,module_offset_a)
		= compute_imported_library_symbol_offsets_lp library_list text_offset 0 symbol_n module_offset_a;
		with {
			compute_imported_library_symbol_offsets_lp :: LibraryList Int Int Int *{#Int} -> (!LibraryList,!Int,!Int,!*{#Int});
			compute_imported_library_symbol_offsets_lp EmptyLibraryList text_offset toc_offset symbol_n module_offset_a
				=	(EmptyLibraryList,text_offset,toc_offset,module_offset_a);
			compute_imported_library_symbol_offsets_lp (Library library_name library_symbols n_symbols library_list) text_offset0 toc_offset symbol_n module_offset_a
			#	(imported_symbols,text_offset1,toc_offset,module_offset_a)
					= compute_library_symbol_offsets library_symbols symbol_n text_offset0 toc_offset module_offset_a;
						with {
							compute_library_symbol_offsets :: LibrarySymbolsList Int Int Int *{#Int} -> (!LibrarySymbolsList,!Int,!Int,!*{#Int});
							compute_library_symbol_offsets EmptyLibrarySymbolsList symbol_n text_offset toc_offset module_offset_a
								= (EmptyLibrarySymbolsList,text_offset,toc_offset,module_offset_a);
							compute_library_symbol_offsets (LibrarySymbol symbol_name symbol_list) symbol_n text_offset toc_offset module_offset_a
								| marked_bool_a.[symbol_n]
									# (imported_symbols,text_offset,toc_offset,module_offset_a)
										= compute_library_symbol_offsets symbol_list (symbol_n+2) (text_offset+24) (toc_offset+4)
											{module_offset_a & [symbol_n]=text_offset,[symbol_n+1]=toc_offset};
									= (LibrarySymbol symbol_name imported_symbols,text_offset,toc_offset,module_offset_a);
									= compute_library_symbol_offsets symbol_list (symbol_n+2) text_offset toc_offset module_offset_a;
						}
				(library_list,text_offset,toc_offset,module_offset_a)
					= compute_imported_library_symbol_offsets_lp library_list text_offset1 toc_offset (symbol_n+n_symbols) module_offset_a;
				n_imported_symbols2 = (text_offset1-text_offset0) / 12;
			=	(Library library_name imported_symbols n_imported_symbols2 library_list,text_offset,toc_offset,module_offset_a);
		}
	= (library_list,text_offset,module_offset_a);


(FWI) infixl;
(FWI) f i :== fwritei i f;

(FWS) infixl;
(FWS) f s :== fwrites s f;

(FWC) infixl;
(FWC) f c :== fwritec c f;

(FWZ) infixl;
(FWZ) f i :== write_zero_bytes_to_file i f;

write_code_to_output_files :: [Xcoff] Int {#Bool} {#Int} {#Int} SymbolsArray Bool Sections !*File *Files -> (![*String],!*File,!*Files,![Xcoff]);
write_code_to_output_files [] first_symbol_n marked_bool_a module_offset_a marked_offset_a0 symbols_a one_pass_link sections pef_file0 files0
	= ([],pef_file0,files0,[]);
write_code_to_output_files [xcoff=:{n_symbols,header}:xcoff_list] first_symbol_n marked_bool_a module_offset_a marked_offset_a0 symbols_a one_pass_link (Sections text_section data_section sections) pef_file0 files0
	| one_pass_link && size text_section==header.text_section_size
		#!
			xcoff1= {xcoff & text_relocations="",symbol_table={xcoff.symbol_table & text_symbols = EmptySymbolIndex}};
		=	([data_section1 : data_strings],pef_file2,files1,[xcoff1 :xcoff_list1]);
		{
			(pef_file1,data_section1)
				= write_code_to_pef_file xcoff first_symbol_n marked_bool_a module_offset_a marked_offset_a0 symbols_a text_section data_section pef_file0;
			(data_strings,pef_file2,files1,xcoff_list1)
				= write_code_to_output_files xcoff_list (first_symbol_n+n_symbols) marked_bool_a module_offset_a marked_offset_a0 symbols_a one_pass_link sections pef_file1 files0;
		}
	| one_pass_link && size text_section==0
		#!
			xcoff1= {xcoff & text_relocations="",symbol_table={xcoff.symbol_table & text_symbols = EmptySymbolIndex}};
		=
		  if (ok0 && ok1 && ok2)
			([data_section1 : data_strings],pef_file2,files3,[xcoff1 :xcoff_list1])
			(abort "Read error");
		{
			(ok0,xcoff_file0,files1)	= fopen header.file_name FReadData files0;
			(ok1,xcoff_file1)			= fseek xcoff_file0 header.text_section_offset FSeekSet;
			(text_string,xcoff_file2)	= freads xcoff_file1 header.text_section_size;
			(ok2,files2) 				= fclose xcoff_file2 files1;

			(pef_file1,data_section1)
				= write_code_to_pef_file xcoff first_symbol_n marked_bool_a module_offset_a marked_offset_a0 symbols_a text_string data_section pef_file0;

			(data_strings,pef_file2,files3,xcoff_list1)
				= write_code_to_output_files xcoff_list (first_symbol_n+n_symbols) marked_bool_a module_offset_a marked_offset_a0 symbols_a one_pass_link sections pef_file1 files2;
		};
		#!
			xcoff1= {xcoff & text_relocations="",symbol_table={xcoff.symbol_table & text_symbols = EmptySymbolIndex}};
		=
		  if (ok0 && ok1 && ok2 && ok3)
			([data_string1 : data_strings],pef_file2,files3,[xcoff1 : xcoff_list1])
			(abort "Read error");
		{
			(ok0,xcoff_file0,files1)	= fopen header.file_name FReadData files0;

			(ok1,xcoff_file1)			= fseek xcoff_file0 header.text_section_offset FSeekSet;
			(text_string,xcoff_file2)	= freads xcoff_file1 header.text_section_size;

			(ok2,xcoff_file3)			= fseek xcoff_file2 header.data_section_offset FSeekSet;
			(data_string,xcoff_file4)	= freads xcoff_file3 header.data_section_size;

			(ok3,files2) 				= fclose xcoff_file4 files1;

			(pef_file1,data_string1)
				 = write_code_to_pef_file xcoff first_symbol_n marked_bool_a module_offset_a marked_offset_a0 symbols_a text_string data_string pef_file0;
			(data_strings,pef_file2,files3,xcoff_list1)
				= write_code_to_output_files xcoff_list (first_symbol_n+n_symbols) marked_bool_a module_offset_a marked_offset_a0 symbols_a one_pass_link sections pef_file1 files2;
		};

write_code_to_pef_file :: Xcoff Int {#Bool} {#Int} {#Int} SymbolsArray !*String *String *File -> (!*File,!*String);
write_code_to_pef_file
		{header={file_name,text_section_offset,text_section_size,data_section_offset,data_section_size,text_v_address,data_v_address},
				 symbol_table={text_symbols,symbols,toc0_symbol},text_relocations,data_relocations}
		first_symbol_n marked_bool_a module_offset_a marked_offset_a0 symbols_a text_section data_section pef_file0
	=	write_text_to_pef_file text_symbols 0 symbols text_section data_section pef_file0;
	{
		write_text_to_pef_file :: SymbolIndexList Int SymbolArray *String *String *File -> (!*File,!*String);
		write_text_to_pef_file EmptySymbolIndex offset0 symbol_table text_a0 data_section pef_file0
			= (pef_file0,data_section);
		write_text_to_pef_file (SymbolIndex module_n symbol_list) offset0 symbol_table=:{[module_n] = symbol} text_a0 data_section pef_file0
			| marked_bool_a.[first_symbol_n+module_n]
				= write_text_to_pef_file symbol_list offset1 symbol_table text_a1 data_section1 pef_file1;
				{
					(text_a1,data_section1,offset1,pef_file1) = write_text_module_to_pef_file symbol offset0 module_offset_a text_a0 data_section pef_file0;
				};
				= write_text_to_pef_file symbol_list offset0 symbol_table text_a0 data_section pef_file0;
			{}{
				write_text_module_to_pef_file :: Symbol Int {#Int} *String *String *File -> (!*String,!*String,!Int,!*File);
				write_text_module_to_pef_file (Module {section_n=TEXT_SECTION,module_offset=virtual_module_offset,length,first_relocation_n,end_relocation_n,align=alignment})
						offset0 module_offset_a/*=:{[o_i]=real_module_offset}*/ text_a0 data_section pef_file0
					= (text_a2,data_section1,aligned_offset0+length,fwrites text_string (write_zero_bytes_to_file (aligned_offset0-offset0) pef_file0));
					{
						(text_string,text_a2) = u_char_array_slice text_a1 offset (offset+length-1);
						offset=virtual_module_offset-text_v_address;
						o_i=first_symbol_n+module_n;
						real_module_offset	= module_offset_a.[o_i];
						
						aligned_offset0=(offset0+alignment_mask) bitand (bitnot alignment_mask);
						alignment_mask=dec (1<<alignment);

						(text_a1,data_section1) = relocate_text first_relocation_n symbols text_a0 data_section;

						relocate_text :: Int SymbolArray *String *String -> (!*String,!*String);
						relocate_text relocation_n symbol_a text_a0 data_section
							| relocation_n==end_relocation_n
								= (text_a0,data_section);
							| relocation_type==R_TRL && (relocation_size==0x8f || relocation_size==0x0f)
								= relocate_text (inc relocation_n) symbol_a text1 data_section1;
								{
									(text1,data_section1)
										= relocate_trl symbol_a.[relocation_symbol_n] symbol_a.[toc0_symbol_n] (relocation_offset-text_v_address) data_v_address
											module_offset_a first_symbol_n relocation_symbol_n symbol_a marked_offset_a0 symbols_a data_relocations text_a0 data_section;

									(SymbolIndex toc0_symbol_n _)=toc0_symbol;
								}
								= relocate_text (inc relocation_n) symbol_a text1 data_section;
								{
									text1 = case relocation_type of {
										R_BR
											| relocation_size==0x8f
												-> relocate_short_branch symbol_a.[relocation_symbol_n] (relocation_offset-text_v_address) virtual_module_offset 
													real_module_offset module_offset_a first_symbol_n relocation_symbol_n symbol_a text_a0;
											| relocation_size==0x99
												-> relocate_branch symbol_a.[relocation_symbol_n] (relocation_offset-text_v_address) virtual_module_offset
													real_module_offset module_offset_a first_symbol_n relocation_symbol_n symbol_a marked_offset_a0 symbols_a text_a0;
										R_TOC
											| relocation_size==0x8f || relocation_size==0x0f
												-> relocate_toc symbol_a.[relocation_symbol_n] symbol_a.[toc0_symbol_n] 
													(relocation_offset-text_v_address) module_offset_a first_symbol_n relocation_symbol_n marked_offset_a0 text_a0;
												{
													(SymbolIndex toc0_symbol_n _)=toc0_symbol;
												}
										R_REF
											-> text_a0;
										R_MW_BR
											| relocation_size==0x8f
												-> relocate_mw_short_branch symbol_a.[relocation_symbol_n] (relocation_offset-text_v_address) virtual_module_offset 
													real_module_offset module_offset_a first_symbol_n relocation_symbol_n symbol_a text_a0;
											| relocation_size==0x99
												-> relocate_mw_branch symbol_a.[relocation_symbol_n] (relocation_offset-text_v_address) virtual_module_offset
													real_module_offset module_offset_a first_symbol_n relocation_symbol_n symbol_a marked_offset_a0 symbols_a text_a0;
										R_MW_TOC
											| relocation_size==0x8f || relocation_size==0x0f
												-> relocate_mw_toc symbol_a.[relocation_symbol_n]
													(relocation_offset-text_v_address) module_offset_a first_symbol_n relocation_symbol_n marked_offset_a0 text_a0;
										u
											-> abort ("Unimplemented relocation type '"+++.toString u+++."' encountered\n")
									}
								}
							{							
								relocation_type=text_relocations BYTE (relocation_index+9);
								relocation_size=text_relocations BYTE (relocation_index+8);
								relocation_symbol_n=(inc (text_relocations LONG (relocation_index+4))) >> 1;
								relocation_offset=text_relocations LONG relocation_index;

								relocation_index=relocation_n * SIZE_OF_RELOCATION;
							}
					}
			}
	}

write_imported_library_functions_code :: LibraryList Int *File -> *File;
write_imported_library_functions_code EmptyLibraryList descriptor_offset0 pef_file0
	= pef_file0;
write_imported_library_functions_code (Library _ imported_symbols _ library_list) descriptor_offset0 pef_file0
	=	write_imported_library_functions_code library_list descriptor_offset1 pef_file1;
	{
		(descriptor_offset1,pef_file1) = write_library_functions_code imported_symbols descriptor_offset0 pef_file0;
		
		write_library_functions_code :: LibrarySymbolsList Int *File -> (!Int,!*File);
		write_library_functions_code EmptyLibrarySymbolsList descriptor_offset0 pef_file0
			= (descriptor_offset0,pef_file0);
		write_library_functions_code (LibrarySymbol symbol_name symbol_list) descriptor_offset0 pef_file0
			= write_library_functions_code symbol_list (descriptor_offset0+4) pef_file1;
			{
				pef_file1 = pef_file0
					FWI (/*0x81820000*/0x81828000+descriptor_offset0) FWI 0x90410014 FWI 0x800C0000 FWI 0x804C0004 FWI 0x7C0903A6 FWI 0x4E800420;
			}
	}

relocate_data :: Int Int Int Int Int String Int {#Int} {#Int} {!Symbol} SymbolsArray *{#Char}-> *{#Char};
relocate_data relocation_n end_relocation_n virtual_module_offset virtual_section_offset real_module_offset data_relocations
		first_symbol_n module_offset_a marked_offset_a0 symbol_a symbols_a data0
	| relocation_n==end_relocation_n
		= data0;
		= relocate_data (inc relocation_n) end_relocation_n virtual_module_offset virtual_section_offset real_module_offset data_relocations
						first_symbol_n module_offset_a marked_offset_a0 symbol_a symbols_a data1;
	{
		data1 = relocate_symbol relocation_type module_offset_a symbol_a marked_offset_a0 symbols_a data0;
		
		relocate_symbol :: Int {#Int} {!Symbol} {#Int} SymbolsArray *{#Char} -> *{#Char};
		relocate_symbol R_POS module_offset_a symbol_a marked_offset_a0 symbols_a data0
			| relocation_size==0x1f
				= relocate_long_pos symbol_a.[relocation_symbol_n] (relocation_offset-virtual_section_offset) module_offset_a 
									first_symbol_n relocation_symbol_n symbol_a marked_offset_a0 symbols_a data0;
		relocate_symbol R_MW_POS module_offset_a symbol_a marked_offset_a0 symbols_a data0
			| relocation_size==0x1f
				= relocate_mw_long_pos symbol_a.[relocation_symbol_n] (relocation_offset-virtual_section_offset) module_offset_a 
									first_symbol_n relocation_symbol_n symbol_a marked_offset_a0 symbols_a data0;

		relocation_type=data_relocations BYTE (relocation_index+9);
		relocation_size=data_relocations BYTE (relocation_index+8);
		relocation_symbol_n=(inc (data_relocations LONG (relocation_index+4))) >> 1;
		relocation_offset=data_relocations LONG relocation_index;

		relocation_index=relocation_n * SIZE_OF_RELOCATION;
	}

relocate_long_pos :: Symbol Int {#Int} Int Int {!Symbol} {#Int} SymbolsArray *{#Char} -> *{#Char};
relocate_long_pos (Module {section_n,module_offset=virtual_label_offset}) index module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a data0
	= add_to_long_at_offset (real_label_offset-virtual_label_offset) index data0;
	{
		real_label_offset=module_offset_a.[first_symbol_n+symbol_n];
	}
relocate_long_pos (Label {label_section_n=section_n,label_offset=offset,label_module_n=module_n}) index module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a data0
	= relocate_long_pos symbol_a.[module_n] index module_offset_a first_symbol_n module_n symbol_a marked_offset_a0 symbols_a data0;
relocate_long_pos (ImportedLabel {implab_file_n=file_n,implab_symbol_n=symbol_n}) index module_offset_a first_symbol_n _ symbol_a marked_offset_a0 symbols_a data0
	| file_n<0
		=	add_to_long_at_offset real_label_offset index data0;
		{
			real_label_offset = module_offset_a.[marked_offset_a0.[file_n + size marked_offset_a0]+symbol_n];
		}
		=	relocate_long_pos_of_module_in_another_module symbols_a.[file_n,symbol_n];
		{
			relocate_long_pos_of_module_in_another_module (Module {section_n})
				= add_to_long_at_offset real_label_offset index data0;
				{
					real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
				}
/*			relocate_long_pos_of_module_in_another_module (Label {label_section_n=section_n,label_offset=offset,label_module_n=module_n})
				= case symbols_a.[file_n,module_n] of {
					Module {section_n,module_offset=v_module_offset}
						-> add_to_long_at_offset (real_label_offset+(offset-v_module_offset)) index data0;
						{
							real_label_offset = module_offset_a.[first_symbol_n+module_n];
						}
				}
*/
			first_symbol_n = marked_offset_a0.[file_n];
		}
relocate_long_pos (ImportedLabelPlusOffset {implaboffs_file_n=file_n,implaboffs_symbol_n=symbol_n,implaboffs_offset=label_offset}) index module_offset_a first_symbol_n _ symbol_a marked_offset_a0 symbols_a data0
		=	case (symbols_a.[file_n,symbol_n]) of {
				Module {section_n}
					-> add_to_long_at_offset (real_label_offset+label_offset) index data0;
					{
						real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
					}
			};
		{
			first_symbol_n = marked_offset_a0.[file_n];
		}

relocate_short_branch :: Symbol Int Int Int {#Int} Int Int {!Symbol} *{#Char} -> *{#Char};
relocate_short_branch (Module {section_n=TEXT_SECTION,module_offset=virtual_label_offset}) index virtual_module_offset
		real_module_offset module_offset_a/*{[o_i]=real_label_offset}*/ first_symbol_n symbol_n symbol_a text0
	= add_to_word_at_offset ((virtual_module_offset-virtual_label_offset)+(real_label_offset-real_module_offset)) index text0;
	{
		o_i=first_symbol_n+symbol_n;
		real_label_offset=module_offset_a.[o_i];
	}
relocate_short_branch (Label {label_section_n=TEXT_SECTION,label_offset=offset,label_module_n=module_n}) index virtual_module_offset real_module_offset module_offset_a first_symbol_n symbol_n symbol_a text0
	= relocate_short_branch symbol_a.[module_n] index virtual_module_offset real_module_offset module_offset_a first_symbol_n module_n symbol_a text0;

relocate_branch :: Symbol Int Int Int {#Int} Int Int {!Symbol} {#Int} SymbolsArray *{#Char} -> *{#Char};
relocate_branch (Module {section_n=TEXT_SECTION,module_offset=virtual_label_offset}) index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a text0
	= add_to_branch_offset_at_offset ((virtual_module_offset-virtual_label_offset)+(real_label_offset-real_module_offset)) index text0;
	{
		real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
	}
relocate_branch (Label {label_section_n=TEXT_SECTION,label_offset=offset,label_module_n=module_n}) index virtual_module_offset 
		real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a text0
	= relocate_branch symbol_a.[module_n] index virtual_module_offset 
		real_module_offset module_offset_a first_symbol_n module_n symbol_a marked_offset_a0 symbols_a text0;
relocate_branch (ImportedLabel {implab_file_n=file_n,implab_symbol_n=symbol_n}) index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 symbols_a text0
	| file_n<0
		= load_toc_after_branch index (add_to_branch_offset_at_offset (virtual_module_offset+(real_label_offset-real_module_offset)) index text0);
		{
			real_label_offset = module_offset_a.[marked_offset_a0.[file_n + size marked_offset_a0]+symbol_n];
		}
		= relocate_branch_to_another_module symbols_a.[file_n,symbol_n] index virtual_module_offset
			real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a text0;
		{
			relocate_branch_to_another_module :: Symbol Int Int Int {#Int} Int Int {!Symbol} {#Int} SymbolsArray *{#Char} -> *{#Char};
			relocate_branch_to_another_module (Module {section_n=TEXT_SECTION}) index virtual_module_offset
					real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a text0
				= add_to_branch_offset_at_offset (virtual_module_offset+(real_label_offset-real_module_offset)) index text0;
				{
					real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
				}
/*
			relocate_branch_to_another_module (Label TEXT_SECTION offset module_n) index virtual_module_offset 
					real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a text0
				= relocate_branch_to_a_label_in_another_module symbol_a.[module_n] index (virtual_module_offset+offset)
					real_module_offset module_offset_a first_symbol_n module_n symbol_a marked_offset_a0 symbols_a text0;

				relocate_branch_to_a_label_in_another_module :: Symbol Int Int Int {#Int} Int Int {!Symbol} {#Int} SymbolsArray *{#Char} -> *{#Char};
				relocate_branch_to_a_label_in_another_module (Module {section_n=TEXT_SECTION,module_offset=v_module_offset} index offset
						real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a text0
					= add_to_branch_offset_at_offset ((offset-v_module_offset)+(real_label_offset-real_module_offset)) index text0;
					{
						real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
					}
*/
			first_symbol_n = marked_offset_a0.[file_n];
		}
relocate_branch (ImportedLabelPlusOffset {implaboffs_file_n=file_n,implaboffs_symbol_n=symbol_n,implaboffs_offset=label_offset}) index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 symbols_a text0
	=	case (symbols_a.[file_n,symbol_n]) of {
			Module {section_n=TEXT_SECTION}
				->	add_to_branch_offset_at_offset (virtual_module_offset+(real_label_offset-real_module_offset)+label_offset) index text0;
				{
					real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
				}	
		};
	{
		first_symbol_n = marked_offset_a0.[file_n];
	}

relocate_toc :: Symbol Symbol Int {#Int} Int Int {#Int} *{#Char} -> *{#Char};
relocate_toc (Module {section_n=TOC_SECTION,module_offset=virtual_label_offset}) (Module {/*section_n=TOC_SECTION,*/module_offset=virtual_toc0_offset}) index
				module_offset_a first_symbol_n symbol_n marked_offset_a text0
	=	add_to_word_at_offset ((virtual_toc0_offset-virtual_label_offset)+real_label_offset-32768) index text0;
	{
		real_label_offset=module_offset_a.[first_symbol_n+symbol_n];
	}
relocate_toc (AliasModule {alias_module_offset,alias_global_module_n}) (Module {/*section_n=TOC_SECTION,*/module_offset=virtual_toc0_offset}) index
				module_offset_a first_symbol_n symbol_n marked_offset_a text0
	=	add_to_word_at_offset ((virtual_toc0_offset-alias_module_offset)+real_label_offset-32768) index text0;
	{
		real_label_offset=module_offset_a.[alias_global_module_n];
	}
relocate_toc (ImportedFunctionDescriptorTocModule {imptoc_offset,imptoc_file_n,imptoc_symbol_n}) (Module {/*section_n=TOC_SECTION,*/module_offset=virtual_toc0_offset}) index
				module_offset_a first_symbol_n symbol_n marked_offset_a text0
	=	add_to_word_at_offset ((virtual_toc0_offset-imptoc_offset)+real_label_offset-32768) index text0;
	{
		real_label_offset=module_offset_a.[marked_offset_a.[imptoc_file_n + size marked_offset_a]+imptoc_symbol_n+1];
	}

relocate_mw_long_pos (Module {section_n,module_offset=virtual_label_offset}) index module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a data0
	= add_to_long_at_offset real_label_offset index data0;
	{
		real_label_offset=module_offset_a.[first_symbol_n+symbol_n];
	}
relocate_mw_long_pos (Label {label_section_n=section_n,label_offset=offset,label_module_n=module_n}) index module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a data0
	= relocate_mw_long_pos symbol_a.[module_n] index module_offset_a first_symbol_n module_n symbol_a marked_offset_a0 symbols_a data0;
relocate_mw_long_pos (ImportedLabel {implab_file_n=file_n,implab_symbol_n=symbol_n}) index module_offset_a first_symbol_n _ symbol_a marked_offset_a0 symbols_a data0
	| file_n<0
		=	add_to_long_at_offset real_label_offset index data0;
		{
			real_label_offset = module_offset_a.[marked_offset_a0.[file_n + size marked_offset_a0]+symbol_n];
		}
		=	relocate_mw_long_pos_of_module_in_another_module symbols_a.[file_n,symbol_n];
		{
			relocate_mw_long_pos_of_module_in_another_module (Module {section_n})
				= add_to_long_at_offset real_label_offset index data0;
				{
					real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
				}
			first_symbol_n = marked_offset_a0.[file_n];
		}
relocate_mw_long_pos (ImportedLabelPlusOffset {implaboffs_file_n=file_n,implaboffs_symbol_n=symbol_n,implaboffs_offset=label_offset}) index module_offset_a first_symbol_n _ symbol_a marked_offset_a0 symbols_a data0
		=	case (symbols_a.[file_n,symbol_n]) of {
				Module {section_n}
					-> add_to_long_at_offset (real_label_offset+label_offset) index data0;
					{
						real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
					}
			};
		{
			first_symbol_n = marked_offset_a0.[file_n];
		}

relocate_mw_short_branch (Module {section_n=TEXT_SECTION}) index virtual_module_offset real_module_offset module_offset_a/*{[o_i]=real_label_offset}*/ first_symbol_n symbol_n symbol_a text0
	= add_to_word_at_offset (virtual_module_offset+real_label_offset-(real_module_offset+index)) index text0;
	{
		o_i=first_symbol_n+symbol_n;
		real_label_offset=module_offset_a.[o_i];
	}
relocate_mw_short_branch (Label {label_section_n=TEXT_SECTION,label_offset=offset,label_module_n=module_n}) index virtual_module_offset real_module_offset module_offset_a first_symbol_n symbol_n symbol_a text0
	= relocate_mw_short_branch symbol_a.[module_n] index virtual_module_offset real_module_offset module_offset_a first_symbol_n module_n symbol_a text0;

relocate_mw_branch (Module {section_n=TEXT_SECTION}) index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a text0
	= add_to_branch_offset_at_offset (virtual_module_offset+real_label_offset-(real_module_offset+index)) index text0;
	{
		real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
	}
relocate_mw_branch (Label {label_section_n=TEXT_SECTION,label_offset=offset,label_module_n=module_n}) index virtual_module_offset 
		real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a text0
	= relocate_mw_branch symbol_a.[module_n] index virtual_module_offset 
		real_module_offset module_offset_a first_symbol_n module_n symbol_a marked_offset_a0 symbols_a text0;
relocate_mw_branch (ImportedLabel {implab_file_n=file_n,implab_symbol_n=symbol_n}) index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 symbols_a text0
	| file_n<0
		= load_toc_after_branch index (add_to_branch_offset_at_offset (virtual_module_offset+real_label_offset-(real_module_offset+index)) index text0);
		{
			real_label_offset = module_offset_a.[marked_offset_a0.[file_n + size marked_offset_a0]+symbol_n];
		}
		= relocate_branch_to_another_module symbols_a.[file_n,symbol_n] index virtual_module_offset
			real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a text0;
		{
			relocate_branch_to_another_module :: Symbol Int Int Int {#Int} Int Int {!Symbol} {#Int} SymbolsArray *{#Char} -> *{#Char};
			relocate_branch_to_another_module (Module {section_n=TEXT_SECTION}) index virtual_module_offset
					real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a text0
				= add_to_branch_offset_at_offset (virtual_module_offset+real_label_offset-(real_module_offset+index)) index text0;
				{
					real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
				}
			first_symbol_n = marked_offset_a0.[file_n];
		}
relocate_mw_branch (ImportedLabelPlusOffset {implaboffs_file_n=file_n,implaboffs_symbol_n=symbol_n,implaboffs_offset=label_offset}) index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 symbols_a text0
	=	case (symbols_a.[file_n,symbol_n]) of {
			Module {section_n=TEXT_SECTION}
				->	add_to_branch_offset_at_offset (virtual_module_offset+real_label_offset-(real_module_offset+index)+label_offset) index text0;
				{
					real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
				}	
		};
	{
		first_symbol_n = marked_offset_a0.[file_n];
	}

relocate_mw_toc (Module {section_n=TOC_SECTION}) index module_offset_a first_symbol_n symbol_n marked_offset_a text0
	=	add_to_word_at_offset (real_label_offset-32768) index text0;
	{
		real_label_offset=module_offset_a.[first_symbol_n+symbol_n];
	}
relocate_mw_toc (AliasModule {alias_global_module_n}) index module_offset_a first_symbol_n symbol_n marked_offset_a text0
	=	add_to_word_at_offset (real_label_offset-32768) index text0;
	{
		real_label_offset=module_offset_a.[alias_global_module_n];
	}
relocate_mw_toc (ImportedFunctionDescriptorTocModule {imptoc_file_n,imptoc_symbol_n}) index module_offset_a first_symbol_n symbol_n marked_offset_a text0
	=	add_to_word_at_offset (real_label_offset-32768) index text0;
	{
		real_label_offset=module_offset_a.[marked_offset_a.[imptoc_file_n + size marked_offset_a]+imptoc_symbol_n+1];
	}

relocate_trl :: Symbol Symbol Int Int {#Int} Int Int {!Symbol} {#Int} SymbolsArray String *String *String -> (!*String,!*String);
relocate_trl symbol toc0_symbol index data_v_address module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a data_relocations text0 data0
	= case symbol of {
		Module {section_n=TOC_SECTION,length=4,first_relocation_n,end_relocation_n}
			| first_relocation_n+1==end_relocation_n && relocation_type==R_POS && relocation_size==0x1f
				-> relocate_trl1 relocation_index text0 data0;
			{}{
				relocation_index=first_relocation_n * SIZE_OF_RELOCATION;
				
				relocation_type=data_relocations BYTE (relocation_index+9);
				relocation_size=data_relocations BYTE (relocation_index+8);
			}
		AliasModule {alias_first_relocation_n}
			-> relocate_trl1 relocation_index text0 data0;
			{
				relocation_index=alias_first_relocation_n * SIZE_OF_RELOCATION;
			}
		_
			-> (relocate_toc symbol toc0_symbol index module_offset_a first_symbol_n symbol_n marked_offset_a0 text0,data0);
	};
	{
		relocate_trl1 :: Int !*String !*String -> (!*String,!*String);
		relocate_trl1 relocation_index text0 data0
			#! (offset,data1)=read_long data0 (relocation_offset-data_v_address);
			= relocate_trl2 symbol_a.[relocation_symbol_n] first_symbol_n relocation_symbol_n offset text0 data1;
		{
			relocation_symbol_n=(inc (data_relocations LONG (relocation_index+4))) >> 1;
			relocation_offset=data_relocations LONG relocation_index;
		

			relocate_trl2 :: Symbol Int Int !Int !*String !*String -> (!*String,!*String);
			relocate_trl2 (Module {section_n,module_offset=virtual_label_offset}) first_symbol_n symbol_n offset text0 data1
				= relocate_trl3 section_n new_offset text0 data1;
				{
					new_offset = real_label_offset+offset-virtual_label_offset;
					real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
				}
			relocate_trl2 (Label {label_offset/*=offset ???*/,label_module_n=module_n}) first_symbol_n symbol_n offset text0 data1
				= relocate_trl2 symbol_a.[module_n] first_symbol_n module_n offset text0 data1;
			relocate_trl2 (ImportedLabel {implab_file_n=imported_file_n,implab_symbol_n=imported_symbol_n}) first_symbol_n symbol_n offset text0 data1
				| imported_file_n<0
					=	(relocate_toc symbol toc0_symbol index module_offset_a first_symbol_n symbol_n marked_offset_a0 text0,data1);
					=	case (symbols_a.[imported_file_n,imported_symbol_n]) of {
							Module {section_n}
								-> relocate_trl3 section_n new_offset text0 data1;
						};
						{
							new_offset=real_label_offset+offset;
							real_label_offset = module_offset_a.[marked_offset_a0.[imported_file_n]+imported_symbol_n];
						}
			relocate_trl2 (ImportedLabelPlusOffset {implaboffs_file_n=imported_file_n,implaboffs_symbol_n=imported_symbol_n,implaboffs_offset=label_offset}) first_symbol_n symbol_n offset text0 data1
				=	case (symbols_a.[imported_file_n,imported_symbol_n]) of {
						Module {section_n}
							-> relocate_trl3 section_n new_offset text0 data1;
					};
					{
						new_offset=real_label_offset+label_offset+offset;
						real_label_offset = module_offset_a.[marked_offset_a0.[imported_file_n]+imported_symbol_n];
					}

			relocate_trl3 :: Int Int !*String !*String -> (!*String,!*String);
			relocate_trl3 section_n new_offset text0 data1
				| (section_n==DATA_SECTION || section_n==BSS_SECTION) && (new_offset bitand 0xffff)==new_offset
					= (change_lwz_to_addi (new_offset-32768) index text0,data1);
					= (relocate_toc symbol toc0_symbol index module_offset_a first_symbol_n symbol_n marked_offset_a0 text0,data1);
		}
	}

change_lwz_to_addi :: Int Int *{#Char} -> *{#Char};
change_lwz_to_addi w index array//=:{[index_2]=a_i_2}
	#! a_i_2	= array.[index_2]
	| (toInt a_i_2 bitand 252) == 128
		= {array & [index_2]=toChar ((toInt a_i_2 bitand 3) bitor 56),[index]=toChar (w>>8),[index1]=toChar w};
	{}{
		index_2 = index-2;
		index1 = inc index;
	}

add_to_word_at_offset :: Int Int *{#Char} -> *{#Char};
add_to_word_at_offset w index array=:{[index]=v0}
	#!	v1 = array.[index1];
		v = (toInt v0<<8) + (toInt v1);
		new_v=v+w;
	= {array & [index]=toChar (new_v>>8),[index1]=toChar new_v};{
		index1 = inc index;
	}

add_to_branch_offset_at_offset :: Int Int *{#Char} -> *{#Char};
add_to_branch_offset_at_offset w index array=:{[index]=v0}
	#!	v1 = array.[index1];
		v2 = array.[index2];
		v3 = array.[index3];
		v = ((toInt v0 bitand 3)<<24)+(toInt v1<<16)+(toInt v2<<8)+(toInt v3);
		new_v=v+w;
		new_v0 = toChar ((toInt v0 bitand 0xfc) bitor ((new_v>>24) bitand 3));
	= {array & [index]=new_v0,[index1]=toChar (new_v>>16),[index2]=toChar (new_v>>8),[index3]=toChar (new_v)};
	{
		index1 = index+1;
		index2 = index+2;
		index3 = index+3;
	}

add_to_long_at_offset :: Int Int *{#Char} -> *{#Char};
add_to_long_at_offset w index array=:{[index]=v0}
	#!	v1 = array.[index1];
		v2 = array.[index2];
		v3 = array.[index3];
		v = (toInt v0<<24) + (toInt v1<<16)+(toInt v2<<8)+toInt v3;
		new_v=v+w;
	= {array & [index]=toChar (new_v>>24),[index1]=toChar (new_v>>16),[index2]=toChar (new_v>>8),[index3]=toChar new_v};{
		index1=index+1;
		index2=index+2;
		index3=index+3;
	}

load_toc_after_branch :: Int *{#Char} -> *{#Char};
load_toc_after_branch index text0//=:{[index4]=n0,[index5]=n1,[index6]=n2,[index7]=n3}
	#!	n0 = text0.[index4];
		n1 = text0.[index5];
		n2 = text0.[index6];
		n3 = text0.[index7];
	| n0==toChar 0x60 && n1=='\0' && n2=='\0' && n3=='\0'
		= {text0 & [index4]=toChar 0x80,[index5]=toChar 0x41,[index6]=toChar 0x00,[index7]=toChar 0x14};
	{}{
		index4=index+4;
		index5=index+5;
		index6=index+6;
		index7=index+7;
	}

write_toc_to_pef_files :: [*String] [Xcoff] Int Int {#Bool} {#Int} {#Int} SymbolsArray *File -> (!Int,![*{#Char}],!*File);
write_toc_to_pef_files [] [] first_symbol_n offset0 marked_bool_a module_offset_a marked_offset_a symbols_a pef_file0
	= (offset0,[],pef_file0);
write_toc_to_pef_files [data_section:data_section_list] [xcoff=:{n_symbols,header={data_v_address},symbol_table={toc_symbols,symbols},data_relocations}:xcoff_list] first_symbol_n offset0 marked_bool_a module_offset_a marked_offset_a symbols_a pef_file0
	= (offset2,[data_section_a : data_section_list1],pef_file2); {
		(offset2,data_section_list1,pef_file2)
			= write_toc_to_pef_files data_section_list xcoff_list (first_symbol_n+n_symbols) offset1 marked_bool_a module_offset_a marked_offset_a symbols_a pef_file1;
		(data_section_a,offset1,pef_file1)
			= write_toc_or_data_to_pef_file toc_symbols first_symbol_n offset0 data_v_address symbols data_relocations marked_bool_a
					module_offset_a marked_offset_a symbols_a data_section pef_file0;
	}

write_data_to_pef_files :: [*{#Char}] [Xcoff] Int Int {#Bool} {#Int} {#Int} SymbolsArray *File -> *File;
write_data_to_pef_files [] [] first_symbol_n offset0 marked_bool_a module_offset_a marked_offset_a symbols_a pef_file0
	= pef_file0;
write_data_to_pef_files [data_section_a:data_section_list] [xcoff=:{n_symbols,header={data_v_address},symbol_table={data_symbols,symbols},data_relocations}:xcoff_list] first_symbol_n offset0 marked_bool_a module_offset_a marked_offset_a symbols_a pef_file0
	= write_data_to_pef_files data_section_list xcoff_list (first_symbol_n+n_symbols) offset1 marked_bool_a module_offset_a marked_offset_a symbols_a pef_file1; {
		(_,offset1,pef_file1)
			= write_toc_or_data_to_pef_file data_symbols first_symbol_n offset0 data_v_address symbols data_relocations marked_bool_a
					module_offset_a marked_offset_a symbols_a data_section_a pef_file0;
	}

	write_toc_or_data_to_pef_file :: SymbolIndexList Int Int Int SymbolArray String {#Bool} {#Int} {#Int} SymbolsArray *{#Char} *File -> (!*{#Char},!Int,!*File);
	write_toc_or_data_to_pef_file EmptySymbolIndex first_symbol_n offset0 data_v_address symbol_table data_relocations marked_bool_a module_offset_a marked_offset_a0 symbols_a data_a0 pef_file0
		= (data_a0,offset0,pef_file0);
	write_toc_or_data_to_pef_file (SymbolIndex module_n symbol_list) first_symbol_n offset0 data_v_address symbol_table=:{[module_n] = symbol} data_relocations marked_bool_a module_offset_a marked_offset_a0 symbols_a data_a0 pef_file0
		| marked_bool_a.[first_symbol_n+module_n]
			= write_toc_or_data_to_pef_file symbol_list first_symbol_n offset1 data_v_address symbol_table data_relocations marked_bool_a module_offset_a marked_offset_a0 symbols_a data_a1 pef_file1;
			{
				(data_a1,offset1,pef_file1) = write_data_module_to_pef_file symbol offset0 module_offset_a marked_offset_a0 symbols_a data_a0 pef_file0;
			};
			= write_toc_or_data_to_pef_file symbol_list first_symbol_n offset0 data_v_address symbol_table data_relocations marked_bool_a module_offset_a marked_offset_a0 symbols_a data_a0 pef_file0;
		{}{
			write_data_module_to_pef_file :: Symbol Int {#Int} {#Int} SymbolsArray *{#Char} *File -> (!*{#Char},!Int,!*File);
			write_data_module_to_pef_file (Module {section_n,module_offset=virtual_module_offset,length,first_relocation_n,end_relocation_n,align=alignment})
					offset0 module_offset_a/*=:{[o_i]=real_module_offset}*/ marked_offset_a0 symbols_a data_a0 pef_file0
				| section_n==DATA_SECTION || section_n==TOC_SECTION
					= (data_a2,aligned_offset0+length,fwrites data_string (write_zero_bytes_to_file (aligned_offset0-offset0) pef_file0));
				{}{
					(data_string,data_a2) = u_char_array_slice data_a1 offset (offset+length-1);
					offset=virtual_module_offset-data_v_address;
					o_i=first_symbol_n+module_n;
					real_module_offset=module_offset_a.[o_i];
					
					aligned_offset0=(offset0+alignment_mask) bitand (bitnot alignment_mask);
					alignment_mask=dec (1<<alignment);
					
					data_a1 = relocate_data first_relocation_n end_relocation_n virtual_module_offset data_v_address real_module_offset data_relocations
											first_symbol_n module_offset_a marked_offset_a0 symbol_table symbols_a data_a0;
				}
			write_data_module_to_pef_file (AliasModule _) offset0 module_offset_a marked_offset_a0 symbols_a data_a0 pef_file0
				=	(data_a0,offset0,pef_file0);
			write_data_module_to_pef_file (ImportedFunctionDescriptorTocModule _) offset0 module_offset_a marked_offset_a0 symbols_a data_a0 pef_file0
				=	(data_a0,offset0,pef_file0);
		}

(THEN) infixl;
(THEN) a f :== f a;

write_xcoff_loader library_list n_libraries n_imported_symbols string_table_file_names_size string_table_size main_offset
				n_loader_relocations loader_relocations xcoff_file0
	=	xcoff_file1
			THEN write_symbol_table library_list 0 1
			THEN write_loader_relocations_for_imported_symbols 0 n_imported_symbols
			THEN write_xcoff_loader_relocations loader_relocations
			FWC '\0' FWC '\0' FWC '\0'
			THEN write_library_file_names library_list
			THEN write_symbol_string_table library_list
			THEN write_zero_bytes_to_file (aligned_string_table_size-string_table_size)
			FWI 0;
	{

		xcoff_file1 = xcoff_file0
			FWI 1 FWI n_imported_symbols FWI (n_loader_relocations+n_imported_symbols) FWI import_file_list_length FWI (1+n_libraries) 
			FWI loader_import_offset FWI string_table_size FWI (loader_import_offset+import_file_list_length);

		aligned_string_table_size=(string_table_size+3) bitand (-4);

		loader_import_offset=32+24*n_imported_symbols+12*(n_loader_relocations+n_imported_symbols);
		import_file_list_length=3+string_table_file_names_size;
		
		write_loader_relocations_for_imported_symbols symbol_n n_symbols xcoff_file
			| n_symbols==0
				= xcoff_file;
				= write_loader_relocations_for_imported_symbols (inc symbol_n) (dec n_symbols)
					(xcoff_file FWI (symbol_n<<2) FWI (3+symbol_n) FWI 0x1F000002);
	
		write_library_file_names EmptyLibraryList pef_file0
			= pef_file0;
		write_library_file_names (Library file_name _ _ libraries) pef_file0
			= write_library_file_names libraries (pef_file0 FWC '\0' FWS file_name FWC '\0' FWC '\0');
			
		write_symbol_table EmptyLibraryList string_table_offset0 file_number xcoff_file0
			= xcoff_file0;
		write_symbol_table (Library _ imported_symbols _ libraries) string_table_offset0 file_number xcoff_file0
			= write_symbol_table libraries string_table_offset1 (inc file_number) xcoff_file1;
			{
				(string_table_offset1,xcoff_file1) = write_symbol_table_entries imported_symbols string_table_offset0 xcoff_file0;

				write_symbol_table_entries :: LibrarySymbolsList Int *File -> (!Int,!*File);
				write_symbol_table_entries EmptyLibrarySymbolsList string_table_offset0 xcoff_file0
					= (string_table_offset0,xcoff_file0);
				write_symbol_table_entries (LibrarySymbol symbol_name symbols) string_table_offset0 xcoff_file0
					| size symbol_name<=8
						= write_symbol_table_entries symbols string_table_offset0
							(xcoff_file0 FWS symbol_name FWZ (8 - size symbol_name) FWI 0 FWI 0x00004000 FWI file_number FWI 0);
						= write_symbol_table_entries symbols (3 + size symbol_name + string_table_offset0)
							(xcoff_file0 FWI 0 FWI (string_table_offset0+2) FWI 0 FWI 0x00004000 FWI file_number FWI 0);
			}
			
		
		write_symbol_string_table EmptyLibraryList pef_file0
			= pef_file0;
		write_symbol_string_table (Library _ imported_symbols _ libraries) pef_file0
			= write_symbol_string_table libraries (write_symbol_strings imported_symbols pef_file0);
		
			write_symbol_strings EmptyLibrarySymbolsList pef_file0
				= pef_file0;
			write_symbol_strings (LibrarySymbol symbol_name symbols) pef_file0
				| size symbol_name<=8
					= write_symbol_strings symbols pef_file0;
					= write_symbol_strings symbols (pef_file0 FWC (toChar (inc_symbol_name_length>>8)) FWC (toChar inc_symbol_name_length) FWS symbol_name FWC '\0');
					{
						inc_symbol_name_length=inc (size symbol_name);
					}
	}

compute_xcoff_string_table_size :: LibraryList Int Int Int Int !{#Bool} -> (!Int,!Int,!Int);
compute_xcoff_string_table_size EmptyLibraryList string_table_file_names_size string_table_symbol_names_size0 n_imported_symbols0 symbol_n marked_bool_a
	=	(string_table_file_names_size,string_table_symbol_names_size0,n_imported_symbols0);
compute_xcoff_string_table_size (Library file_name imported_symbols _ libraries) string_table_file_names_size string_table_symbol_names_size0 n_imported_symbols0 symbol_n0 marked_bool_a
	=	compute_xcoff_string_table_size libraries (3 + size file_name + string_table_file_names_size) string_table_symbol_names_size1 n_imported_symbols1 symbol_n1 marked_bool_a;
	{
		(string_table_symbol_names_size1,n_imported_symbols1,symbol_n1)
			= string_table_size_of_symbol_names imported_symbols string_table_symbol_names_size0 n_imported_symbols0 symbol_n0;
		
		string_table_size_of_symbol_names :: LibrarySymbolsList Int Int Int -> (!Int,!Int,!Int);
		string_table_size_of_symbol_names EmptyLibrarySymbolsList string_table_symbol_names_size0 n_imported_symbols0 symbol_n
			= (string_table_symbol_names_size0,n_imported_symbols0,symbol_n);
		string_table_size_of_symbol_names (LibrarySymbol symbol_name imported_symbols) string_table_symbol_names_size0 n_imported_symbols0 symbol_n
			| not marked_bool_a.[symbol_n]
				= string_table_size_of_symbol_names imported_symbols string_table_symbol_names_size0 n_imported_symbols0 (symbol_n+2);
			| size symbol_name<=8
				= string_table_size_of_symbol_names imported_symbols string_table_symbol_names_size0 (inc n_imported_symbols0) (symbol_n+2);
				= string_table_size_of_symbol_names imported_symbols (3 + size symbol_name + string_table_symbol_names_size0) (inc n_imported_symbols0) (symbol_n+2);
	}

write_zero_longs_to_file n pef_file0
	| n==0
		= pef_file0;
		= write_zero_longs_to_file (dec n) (fwritei 0 pef_file0);

write_zero_bytes_to_file n pef_file0
	| n==0
		= pef_file0;
		= write_zero_bytes_to_file (dec n) (fwritec '\0' pef_file0);


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
		= [a_i : xcoff_array_to_list (inc i) a2];
		{
			(a_i,a2)=replace a0 i empty_xcoff;
		}

mark_modules :: !Int !Int !*[*Xcoff] !Int !Int !Int !LibraryList -> (![String],!Int,!{#Bool},!{#Int},!*{#*Xcoff});
mark_modules main_symbol_n main_file_n xcoff_list1 n_xcoff_files n_libraries n_library_symbols library_list0
	= (undefined_symbols,n_xcoff_symbols,marked_bool_a1,marked_offset_a0,xcoff_a1);
{
	(undefined_symbols,marked_bool_a1,xcoff_a1)	= mark_used_modules main_symbol_n main_file_n marked_bool_a0 marked_offset_a0 xcoff_a;
	(marked_bool_a0,marked_offset_a0,xcoff_a)	= create_xcoff_boolean_array n_xcoff_files n_xcoff_symbols n_libraries n_library_symbols
																				library_list0 xcoff_list2;

	(n_xcoff_symbols,xcoff_list2)				= n_symbols_of_xcoff_list 0 xcoff_list1;
}

write_output_file :: !Bool .{#Char} .Int !.Int !.Int !.LibraryList !.Int !.Int .Bool !*Sections !.Int !{#.Bool} !{#.Int} !*{#*Xcoff} *Files -> (!Bool,!String,Int,Int,*Files);
write_output_file generate_xcoff application_file_name n_xcoff_files n_libraries n_library_symbols library_list0
		main_symbol_n main_file_n one_pass_link sections n_xcoff_symbols marked_bool_a1 marked_offset_a0 xcoff_a1 files2
	| not generate_xcoff
		= write_pef_file   application_file_name n_xcoff_files n_libraries n_library_symbols library_list0 
							main_symbol_n main_file_n one_pass_link sections 
							n_xcoff_symbols marked_bool_a1 marked_offset_a0 xcoff_a1 files2;
/*		= write_xcoff_file application_file_name n_xcoff_files n_libraries n_library_symbols library_list0
							main_symbol_n main_file_n one_pass_link sections
							n_xcoff_symbols marked_bool_a1 marked_offset_a0 xcoff_a1 files2;
*/

write_xcoff_file :: .{#Char} .Int !.Int !.Int !.LibraryList .Int .Int .Bool !*Sections !.Int {#.Bool} {#.Int} !*{#*Xcoff} *Files -> *(!Bool,!String,Int,*Files);
write_xcoff_file application_file_name n_xcoff_files n_libraries n_library_symbols library_list0 
		main_symbol_n main_file_n one_pass_link sections
		n_xcoff_symbols marked_bool_a1 marked_offset_a0 xcoff_a1
		files2
	= (ok,"",/* pef_text_section_size2 + */ pef_bss_section_end1,files5);
	{
	(ok,files5)=fclose pef_file7 files4;
	pef_file7 = pef_file4
		THEN write_data_to_pef_files data_sections1 xcoff_list5 0 end_toc_offset marked_bool_a1 module_offset_a3 marked_offset_a0 symbols_a
		THEN write_zero_bytes_to_file (pef_data_section_size1-pef_data_section_size0)
//		THEN write_zero_longs_to_file ((pef_bss_section_end1-pef_data_section_size1)>>2)
		THEN write_xcoff_loader library_list1 n_libraries n_imported_symbols string_table_file_names_size string_table_size
				main_offset n_loader_relocations loader_relocations;
	
	(end_toc_offset,data_sections1,pef_file4)
		= write_toc_to_pef_files data_sections0 xcoff_list5 0 (n_imported_symbols<<2) marked_bool_a1 module_offset_a3 marked_offset_a0 symbols_a pef_file3;

	pef_file3 = pef_file1
		THEN write_imported_library_functions_code library_list1 0
		THEN write_zero_bytes_to_file (pef_text_section_size2-pef_text_section_size1)
	 	THEN write_zero_longs_to_file n_imported_symbols;

	(data_sections0,pef_file1,files4,xcoff_list5)
		= write_code_to_output_files xcoff_list4 0 marked_bool_a1 module_offset_a3 marked_offset_a0 symbols_a one_pass_link sections1 pef_file0 files3;

	xcoff_loader_section_size = 32+24*n_imported_symbols+12*(n_loader_relocations+n_imported_symbols)+3+string_table_file_names_size+string_table_size;
	(pef_file0,files3)
		= create_xcoff_file application_file_name pef_text_section_size1 pef_data_section_size1 (pef_bss_section_end1-pef_data_section_size1)
							xcoff_loader_section_size main_offset files2;

	(n_loader_relocations,loader_relocations) = count_and_reverse_relocations loader_relocations0;
	loader_relocations0 = compute_xcoff_loader_relocations xcoff_list4 marked_bool_a1 module_offset_a3 marked_offset_a0 symbols_a;

	main_offset=module_offset_a3.[marked_offset_a0.[main_file_n]+main_symbol_n];
	
	pef_text_section_size2=(pef_text_section_size1+3) bitand (-4);
	(library_list1,pef_text_section_size1,module_offset_a3)
		= compute_imported_library_symbol_offsets library_list0 pef_text_section_size0 n_xcoff_symbols marked_bool_a1 module_offset_a2;

	pef_bss_section_end1 = (pef_bss_section_end0+3) bitand (-4);
	(pef_bss_section_end0,module_offset_a2)
		= compute_bss_module_offsets xcoff_list4 pef_data_section_size1 0 marked_bool_a1 module_offset_a1;

	pef_data_section_size1 = (pef_data_section_size0+3) bitand (-4);
	
	(pef_data_section_size0,module_offset_a1)
		= compute_data_module_offsets xcoff_list4 pef_toc_section_size0 0 module_offset_a0;
	(pef_text_section_size0,pef_toc_section_size0,module_offset_a0)
		= compute_module_offsets (n_xcoff_symbols+n_library_symbols) xcoff_list4 (n_imported_symbols<<2) marked_bool_a1;

	symbols_a = xcoff_list_to_symbols_array n_xcoff_files xcoff_list4;	

	(string_table_file_names_size,string_table_size,n_imported_symbols)
		= compute_xcoff_string_table_size library_list0 0 0 0 n_xcoff_symbols marked_bool_a1 ;

	(sections1,xcoff_list4,toc_table)
		= split_data_symbol_lists_of_files2 marked_offset_a0 marked_bool_a1 sections xcoff_list3 EmptyTocTable;

//	(marked_bool_a1,xcoff_list3) = mark_toc0_symbols 0 marked_bool_a1_ xcoff_list3_;

	xcoff_list3 = xcoff_array_to_list 0 xcoff_a1;
}

write_pef_file :: .{#Char} .Int !.Int !.Int !.LibraryList !.Int !.Int .Bool !*Sections !.Int {#.Bool} !{#.Int} !*{#*Xcoff} *Files -> *(!Bool,!String,Int,Int,*Files);
write_pef_file application_file_name n_xcoff_files n_libraries n_library_symbols library_list0 main_symbol_n main_file_n one_pass_link sections 
				n_xcoff_symbols marked_bool_a1 marked_offset_a0 xcoff_a1 files2
	| not open_pef_file_ok
		= (False,"Error creating or opening application file "+++application_file_name,0,0,files3);
	| not ok
		= (False,"Error writing application file",pef_bss_section_end1,end_toc_offset,files5);
		= (True,"",pef_bss_section_end1,end_toc_offset,files5);
	{}{
	(ok,files5)=fclose pef_file7 files4;
	pef_file7 = pef_file4
		THEN write_data_to_pef_files data_sections1 xcoff_list5 0 end_toc_offset marked_bool_a1 module_offset_a3 marked_offset_a0 symbols_a
		THEN write_zero_bytes_to_file (pef_data_section_size1-pef_data_section_size0)
		THEN write_zero_longs_to_file ((pef_bss_section_end1-pef_data_section_size1)>>2)
		THEN write_zero_bytes_to_file (((pef_bss_section_end1+15) bitand (-16))-pef_bss_section_end1)
		THEN write_pef_loader library_list1 n_libraries n_imported_symbols string_table_file_names_size string_table_symbol_names_size 
				main_offset n_loader_relocations loader_relocations;
	
	(end_toc_offset,data_sections1,pef_file4)
		= write_toc_to_pef_files data_sections0 xcoff_list5 0 (n_imported_symbols<<2) marked_bool_a1 module_offset_a3 marked_offset_a0 symbols_a pef_file3;

	pef_file3 = pef_file1
		THEN write_imported_library_functions_code library_list1 0
		THEN write_zero_bytes_to_file (((pef_text_section_size1+15) bitand (-16))-pef_text_section_size1)
	 	THEN write_zero_longs_to_file n_imported_symbols;

	(data_sections0,pef_file1,files4,xcoff_list5)
		= write_code_to_output_files xcoff_list4 0 marked_bool_a1 module_offset_a3 marked_offset_a0 symbols_a one_pass_link sections1 pef_file0 files3;
	
	pef_loader_section_size = 56+24*n_libraries+(n_imported_symbols<<2)+(n_loader_relocations<<1)+12+aligned_string_table_size+4;
	(open_pef_file_ok,pef_file0,files3)
		= create_pef_file application_file_name pef_text_section_size1 pef_bss_section_end1 pef_loader_section_size files2;

	(n_loader_relocations,loader_relocations) = count_and_reverse_relocations loader_relocations0;

	loader_relocations0 = compute_pef_loader_relocations xcoff_list4 marked_bool_a1 module_offset_a3 marked_offset_a0 symbols_a n_imported_symbols;

	symbols_a = xcoff_list_to_symbols_array n_xcoff_files xcoff_list4;

	main_offset=module_offset_a3.[marked_offset_a0.[main_file_n]+main_symbol_n];
	
	(library_list1,pef_text_section_size1,module_offset_a3)
		= compute_imported_library_symbol_offsets library_list0 pef_text_section_size0 n_xcoff_symbols marked_bool_a1 module_offset_a2;

	pef_bss_section_end1 = (pef_bss_section_end0+3) bitand (-4);
	(pef_bss_section_end0,module_offset_a2)
		= compute_bss_module_offsets xcoff_list4 pef_data_section_size1 0 marked_bool_a1 module_offset_a1;

	pef_data_section_size1 = (pef_data_section_size0+3) bitand (-4);
	
	(pef_data_section_size0,module_offset_a1)
		= compute_data_module_offsets xcoff_list4 pef_toc_section_size0 0 module_offset_a0;
	(pef_text_section_size0,pef_toc_section_size0,module_offset_a0)
		= compute_module_offsets (n_xcoff_symbols+n_library_symbols) xcoff_list4 (n_imported_symbols<<2) marked_bool_a1;

	aligned_string_table_size=(string_table_size+3) bitand (-4);
	string_table_size=string_table_file_names_size+string_table_symbol_names_size;

	(sections1,xcoff_list4,toc_table)
		= split_data_symbol_lists_of_files2 marked_offset_a0 marked_bool_a1 sections xcoff_list3 EmptyTocTable;

	xcoff_list3 = xcoff_array_to_list 0 xcoff_a1;
	
	(string_table_file_names_size,string_table_symbol_names_size,n_imported_symbols)
		= compute_pef_string_table_size library_list0 0 0 0 n_xcoff_symbols marked_bool_a1;
}

compute_pef_string_table_size :: LibraryList Int Int Int Int !{#Bool} -> (!Int,!Int,!Int);
compute_pef_string_table_size EmptyLibraryList string_table_file_names_size string_table_symbol_names_size0 n_imported_symbols0 symbol_n marked_bool_a
	=	(string_table_file_names_size,string_table_symbol_names_size0,n_imported_symbols0);
compute_pef_string_table_size (Library file_name imported_symbols _ libraries) string_table_file_names_size string_table_symbol_names_size0 n_imported_symbols0 symbol_n0 marked_bool_a
	=	compute_pef_string_table_size libraries (1 + size file_name + string_table_file_names_size) string_table_symbol_names_size1 n_imported_symbols1 symbol_n1 marked_bool_a;
	{
		(string_table_symbol_names_size1,n_imported_symbols1,symbol_n1)
			= string_table_size_of_symbol_names imported_symbols string_table_symbol_names_size0 n_imported_symbols0 symbol_n0;
		
		string_table_size_of_symbol_names :: LibrarySymbolsList Int Int Int -> (!Int,!Int,!Int);
		string_table_size_of_symbol_names EmptyLibrarySymbolsList string_table_symbol_names_size0 n_imported_symbols0 symbol_n
			= (string_table_symbol_names_size0,n_imported_symbols0,symbol_n);
		string_table_size_of_symbol_names (LibrarySymbol symbol_name imported_symbols) string_table_symbol_names_size0 n_imported_symbols0 symbol_n
			| marked_bool_a.[symbol_n]
				= string_table_size_of_symbol_names imported_symbols (1 + size symbol_name + string_table_symbol_names_size0) (inc n_imported_symbols0) (symbol_n+2);
				= string_table_size_of_symbol_names imported_symbols string_table_symbol_names_size0 n_imported_symbols0 (symbol_n+2);
	}

write_pef_loader library_list n_libraries n_imported_symbols string_table_file_names_size string_table_symbol_names_size main_offset
				n_loader_relocations loader_relocations pef_file0
	=	pef_file1
			THEN write_library_table library_list 0 0
			THEN write_symbol_table library_list string_table_file_names_size
			FWI 0x10000 FWI n_loader_relocations FWI 0
			THEN write_loader_relocations loader_relocations
			THEN write_library_file_names library_list
			THEN write_symbol_string_table library_list
			THEN write_zero_bytes_to_file (aligned_string_table_size-string_table_size)
			FWI 0;
	{
		pef_file1 = fwritei 0 (fwritei 0 (fwritei slot_table_offset (fwritei string_table_offset (fwritei relocation_table_offset (fwritei 1 (
					fwritei n_imported_symbols (fwritei n_libraries (fwritei 0 (fwritei (-1) (fwritei 0 (fwritei (-1) (fwritei main_offset (fwritei 1 pef_file0)))))))))))));

		aligned_string_table_size=(string_table_size+3) bitand (-4);
		string_table_size=string_table_file_names_size+string_table_symbol_names_size;

		relocation_table_offset = 56+n_libraries*24+(n_imported_symbols<<2)+12;
		string_table_offset = relocation_table_offset+(n_loader_relocations<<1);
		slot_table_offset = string_table_offset+aligned_string_table_size;

		write_library_table EmptyLibraryList string_table_offset first_symbol_n pef_file0
			= pef_file0;
		write_library_table (Library file_name _ n_imported_symbols2 libraries) string_table_offset first_symbol_n pef_file0
			= write_library_table libraries (string_table_offset + 1 + size file_name) (first_symbol_n+n_imported_symbols) pef_file1;
			{
				pef_file1 = fwritei 0 (fwritei first_symbol_n (fwritei n_imported_symbols (fwritei 0 (fwritei 0 (fwritei string_table_offset pef_file0)))));
				n_imported_symbols = n_imported_symbols2>>1;
			}
	
		write_library_file_names EmptyLibraryList pef_file0
			= pef_file0;
		write_library_file_names (Library file_name _ _ libraries) pef_file0
			= write_library_file_names libraries (fwritec '\0' (fwrites file_name pef_file0));
			
		write_symbol_table EmptyLibraryList string_table_offset0 pef_file0
			= pef_file0;
		write_symbol_table (Library _ imported_symbols _ libraries) string_table_offset0 pef_file0
			= write_symbol_table libraries string_table_offset1 pef_file1;
			{
				(string_table_offset1,pef_file1) = write_symbol_table_entries imported_symbols string_table_offset0 pef_file0;
			}
			
			write_symbol_table_entries :: LibrarySymbolsList Int *File -> (!Int,!*File);
			write_symbol_table_entries EmptyLibrarySymbolsList string_table_offset0 pef_file0
				= (string_table_offset0,pef_file0);
			write_symbol_table_entries (LibrarySymbol symbol_name symbols) string_table_offset0 pef_file0
				= write_symbol_table_entries symbols (1 + size symbol_name + string_table_offset0) (fwritei (0x2000000+string_table_offset0) pef_file0);
		
		write_symbol_string_table EmptyLibraryList pef_file0
			= pef_file0;
		write_symbol_string_table (Library _ imported_symbols _ libraries) pef_file0
			= write_symbol_string_table libraries (write_symbol_strings imported_symbols pef_file0);
		
			write_symbol_strings EmptyLibrarySymbolsList pef_file0
				= pef_file0;
			write_symbol_strings (LibrarySymbol symbol_name symbols) pef_file0
				= write_symbol_strings symbols (fwritec '\0' (fwrites symbol_name pef_file0));
	}

create_pef_file :: !String Int Int Int !*Files -> *(!Bool,*File,*Files);
create_pef_file pef_file_name text_section_size data_section_size loader_section_size files0
	# (ok,file0,files1) = fopen pef_file_name FWriteData files0;
	| not ok
		= (False,file0,files1);
	#	aligned_text_section_size=(text_section_size+15) bitand (-16);
		aligned_data_section_size=(data_section_size+15) bitand (-16);
		file1 = file0
			FWS "Joy!peffpwpc" FWI 1 FWI 0 FWI 0 FWI 0 FWI 0 FWI 0x30002 FWI 0
			FWI (-1) FWI 0 FWI text_section_size FWI text_section_size FWI text_section_size FWI 128 FWI 0x00010200
			FWI (-1) FWI 0 FWI data_section_size FWI data_section_size FWI data_section_size FWI (128+aligned_text_section_size) FWI 0x01010300
			FWI (-1) FWI 0 FWI 0 FWI 0 FWI loader_section_size FWI (128+aligned_text_section_size+aligned_data_section_size) FWI 0x04010000
			FWI 0;
	= (True,file1,files1);

write_loader_relocations :: !LoaderRelocations !*File -> *File;
write_loader_relocations EmptyRelocation pef_file0
	= pef_file0;
write_loader_relocations (CodeRelocation i relocations) pef_file0
	= write_loader_relocations relocations (fwritec (toChar deci) (fwritec (toChar (0x40+(deci>>8))) pef_file0)); {
		deci =  dec i;
	}
write_loader_relocations (DataRelocation i relocations) pef_file0
	= write_loader_relocations relocations (fwritec (toChar deci) (fwritec (toChar (0x42+(deci>>8))) pef_file0)); {
		deci =  dec i;
	}
write_loader_relocations (DeltaDataRelocation d i relocations) pef_file0
	= write_loader_relocations relocations (fwritec (toChar (((d_4 bitand 3)<<6) bitor i)) (fwritec (toChar ((d_4>>2))) pef_file0)); {
		d_4 =  d>>2;
	}
write_loader_relocations (DeltaRelocation i relocations) pef_file0
	= write_loader_relocations relocations (fwritec (toChar deci) (fwritec (toChar (0x80+(deci>>8))) pef_file0)); {
		deci =  dec i;
	}
write_loader_relocations (ImportedSymbolsRelocation i relocations) pef_file0
	= write_loader_relocations relocations (fwritec (toChar deci) (fwritec (toChar (0x4a+(deci>>8))) pef_file0)); {
		deci =  dec i;
	}

	first_zero_char_offset string offset
		| offset >= size string
			= offset;
		| string CHAR offset=='\0'
			= offset;
			= first_zero_char_offset string (offset+1);
	