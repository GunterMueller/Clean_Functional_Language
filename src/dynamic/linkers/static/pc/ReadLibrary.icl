implementation module ReadLibrary

import 
	StdArray, StdEnum, StdBool, StdList

from StdString import String
from StdMisc import abort
from StdFile import Files
from StdClass import <=;

import
	lib;
	
import ExtString;
import DebugUtilities;

// Symbol
:: StaticLibrarySym :== !(!String,!Int)
:: StaticLibrarySymbols :== !{StaticLibrarySym}

// Object modules
:: StaticLibraryModule :== !(!String,!Int)
:: StaticLibraryModules :== ![StaticLibraryModule]

// Library
:: StaticLibrary = {
	static_library_name :: !String,
	static_symbols :: !StaticLibrarySymbols,
	static_modules :: !StaticLibraryModules 
	}
	
// Libraries
:: StaticLibraries :== ![!StaticLibrary]

EmptyStaticLibrarySymbol :: StaticLibrarySym
EmptyStaticLibrarySymbol
	= ("",0)

ReadStaticLibraries :: [!String] StaticLibraries !*Files -> (!LinkerMessagesState,StaticLibraries,!*Files);
ReadStaticLibraries [] static_libraries files
	= (DefaultLinkerMessages,static_libraries, files)
		
ReadStaticLibraries [n:ns] static_libraries files
	#! (linker_messages_state,is_new_library_name, new_library_name, cancelled, lib_file, files)
		= OpenLibraryFile n files
	#! (ok,linker_messages_state)
		= isLinkerErrorOccured linker_messages_state;
	| not ok
		= (linker_messages_state,[],files);

	| is_new_library_name || cancelled
		= abort "ReadStaticLibraries: cancel or new library selection does not work"
				
	#! (n_xcoff_files, xcoff_file_offsets, n_xcoff_symbols, indices, string_table, lib_file)
		= ReadSecondLinkerMember lib_file;
			
	#! static_library_symbols
		= init_static_library_symbols 0 n_xcoff_symbols 0 (createArray n_xcoff_symbols EmptyStaticLibrarySymbol) string_table indices xcoff_file_offsets n_xcoff_files
			
	#! (static_library_modules,lib_file)
		= init_static_library_modules n_xcoff_files xcoff_file_offsets lib_file; 
			
	#! static_library
		= { StaticLibrary |
			static_library_name = n,
			static_symbols = static_library_symbols,
			static_modules = static_library_modules
		}	
	#! files
		= CloseLibraryFile lib_file files
			
	= ReadStaticLibraries ns (static_libraries ++ [static_library]) files
where 
	init_static_library_symbols i n_xcoff_symbols index static_library_symbols string_table indices xcoff_file_offsets n_xcoff_files
		| i == n_xcoff_symbols
			= static_library_symbols;
				
			#! (ok,new_index)
		 		= CharIndex string_table index '\0'
			| not ok
				= abort "init_static_library_symbols: internal error";		
			#! name 
				= string_table % (index,  new_index -1);
		
			#! index_in_offsets
				= indices.[i] - 1;
	
			#! xcoff_file_offset
				= xcoff_file_offsets.[index_in_offsets];
			= init_static_library_symbols (inc i) n_xcoff_symbols (inc new_index) {static_library_symbols & [i] = (name, xcoff_file_offset)} string_table indices xcoff_file_offsets n_xcoff_files
				
	init_static_library_modules n_xcoff_files xcoff_file_offsets lib_file
		#! (object_names,lib_file,_,_,_)
			= ReadOtherLinkerMembers "" False lib_file create_names_table 0 [] "" [];
		#! static_library_modules_a
			= { o \\ o <- object_names };
		#! static_library_modules
			= [ (static_library_modules_a.[i], xcoff_file_offsets.[i]) \\ i <- [0..(n_xcoff_files-1)] ];	
		= (static_library_modules,lib_file);