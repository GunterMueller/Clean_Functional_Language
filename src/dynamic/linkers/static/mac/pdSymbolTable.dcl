definition module pdSymbolTable;

import
	StdEnv;

instance toString Symbol;

CreateImportedLabel :: !Int !Int -> !Symbol;
	
read_library_file :: String Int *Files *NamesTable -> (!Bool,!String,!LibrarySymbolsList,!Int,!*Files,!*NamesTable);
split_data_symbol_lists_without_removing_unmarked_symbols :: *Xcoff -> !*Xcoff;

import NamesTable;

// accessors
get_text_relocations	:== (\xcoff=:{text_relocations} -> (text_relocations,xcoff));
get_data_relocations	:== (\xcoff=:{data_relocations} -> (data_relocations,xcoff));
get_header				:== (\xcoff=:{header}			-> (header,xcoff));	
get_n_symbols			:== (\xcoff=:{n_symbols}		-> (n_symbols,xcoff));
get_text_v_address		:== (\xcoff=:{header={text_v_address}} -> (text_v_address,xcoff));
get_data_v_address		:== (\xcoff=:{header={data_v_address}} -> (data_v_address,xcoff));
get_toc0_symbols		:== (\symbol_table=:{toc0_symbol} -> (toc0_symbol,symbol_table));
get_toc_symbols			:== (\symbol_table=:{toc_symbols} -> (toc_symbols,symbol_table));	

symbol_get_offset :: !Symbol -> !Int;
// Label
isLabel :: !Symbol -> !Bool;

getLabel_offset :: !Symbol -> !Int;
getLabel_module_n :: !Symbol -> !Int;

// Module
isModule :: !Symbol -> !Bool;

getModule_virtual_label_offset :: !Symbol -> !Int;


fill_library_offsets :: LibraryList Int Int *{#Int} -> *{#Int};
	
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
/*
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

//n_symbols_of_xcoff_list :: !Int ![Xcoff] -> Int;
empty_xcoff ::.Xcoff;
:: UndefinedSymbol :== ({#Char},Int,Int);
import_symbols_in_xcoff_files :: !*[*Xcoff] !Int [({#Char},Int,Int)] !*{!NamesTableElement} -> (![({#Char},Int,Int)],![.Xcoff],!.{!NamesTableElement});
//mark_used_modules :: !Int !Int !*{#Bool} !{#Int} !*{#*Xcoff} -> (![String],!*{#Bool},!*{#*Xcoff});
mark_used_modules :: !Int !Int ![String] !{#Bool} !*{#Bool} !*{#Int} !*{#*Xcoff} -> (![String],!*{#Int}, !*{#Bool},!*{#*Xcoff});


//create_names_table :: *NamesTable;
//find_symbol_in_symbol_table :: !String !*NamesTable -> (!NamesTableElement,!*NamesTable);
//insert_symbol_in_symbol_table :: !String Int Int !*NamesTable -> *NamesTable;
//sort_modules :: !*Xcoff -> .Xcoff;
//reverse_symbols :: !SymbolIndexList -> SymbolIndexList;


xcoff_list_to_symbols_array :: !.Int ![.Xcoff] -> {!{!Symbol}};
xcoff_array_to_list :: Int *{#*Xcoff} -> [*Xcoff];
// old: split_data_symbol_lists_of_files2 :: {#Int} {#Bool} Sections [*Xcoff] *TocTable -> (!Sections,![*Xcoff],!*TocTable);
split_data_symbol_lists_of_files2 :: *{#Int} *{#Bool} Sections [*Xcoff] *TocTable -> (!Sections,![*Xcoff],!*TocTable,*{#Int},*{#Bool});

::	SymbolAndFileN = { symbol_n::!Int, file_n::!Int };
//find_root_symbols :: *NamesTable -> (!Bool,!SymbolAndFileN,!*NamesTable);
//mark_modules :: !SymbolAndFileN !*[*Xcoff] !Int !Int !Int !LibraryList -> (![String],!Int,!{#Bool},!{#Int},!*{#*Xcoff});
//create_xcoff_mark_and_offset_arrays :: Int Int Int Int LibraryList [*Xcoff] -> (!*{#Bool},!*{#Int},!*{#*Xcoff});
read_library_files :: ![String] Int Int !*Files *NamesTable -> (![String],!LibraryList,!Int,!*Files,!*NamesTable);

//insert_exported_symbol_in_toc_table :: Int Int Int Int Int Int *{!Symbol} {#Int} !*TocTable -> (!*{!Symbol},!*TocTable);
//insert_exported_symbol_in_toc_table :: Int Int Int Int Int Int *{!Symbol} *{#Int} !*TocTable -> (!*{!Symbol},!*TocTable, *{#Int});

//NEW
xcoff_list_to_array :: !Int ![*Xcoff] -> !{#*Xcoff};
