definition module lib

from StdFile import :: Files


CreateArchive :: !String ![String] !*Files -> (![String], !Files)
/*
	Creates an archive named after the first argument. The archive 
	consists of the object modules in the second argument. The
	returned list contains possible error messages
*/

OpenArchive :: !String !*Files -> (![String],![String],!Files);
/*
	The 1st component is a list of error messages. The second a 
	list of object modules contained in the library.
*/


getExternalNames :: .{#Char} *Files -> *(.([{#Char}],[{#Char}],[{#Char}]),*Files);
