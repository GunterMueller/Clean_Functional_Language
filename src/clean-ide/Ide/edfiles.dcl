definition module edfiles

from StdId			import :: Id
from StdPSt			import :: PSt
from IdeState		import :: General
from EdClient		import :: Selection

ed_ask_save_all		:: !Bool !Bool(*(PSt General) -> *PSt General)		!*(PSt General) -> *PSt General
// cycle through modified edit windows asking user if they should be saved
ed_open_path		:: .String										!*(PSt General) -> *PSt General
// open edit window on file
ed_open_cont		:: .String .(Bool Id *(PSt General) -> *PSt General) !*(PSt General) -> *PSt General
// open edit window on file without file history handling but with explicit continuation
ed_open_path_sel	:: .String !Selection							!*(PSt General) -> *PSt General
// open edit window on file with initial selection
ed_close			:: !Id											!*(PSt General) -> *PSt General
// close specified edit window
ed_new				:: !String										!*(PSt General) -> *PSt General
// create new edit window
ed_common_close		:: !Bool !Id									!*(PSt General) -> *PSt General
// shared edit window close functionality
ed_save				:: !Id											!*(PSt General) -> (!Bool,!*PSt General)
// save specified editor window
ed_save_as			::												!*(PSt General) -> *PSt General
// save active editor window to new file
ed_save_copy_as		::												!*(PSt General) -> *PSt General
// save a copy of the active editor window
ed_save_all			::												!*(PSt General) -> *PSt General
// save all open and modified editor windows
ed_print_setup		::												!*(PSt General) -> *PSt General
// go through print setup dialogue
ed_print			::												!*(PSt General) -> *PSt General
// print active editor window
ed_print_all		::												!*(PSt General) -> *PSt General
// print all open editor windows
ed_revert			::												!*(PSt General) -> *PSt General
// revert active window
ed_revert_win		:: !Id											!*(PSt General) -> *PSt General
// revert specified window
