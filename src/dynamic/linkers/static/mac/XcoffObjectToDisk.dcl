definition module XcoffObjectToDisk;

import SymbolTable;

write_xcoff_file :: .{#Char} .Int !.Int !.Int !.LibraryList .Int .Int .Bool !*Sections !.Int {#.Bool} {#.Int} !*{#*Xcoff} *Files -> *(!Bool,Int,*Files);

