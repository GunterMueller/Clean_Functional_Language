// this is for the PowerMac
definition module CoclSystemDependent

from StdFile import :: Files
import DirectorySeparator

PathSeparator
	:==	','

script_handler :: !{#Char} *Files -> (!Int,!*Files);

clean2_compile :: !Int -> Int;

clean2_compile_c_entry :: !Int -> Int;

ensureCleanSystemFilesExists :: !String !*Files -> (!Bool, !*Files)

set_compiler_id :: !Int -> Int;
