definition module ConvertMWObject;

import SymbolTable;

read_mw_object_files :: !String !Int !*NamesTable !String !*File !*Files -> (![String],!Sections,![*Xcoff],!Int,!*NamesTable,!*Files);
