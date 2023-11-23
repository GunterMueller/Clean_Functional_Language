definition module HttpSubServer

import Http, SubServerUtil

// (c) 2006 Erwin Lips and Jacco van Drunen
// HIO - Breda
// Radboud University Nijmegen

// This is an Http 1.1 SubServer written in Clean
// The SubServer can be linked with a Clean function generating Html code
// It creates a subserver application which can be attached to a Http 1.1 compliant main server.
// This can e.g. be an Apache server, a Microsoft IIS server, or the Clean Http 1.1 server.
// Several SubServers can be attached, and Strings and Files can be communicated


:: HTTPSubServerOption	= HTTPSubServerOptPort Int				// The port on which the server listens (default is 80)
						| HTTPSubServerOptStaticFallback Bool	// If all request handlers fail, should the static file handler be tried (default False)
						| HTTPSubServerOptParseArguments Bool	// Should the query and body of the request be parsed (default True)
						| HTTPSubServerOptMaxServers Int		// The maximum number of subserver processes to be started (default is 100)


//Wrapper function similar to http_startServer and http_startCGI
http_startSubServer :: [HTTPSubServerOption] [((String -> Bool),(HTTPRequest *World-> (HTTPResponse,*World)))] *World -> *World

//The following types and functions can be used to implement a more advanced streaming subserver.
//For simple applications, it is advisable to just use the http_startSubServer wrapper

:: Socket :== Int;

//required functions
RegisterSubProcToServer :: !Int !Int !Int !String !String -> Int		// priority minimum maximum number of subservers
WaitForMessageLoop :: ([String] Int Socket *World -> (Socket,*World)) Socket !*World -> *World

//helper-functions for sending (suggested to use one of these)
SendString :: !String !String ![String] !Socket !*World -> (Socket,*World)
SendFile :: String ![String] !Socket !*World -> (Socket,*World)

//helper-functions for receiving (optional to use one of these)
ReceiveString :: !Int !Int !Socket !*World -> (Int,String,Socket,*World)
ReceiveFile :: !Int !Socket !*File !*World -> (Bool,*File,*World)

//extra functions (do not use these unless you know what you are doing, read the RFC first)
SendDataToClient :: !Socket !{#Char} !*env -> (!Socket,*env);
HTTPdisconnectGracefulC :: !Socket !*env -> *env;
DetectHttpVersionAndClose :: !String !String !Socket !*World -> (Socket,*World)