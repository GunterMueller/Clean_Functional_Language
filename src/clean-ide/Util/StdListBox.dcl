definition module StdListBox

import StdControl, StdControlClass, StdId, StdPSt

:: ListBoxControl ls ps
	= ListBoxControl [String] [Int] ListBoxId [ControlAttribute *(ls,ps)]

instance Controls ListBoxControl

::	ListBoxId

openListBoxId			:: !*env -> (!ListBoxId,!*env)	| Ids env

getListBoxSelection 	:: !ListBoxId					!(PSt .l) -> (!(!Bool,![(String,!Index)]),!PSt .l)
setListBoxSelection 	:: !ListBoxId ![Index]			!(PSt .l) -> PSt .l
getListBoxItems			:: !ListBoxId					!(PSt .l) -> (!(!Bool,![String]),!PSt .l)
openListBoxItems		:: !ListBoxId !Index ![String]	!(PSt .l) -> PSt .l
appendListBoxItems		:: !ListBoxId ![String]			!(PSt .l) -> PSt .l
closeListBoxItems		:: !ListBoxId ![Index]			!(PSt .l) -> PSt .l
closeAllListBoxItems	:: !ListBoxId					!(PSt .l) -> PSt .l

upListBoxSelItem :: !ListBoxId !*([a],!*PSt .l) -> *(Bool,*([a],*PSt .l))
dnListBoxSelItem :: !ListBoxId !*([a],!*PSt .l) -> *(Bool,*([a],*PSt .l))

showListBoxControl		:: !ListBoxId !*(IOSt .l) -> *IOSt .l
hideListBoxControl		:: !ListBoxId !*(IOSt .l) -> *IOSt .l
enableListBoxControl	:: !ListBoxId !*(IOSt .l) -> *IOSt .l
disableListBoxControl	:: !ListBoxId !*(IOSt .l) -> *IOSt .l
