definition module EdMessage

// message passing with the editor

from StdId			import class Ids
from StdPSt			import :: PSt
from StdReceiver	import :: Receiver2
from EdMonad		import :: EditState, :: EditMonad, :: StateM

:: EditId
:: Message
:: EditAction l a	:== EditMonad (PSt l) a

openEditId			:: *env								-> (EditId, *env) | Ids env
openEditReceiver	:: !EditId							-> Receiver2 Message Message EditState (PSt .l)

hasEditState		:: !EditId			  			!*(PSt .l) -> *(Bool,		*PSt .l)
appEditState		:: !EditId !.(EditAction .l .r) !*(PSt .l) -> *(.r,*PSt .l)
