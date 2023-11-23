implementation module PmDynamic;

from StdBool import not;
from StdString import String, +++;
from StdMisc import abort;

from PmProject import Project, PR_InitProject;
//from target import Target;
from StdPathname import Pathname;
from ReadLibrary import StaticLibraryModules,StaticLibrarySymbols,StaticLibraryModule,StaticLibrarySym,StaticLibraries, StaticLibrary;
	
// DynamicLinkerNode
:: DynamicLinkerNode = 
	{ project				:: !Project
	, updated				:: !Bool
	, project_name			:: !String
	, static_libraries		:: !StaticLibraries
	};
	
EmptyDynamicLinkerNode :: !DynamicLinkerNode;
EmptyDynamicLinkerNode =
	{ DynamicLinkerNode |
	  project						= PR_InitProject
	, updated						= False
	, project_name					= ""
	, static_libraries				= []
	};
	

// ServerState		
:: ServerState = 
	{ application_path				:: !String
	, static_application_as_client	:: !Bool
	};
	
EmptyServerState :: !ServerState;
EmptyServerState = 
	{ application_path				= ""				
	, static_application_as_client 	= False
	};
