definition module CommonObjectToDisk;

import SymbolTable, State;

//write_imported_library_functions_code :: !LibraryList !Int *a !Int !*State -> *(*a,!*State) | Target2 a;
write_imported_library_functions_code :: !Int *a !Int !*State -> *(*a,!*State) | Target2 a;


count_and_reverse_relocations :: !*LoaderRelocations -> (!Int,!*LoaderRelocations);


// Extra

:: WriteKind = WriteText | WriteData | WriteTOC | WriteDataAndToc;

:: *WriteOutputRecord = {
	file_or_memory	:: !Int,
	offset			:: !Int,
	string			:: !{#Char},
	
	// was ChangeStateRecord
	file_n			:: !Int,
	module_n		:: !Int,
	state			:: !*State
	};
	
class Target2 a
where
{
	WriteOutput :: !WriteOutputRecord !*a -> (!*a,!*State);
	

	WriteLong	:: !Int !*a -> !*a;
	
	DoRelocations :: !*a -> (!Bool,!*a);
	
	BeforeWritingXcoffFile :: !Int !*a !*State -> (!*a,!*State);
	
	AfterWritingXcoffFile :: !Int !*a !*State -> (!*a,!*State)
	
	/*
						# (pef_file,state)
						= NextXcoffFile file_n pef_file state;
	*/
};
instance Target2 File;

// -----------------------
write_to_pef_files2 :: !Int !WriteKind {*String} Int Int !*State Sections !*a !*Files -> ((!Int,!{*{#Char}},!*a,!*State), !*Files) | Target2 a ;

//write_to_pef_files2 :: !Int !WriteKind {*String} Int Int !*State Sections !*a !*Files -> (!Int,!{*{#Char}},!*a, !*Files,!*State) | Target2 a ;