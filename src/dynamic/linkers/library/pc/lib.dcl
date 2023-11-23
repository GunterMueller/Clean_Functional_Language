definition module lib

from StdFile import :: Files;
from LinkerMessages import :: LinkerMessagesState;
from pdSymbolTable import :: Xcoff;
from NamesTable import :: NamesTable, :: SNamesTable, :: NamesTableElement;
from Redirections import :: RedirectionState;

// FIXME: remove make_even macro
from StdOverloaded import class +(+), class isEven (isEven)
from StdInt import instance + Int, instance isEven Int
make_even i :== if (isEven i) i (i+1);	
read_archive_member_header :: !*File !String -> (!Bool,!String,!Int,!*File);

CreateArchive :: !String [String] !*Files -> ([String], !Files)
/*
	Creates an archive named after the first argument. The archive 
	consists of the object modules in the second argument. The
	returned list contains possible error messages
*/

OpenArchive :: !String !*Files -> (![String],![String],!Files);
/*
	The 1st component is a list of error messages. The second a 
	list of object modules contained in the library.
*/

// Access functions for static libraries

OpenLibraryFile :: !String !*Files -> (LinkerMessagesState,!Bool,!String,!Bool,!*File,!*Files);

StaticOpenLibraryFile :: !String !*Files -> ([String],!*File,!*Files);

ReadSecondLinkerMember :: !*File -> (!Int,!{#Int},!Int,!{#Int},!String,!*File);

ReadOtherLinkerMembers :: !String !Bool !*File !NamesTable !Int [*Xcoff] !String [String] !*ReadStaticLibState !RedirectionState ->  ([String],!*File,!NamesTable,!Int,[*Xcoff],!*ReadStaticLibState,!RedirectionState);

CloseLibraryFile :: !*File !*Files -> *Files;

:: *ReadStaticLibState
	= {
		import_libraries	::	[ImportLibrary]
	};
	
:: ImportLibrary 
	= { 
		il_name		:: !String
	,	il_symbols	:: [String]
	};
default_rsl_state :: *ReadStaticLibState

read_static_lib_files :: [String] [String] !NamesTable !Int [*Xcoff] !*Files !*ReadStaticLibState !RedirectionState -> ([String],[*Xcoff],[String],!NamesTable,!Int,!*Files,!*ReadStaticLibState,!RedirectionState);
