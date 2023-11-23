definition module DynamicLinkerOffsets;

from LibraryInstance import :: Libraries;
from pdSymbolTable import :: LibraryList;

Dcompute_imported_library_symbol_offsets_for_libraries :: !Libraries !Int Int *{#Bool} !*{#Int} !*{#Int} -> (!Libraries,!Int,!*{#Bool},!*{#Int},!*{#Int});

Dcompute_imported_library_symbol_offsets :: !LibraryList !Int Int *{#Bool} !*{#Int} -> (!*{#Bool},!LibraryList,!Int,!*{#Int}); 
