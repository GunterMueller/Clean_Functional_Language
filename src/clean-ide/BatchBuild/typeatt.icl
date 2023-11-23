implementation module typeatt

import StdEnv,IdeState

update_type_window :: !Bool !String ![String] !*GeneralSt -> *GeneralSt
update_type_window _ module_name types ps
	= foldl (flip writeLog) (writeLog ("\""+++module_name+++"\"") ps) types
