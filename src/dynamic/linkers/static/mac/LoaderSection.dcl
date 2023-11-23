definition module LoaderSection;

import 
	State;
	
compute_pef_loader_relocations2 :: !Int !*State -> (!Int,*LoaderRelocations,!*State);
//write_pef_loader :: !LibraryList !Int !Int !Int !Int !Int !Int !.LoaderRelocations !*File -> *File;	
write_pef_loader :: !Int !Int !Int !Int !Int !.LoaderRelocations !*State !*File -> (!*State,*File);	
