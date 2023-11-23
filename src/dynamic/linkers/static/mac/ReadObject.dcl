definition module ReadObject;

from StdString import String;
import SymbolTable;

read_xcoff_files :: ![String] *NamesTable Bool !*Files !Int -> (![String],!Sections,!Int,![*Xcoff],!*NamesTable,!*Files);
read_lib_files :: ![String] ![String] !NamesTable !Int ![*Xcoff] !*Files -> (![!String],![*Xcoff],![String],!NamesTable,!Int,!*Files);


//ReadXcoff :: !String !Int !NamesTable !Bool !*Files !Int -> (![String],!*String,!*String,!*Xcoff,!NamesTable,!Files);  

// one pass, dynamic linking not supported
ReadXcoffM :: !String !Int !NamesTable !Bool !Int !*Files -> ((![String],![*Xcoff],!NamesTable),!Files);  
