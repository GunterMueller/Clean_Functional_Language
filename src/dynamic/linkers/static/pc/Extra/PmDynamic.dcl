definition module PmDynamic;

from StdEnv import String;
from StdFile import Files;

from PmProject import Project;



from StdPathname import Pathname;
//from target import Target;
from ReadLibrary import StaticLibraryModules,StaticLibrarySymbols,StaticLibraryModule,StaticLibrarySym,StaticLibraries, StaticLibrary;

// DynamicLinkerNode
:: DynamicLinkerNode = 
	{ project						:: !Project
	, updated						:: !Bool
	, project_name					:: !String
	, static_libraries				:: !StaticLibraries
	};
	
EmptyDynamicLinkerNode :: !DynamicLinkerNode;


// -----------------------------------------------------------------------------------------
// ServerState	
:: ServerState = 
	{ application_path				:: !String
	,  static_application_as_client :: !Bool
	};
	
EmptyServerState :: !ServerState;
// -----------------------------------------------------------------------------------------