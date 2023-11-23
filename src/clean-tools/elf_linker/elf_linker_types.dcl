definition module elf_linker_types;

::	*SymbolArray :== SSymbolArray;
::	SSymbolArray :== {!Symbol};

::	Symbol
	= Module !Int !Int !Int !Int !Int !Int !String !Int	// section_n offset length virtual_address file_offset n_relocations relocations align
	| Label !Int !Int !Int								// section_n offset module_n
	| SectionLabel !Int !Int							// section_n offset
	| ImportLabel !String								// label_name
	| ImportedLabel !Int !Int 							// file_n symbol_n
	| ImportedLabelPlusOffset !Int !Int !Int			// file_n symbol_noffset
	| UndefinedLabel !Int
	| EmptySymbol;

::	SymbolIndexList = SymbolIndex !Int !SymbolIndexList | EmptySymbolIndex;

::	*Xcoff :== *SXcoff;
:: SXcoff ={
		file_name			:: !String,
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
		symbols			:: !.SSymbolArray
	};

:: XcoffArray :== {#SXcoff};
