definition module pdDynamicLinker;

import
	StdEnv;
	
import State;
	
ParseCommandLine :: !String -> {#{#Char}};
RemoveStaticClientLibrary :: !*State -> !*State;