definition module pdSymbolTable;

from StdOverloaded import class ==, class toString, class toInt;
from NamesTable import :: NamesTable, :: SNamesTable, :: NamesTableElement;

CreateImportedLabel :: !Int !Int -> Symbol;

// Label
isLabel :: !Symbol -> Bool;
getLabel_offset :: !Symbol -> Int;
getLabel_module_n :: !Symbol -> Int;

// Module
isModule :: !Symbol -> Bool;
getModule_virtual_label_offset :: !Symbol -> Int;

symbol_get_offset :: !Symbol -> Int;

fill_library_offsets :: LibraryList Int Int *{#Int} -> *{#Int};

:: *Sections = Sections !*String !*String !Sections | EndSections;

:: SymbolIndexListKind = Text | Data | Bss;

:: UndefinedSymbol :== ({#Char},Int,Int);
	
// --------------------------------------------------------------------------------
// Exported types

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
	
instance == SectionKind;
	
instance toInt SectionKind;

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

// Change library_base address
::	LibraryList = Library !String !Int !LibrarySymbolsList !Int !LibraryList | EmptyLibraryList;

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
	
import_symbols_in_xcoff_files :: !*[*Xcoff] !Int [({#Char},Int,Int)] !*NamesTable -> (![({#Char},Int,Int)],![*Xcoff],!*NamesTable);

xcoff_list_to_array :: !.Int ![.Xcoff] -> {#Xcoff};
xcoff_array_to_list :: !Int !*{#*Xcoff} -> [*Xcoff];

:: OffsetArray :== {#Int};

empty_xcoff :: .Xcoff;

xcoff_list_to_xcoff_array :: ![*Xcoff] !Int -> *{#*Xcoff};

mark_used_modules :: !Int !Int ![String] !{#Bool} !*{#Bool} !*{#Int} !*{#*Xcoff} -> (![String],!*{#Int}, !*{#Bool},!*{#*Xcoff});

instance toString Symbol;

// assumuption: a normal static link is performed		
remove_garbage_from_symbol_table :: !Int !Int Int *{#Bool} {#*Xcoff} -> (*{#Bool},{#*Xcoff});