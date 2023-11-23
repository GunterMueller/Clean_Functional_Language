definition module main;

import
	StdEnv, State; //, PmDynamic;
	
InitialLink :: [!String] !ServerState !*State !*Files -> (!Bool,!Int,!ServerState,!State, !*Files);
