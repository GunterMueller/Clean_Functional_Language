definition module LinkerOffsets;

from pdSymbolTable import :: Xcoff, :: LibraryList, :: SymbolIndexListKind;

:: *ModuleOffsets :== *{#Int};

compute_module_offsets :: SymbolIndexListKind Int [*Xcoff] Int Int *{#Bool} ModuleOffsets -> (*{#Bool},!Int,!ModuleOffsets,![*Xcoff]);
compute_module_offsets_for_user_defined_sections :: {#Char} Int !*[*Xcoff] Int Int *{#Bool} *{#Int} -> *(.{#Bool},Int,*{#Int},[.Xcoff]);

compute_imported_library_symbol_offsets :: !LibraryList !Int !Int !Int !Int !*{#Bool} !*{#Int} -> (!*{#Bool},!LibraryList,!Int,!Int,!*{#Int}); 