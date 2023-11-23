implementation module store

import StdMisc
import StdId, StdPSt, StdReceiver

::	StoreSt a
	=	{	store	:: !Maybe a
		}
::	MsgIn a
	=	InGet				// request to obtain current (if present) value
	|	InSet a				// request to update current value
::	MsgOut a
	=	OutGet (Maybe a)	// response to request for current value
	|	OutSet				// response to update current value (always successfull)

::	Store a ls pst
	=	Store (StoreId a) (Maybe a)
::	StoreId a
	:== R2Id (MsgIn a) (MsgOut a)

openStoreId :: !*env -> (!StoreId a,!*env) | Ids env
openStoreId env
	= openR2Id env

storeIdToId :: !(StoreId a) -> Id
storeIdToId r2id
	= r2IdtoId r2id

openStore :: !(StoreId a) !(Maybe a) !(PSt .ps) -> (!Bool,!PSt .ps)
openStore r2id content pSt
	= case openReceiver {store=content} (Receiver2 r2id storeFun []) pSt of
		(NoError,pSt)	= (True, pSt)
		(error,  pSt)	= (False,pSt)

instance Receivers (Store a) where
	openReceiver ls (Store r2id maybeValue) pSt
		= openReceiver {store=maybeValue} (Receiver2 r2id storeFun []) pSt
	getReceiverType _
		= "Store"

storeFun :: (MsgIn a) (StoreSt a,PSt .ps) -> (MsgOut a, (StoreSt a,PSt .ps))
storeFun InGet (st=:{store},pSt)
	= (OutGet store,(st,pSt))
storeFun (InSet v) (st,pSt)
	= (OutSet,({st & store=Just v},pSt))

valueStored :: !(StoreId a) !(PSt .ps) -> (!Bool,!PSt .ps)
valueStored r2id pSt
	= case syncSend2 r2id InGet pSt of
		((SendOk,Just (OutGet mv)),pSt) = (isJust mv,pSt)
		(unexpectedAnswer,         pSt) = (False,    pSt)
	
readStore :: !(StoreId a) !(PSt .ps) -> (a,!PSt .ps)
readStore r2id pSt
	= case syncSend2 r2id InGet pSt of
		((SendOk,Just (OutGet (Just v))),pSt) = (v,pSt)
		((SendOk,Just (OutGet nothing)), pSt) = abort "readStore: failed because no value returned.\n(Use valueStored to check presence of value.)\n"
		(unexpectedAnswer,               pSt) = abort "readStore: failed to read store.\n(Probably not open.)\n"

writeStore :: !(StoreId a) a !(PSt .ps) -> PSt .ps
writeStore r2id v pSt
	= case syncSend2 r2id (InSet v) pSt of
		((SendOk,Just OutSet),pSt) = pSt
		(unexpectedAnswer,    pSt) = abort "writeStore: failed to write value to store.\n(Probably not open.)\n"

closeStore :: !(StoreId a) !(PSt .ps) -> PSt .ps
closeStore r2id pSt
	= appPIO (closeReceiver (r2IdtoId r2id)) pSt
