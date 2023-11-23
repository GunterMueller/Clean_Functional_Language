definition module first_run

from StdPSt import :: PSt

first_run :: !String !String !String !String ![(String,String)] !(PSt .ls) -> (!Bool,(String,String),!PSt .ls)
change_hcl_registry_fun :: !String !String !String !String -> [String]
change_pcl_registry_fun :: !String !String !String !String -> [String]
get_ide_from_registry :: (!String,!String,![String])
GetFileName :: !String -> String;
GetFilePath :: !String -> String;
uninstall :: !(PSt .ls)	-> (![String],!PSt .ls)
