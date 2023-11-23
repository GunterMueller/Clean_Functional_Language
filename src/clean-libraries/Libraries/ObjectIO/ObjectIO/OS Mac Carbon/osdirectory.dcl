definition module osdirectory

import StdString
import ostoolbox

//	Clean Object I/O library, version 1.2.2

get_or_put_file_selector_result :: !Int !Int !*OSToolbox -> (!Bool,!String,!*OSToolbox)
Get_directory_path :: !Int !Int !String !*OSToolbox -> (!String,!*OSToolbox)

/*
String64 :: String
//Get_parent_id_of_file :: !Int !String !*OSToolbox -> (!Int,!*OSToolbox)
//Get_working_directory_info :: !Int !*OSToolbox -> (!Int,!Int,!*OSToolbox)
Get_directory_and_file_name :: !String !*OSToolbox -> (!Int,!Int,!String,!*OSToolbox)
Set_directory :: !Int !Int !*OSToolbox -> *OSToolbox
SelectorPosition :: !*OSToolbox -> (!(!Int,!Int),!*OSToolbox)
*/