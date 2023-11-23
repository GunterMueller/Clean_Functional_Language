implementation module pdExtFile;

import StdEnv;
import code from "filesize.";
//import code from "fileutilities.obj";
//import code from library "fileutilities_library";
import Directory;

path_separator :== '\\';

FileSize :: !String -> (!Bool,!Int);
FileSize _ =
	code {
		ccall FileSize "S-II"
	};

(FWW) infixl;
(FWW) f w :== fwritec (toChar (w>>8)) (fwritec (toChar w) f);

(FWB) infixl;
(FWB) f b :== fwritec (toChar b) f;

/*
FetchFileTime :: !String -> (!Bool,!Int,!Int);
FetchFileTime _ 
	= code {
		ccall FetchFileTime "S-III"
	};
	
CompareFileTimes :: !Int !Int !Int !Int -> Int;
CompareFileTimes _ _ _ _
	= code {
		ccall CompareFileTimes "IIII-I"
	};
*/
	
GetShortPathName :: !String -> (!Bool,!String);
GetShortPathName long_path
	#! s_short_path
		= GetShortPathName_ long_path "\0" 0;
	#! short_path
		= createArray s_short_path '\0';
	#! result
		= GetShortPathName_ long_path short_path s_short_path;
	= (not (result == 0),short_path);
where {
	GetShortPathName_ :: !String !String !Int -> Int;
	GetShortPathName_ long_path short_path s_short_path
		= code {
			ccall GetShortPathNameA@12 "PssI:I"
		}
}

/*
file_exists :: !String !*f -> (!Bool,!*f) | FileEnv f;
file_exists file_name io
	#! ((ok,file),io)
		= accFiles (pd_StringToPath file_name) io;
	# ((file_error,_),io)
		= accFiles (getFileInfo file) io;
	= (file_error <> DoesntExist,io);

FileExists :: !String !*env -> (!Bool,!*env) | FileSystem env;
FileExists pd_path env
	#! ((ok,path), env)
		= pd_StringToPath pd_path env; 
	| not ok
		= abort "pdExtFile (FileExists): could not convert path to platform independent representation";
		
	#! ((dir_error, _), env)
		= getFileInfo path env;
	= (not (dir_error == DoesntExist),env);
*/

GetFullPathName :: !String -> (!Bool,!String);
GetFullPathName lpFileName
	#! buffer_s = (GetFullPathName_ lpFileName 0 "\0" 0);
	#! buffer = createArray buffer_s '*';
	#! result = GetFullPathName_ lpFileName buffer_s buffer 0;
	= (result <> 0,buffer % (0,result - 4));
where {
	GetFullPathName_ :: !String !Int !String !Int -> Int;
	GetFullPathName_ lpFileName nBufferLength buffer _
		= code {
			ccall GetFullPathNameA@16 "PsIsI:I"
		}
}
