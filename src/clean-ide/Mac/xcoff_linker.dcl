definition module xcoff_linker;

from StdFile import :: Files;

import linker2;

mark_used_modules :: !Int !Int !*{#Bool} !{#Int} !*{#*Xcoff} -> (![String],!*{#Bool},!*{#*Xcoff});
link_xcoff_files :: ![String] ![String] !String !(!Int, !{#Char}) !Int !Int !Int !Int !Int !Int !Int !Bool !Bool !*Files -> ((!Bool,![String]),!*Files);

