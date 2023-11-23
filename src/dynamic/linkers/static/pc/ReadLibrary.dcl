definition module ReadLibrary

from StdString import String
from StdFile import Files

import LinkerMessages;

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

ReadStaticLibraries :: [!String] StaticLibraries !*Files -> (!LinkerMessagesState,StaticLibraries,!*Files);
