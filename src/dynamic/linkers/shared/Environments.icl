implementation module Environments;

import StdClass, StdArray;
from StdString import String, +++, ==;
from StdMisc import abort;
from StdList import filter, hd;
from StdTuple import fst, snd;
from StdBool import &&;

from ExtString import CharIndex;

:: Environment :== [(!String,!String)];	

ReplaceEnvironmentVar :: !String !Environment -> !String;
ReplaceEnvironmentVar var_path env
	#! (var_exists,i)
		= find_env_var;
	| var_exists
		#! dir 
			= GetAttribute (var_path % (0,i)) env;
		#! path 
			= (var_path % (i+1,size var_path));
		#! dir_path
			= dir +++ path;
		| size path > 0 && (dir == "")     // (dir_path % (0,1)) == ".\\"
			= dir_path % (1,size dir_path - 1);
			= dir_path;
		= var_path;
where
{
	find_env_var :: (!Bool,!Int);
	find_env_var
		#! (found,i)
			= CharIndex var_path 0 '}';
		| found
			= (var_path.[0] == '{',i);
			= (False,0);
}

GetAttribute :: !String [(!String,!String)] -> !String;
GetAttribute name env
	| (length name_list) == 1
		= snd (hd name_list);
		= abort ("GetAttribute: environment variabele " +++ name +++ " not found");
where
{
	name_list = filter eq env;
	eq (s1,_) = s1 == name;
}


