definition module WriteOptionsFile

import
	StdFile;
/*	
:: ConstructorType = NoConsole | BasicValuesOnly | ShowConstructors

:: ApplicationOptions = {
	sgc 					:: !Bool,
	pss 					:: !Bool,
	set 					:: !Bool,
	write_stderr_to_file	:: !Bool,
	marking_collection		:: !Bool,
	memoryProfiling		 	:: !Bool,
	o						:: !ConstructorType
	}

ApplicationOptionsToFlags :: !ApplicationOptions -> Int
*/
write_options_file :: !{#.Char} !.Int !.Int !.Int !.Int !.Int !.Int !*a -> !*(!Bool,!*a) | FileSystem a