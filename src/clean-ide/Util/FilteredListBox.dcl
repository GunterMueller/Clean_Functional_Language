definition module FilteredListBox

import StdControl, StdControlClass, StdId, StdPSt

::	FilteredListBoxId
	=	{	fcontrolId	:: !Id							// The Id of the outmost CompoundControl
		,	freceiverId	:: !R2Id (FilteredMessageIn) FilteredMessageOut	// The Id of the Receiver2Control that handles message passing
		}
:: FilteredMessageIn
:: FilteredMessageOut
:: FilteredListBoxItem :== String

:: FilteredListBoxControl ls ps
	= FilteredListBoxControl [FilteredListBoxItem] [Int] FilteredListBoxId [ControlAttribute *(*(FilteredListBoxState,ls),ps)]

instance Controls FilteredListBoxControl

openFilteredListBoxId			:: !*env -> (!FilteredListBoxId,!*env)	| Ids env

appendFilteredListBoxItems		:: !FilteredListBoxId ![FilteredListBoxItem]			!(PSt .l) -> PSt .l
setFilteredListBoxPen			:: !FilteredListBoxId ![PenAttribute] !(PSt .l) -> PSt .l
exec_next_filtered				:: !Bool !FilteredListBoxId (String (PSt .l) -> (PSt .l)) !(PSt .l) -> (PSt .l)

flbMouse	:: ({#Char} -> .(*(PSt .a) -> *PSt .a)) -> .ControlAttribute *((FilteredListBoxState,.b),*PSt .a);
flbKeyboard	:: ({#Char} -> .(*(PSt .a) -> *PSt .a)) -> .ControlAttribute *((FilteredListBoxState,.b),*PSt .a);

:: FilteredListBoxState

setFilter :: !FilteredListBoxId ([String]->[String]) !(PSt .l) -> PSt .l
getFilter :: !FilteredListBoxId !(PSt .l) -> (![String]->[String],PSt .l)

getFilteredListBoxSelection :: !FilteredListBoxId !(PSt .l) -> (!(!Bool,![(String,!Index)]),!PSt .l)
