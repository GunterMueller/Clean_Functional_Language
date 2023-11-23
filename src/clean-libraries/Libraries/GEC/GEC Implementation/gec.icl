implementation module gec

import StdMisc, StdTuple
import StdObjectIOExt, StdPSt, StdReceiver, StdControlReceiver
import guiloc, objectloc, StdBimap
import GenEq, GenPrint, StdGeneric

derive bimap  GECMsgIn, GECMsgOut, GECVALUE
derive gEq    PropagationDirection, UpdateReason, IncludeUpdate, KeepActiveCONS, Arrangement
derive gPrint ConsPos, Arrangement, IncludeUpdate

::	GECId t
	=	GECId !(R2Id (GECMsgIn t) (GECMsgOut t))

openGECId :: !*env -> (!GECId t,!*env) | Ids env
openGECId env
	# (r2id,env) = openR2Id env
	= (GECId r2id,env)

GECIdtoId :: !(GECId t) -> Id
GECIdtoId (GECId rid) = r2IdtoId rid

instance == (GECId t) where
	(==) (GECId a) (GECId b) = a==b

isGECIdBound :: !(GECId t) !(IOSt .ps) -> (!Bool,!IOSt .ps)
isGECIdBound gecId ioSt
	= isIdBound (GECIdtoId gecId) ioSt

instance Controls (GECReceiver t) where
	controlToHandles (GECReceiver (GECId rid) rfun) pSt = controlToHandles (Receiver2 rid rfun []) pSt
	getControlType   _                                  = "GECReceiver"
instance Receivers (GECReceiver t) where
	openReceiver ls (GECReceiver (GECId rid) rfun)  pSt = openReceiver ls (Receiver2 rid rfun []) pSt
	getReceiverType _                                   = "GECReceiver"

openGEC :: !(GECId t) !(PSt .ps) -> PSt .ps
openGEC gecId pSt = snd (sendAndCheck gecId InOpenGEC "openGEC" pSt)

closeGEC :: !(GECId t) !(PSt .ps) -> PSt .ps
closeGEC gecId pSt = snd (sendAndCheck gecId InCloseGEC "closeGEC" pSt)

getGECvalue :: !(GECId t) !(PSt .ps) -> (t,!PSt .ps)
getGECvalue gecId pSt
	= case sendAndCheck gecId InGetValue "getGECvalue" pSt of
		(OutGetValue v,pSt)	= (v,pSt)
		(wrong,        pSt)	= abort "getGECvalue: wrong response from receiver."

setGECvalue :: !(GECId t) !IncludeUpdate !t !(PSt .ps) -> PSt .ps
setGECvalue gecId i v pSt = snd (sendAndCheck gecId (InSetValue i v) "setGECvalue" pSt)

openGECGUI :: !(GECId t) !(!GUILoc,!OBJECTControlId) !(PSt .ps) -> PSt .ps
openGECGUI gecId (guiLoc,objLoc) pSt = snd (sendAndCheck gecId (InOpenGUI guiLoc objLoc) "openGECGUI" pSt)

closeGECGUI :: !(GECId t) !KeepActiveCONS !(PSt .ps) -> PSt .ps
closeGECGUI gecId keepCONS pSt = snd (sendAndCheck gecId (InCloseGUI keepCONS) "closeGECGUI" pSt)

switchGEC :: !(GECId t) !IncludeUpdate ![ConsPos] !(PSt .ps) -> PSt .ps
switchGEC gecId yesUpdate path pSt = snd (sendAndCheck gecId (InSwitchCONS yesUpdate path) "switchGEC" pSt)

arrangeGEC :: !(GECId t) !Arrangement ![ConsPos] !(PSt .ps) -> PSt .ps
arrangeGEC gecId arrangement path pSt = snd (sendAndCheck gecId (InArrangeCONS arrangement path) "arrangeGEC" pSt)

sendAndCheck :: !(GECId t) (GECMsgIn t) String !(PSt .ps) -> (GECMsgOut t,!PSt .ps)
sendAndCheck (GECId r2id) msg fName pSt
	= case syncSend2 r2id msg pSt of
		((SendOk,Just out),pSt) = (out,pSt)
		(wrong,            pSt) = abort (fName +++ ": wrong response from receiver.")
