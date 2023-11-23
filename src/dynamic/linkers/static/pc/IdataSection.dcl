definition module IdataSection;

from SymbolTable import :: LibraryList;

write_imported_library_functions_code_32 :: !LibraryList !Int !*File -> *File;
write_imported_library_functions_code_64 :: !LibraryList !Int !Int !*File -> *File;
write_idata :: !.LibraryList !.Int !.Int !.Int !*File -> .File;
compute_idata_strings_size :: !LibraryList !Int !Int !Int !*{#Bool} -> (!*{#Bool},!Int,!Int);
