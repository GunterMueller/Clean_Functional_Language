implementation module pdExtFile;

import StdEnv;
//from StdFile import fwritec, FileEnv, files;
from StdInt import toChar, >>;
from StdMisc import abort;
from StdBool import not;
import Directory;

(FWB) infixl
(FWB) f i :== fwritec (toChar i) f;


(FWW) infixl
(FWW) f i :== fwritec (toChar i) (fwritec (toChar (i>>8)) f);

path_separator :== ':';

FileExists :: !String !*env -> (!Bool,!*env) | FileSystem env;
FileExists pd_path env
	#! ((ok,path), env)
		= pd_StringToPath pd_path env; 
	| not ok
		= abort "pdExtFile (FileExists): could not convert path to platform independent representation";
		
	#! ((dir_error, _), env)
		= getFileInfo path env;
	= (not (dir_error == DoesntExist),env);