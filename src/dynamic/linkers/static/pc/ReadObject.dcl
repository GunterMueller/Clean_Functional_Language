definition module ReadObject;

from StdFile import :: Files;
from StdMaybe import :: Maybe;
from pdSymbolTable import :: Sections, :: LibrarySymbolsList;
from NamesTable import :: NamesTable, :: SNamesTable, :: NamesTableElement;
from Redirections import ::RedirectionState;
from pdSymbolTable import :: LibraryList, :: Xcoff;

ReadXcoffM :: !Bool !String !Int !NamesTable !Bool !Int !*RedirectionState !*Files  -> ((!Bool,![String],![*Xcoff],!NamesTable,!*RedirectionState),!Files);  

read_xcoff_files :: !Bool ![String] !NamesTable !Bool !Files !Int !*RedirectionState -> (!Bool,![String],!Sections,!Int,![*Xcoff],!NamesTable,!Files,!*RedirectionState);

read_xcoff_file :: !String !Int !NamesTable !Bool !*File !Int !*RedirectionState -> (!Bool,![String],!*String,!*String,!*Xcoff,!NamesTable,!*File,!*RedirectionState);

read_xcoff_fileI :: !String !String !Int !NamesTable !Bool !*File !Int !*RedirectionState -> (!Bool,![String],!*String,!*String,!*Xcoff,!NamesTable,!*File,!*RedirectionState);

/*
	This function extracts all external symbols from an object file.
	
	Result (n th component):
	1	= list of errors
	2	= # external symbols
	3 	= list of names for each external defined symbol
	4 	= list of names for each external referenced symbol (inter object reference)
	5	= files 	
*/	
read_external_symbol_names_from_xcoff_file :: !String !*Files ->  ([String], !Int, !Int, [String],[String],!*Files);
read_coff_header :: !*File -> (!Bool,!Int,!Int,!Int,!*File);

class ExtFileSystem f
where {
	rlf_fopen :: !{#Char} !Int !*f -> (!Bool,!*File,!*f);
	rlf_fclose :: !*File !*f -> (!Bool,!*f);
	rlf_freadline :: !*File !*f -> (!*{#Char},!*File,!*f)
};

instance ExtFileSystem Files;
read_library_files list library_n n_library_symbols0 files0 names_table0 :== read_library_files_new True list library_n n_library_symbols0 files0 names_table0;

read_library_files_new :: !Bool ![String] !Int !Int !*a !*NamesTable -> *(![String],!LibraryList,!Int,!*a,!*NamesTable) | ExtFileSystem a;

read_library_file library_file_name library_n files names_table :== read_library_file_new True library_file_name library_n files names_table;

read_library_file_new :: !Bool !String !Int !*a !*NamesTable -> *(!Bool,!String,!LibrarySymbolsList,!Int,!*a,!*NamesTable) | ExtFileSystem a;

read_library_files2 :: [[String]] !Int !Int !*{!NamesTableElement} -> *(!LibraryList,!Int,!*{!NamesTableElement});

class ImportDynamicLibrarySymbols a :: a !Int !Int !*NamesTable -> (!Int,!Int,!*NamesTable);

instance ImportDynamicLibrarySymbols LibraryList;

decode_line_from_library_file :: String -> Maybe String;
