definition module ConvertMWObject;

import linker2,linker3;

read_mw_object_files :: !String !Int !*NamesTable !String !*File !*Files -> (![String],!Sections,![*Xcoff],!Int,!*NamesTable,!*Files);
