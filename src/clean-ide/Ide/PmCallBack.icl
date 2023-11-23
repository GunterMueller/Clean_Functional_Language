implementation module PmCallBack

from IdeState import ::General,::PSt,::Id,getInterrupt
from interrupt import StartIntr,ContIntr,StopIntr

:: *GeneralSt :== PSt General

start :: !.a !(.Bool -> .(.a -> .(*GeneralSt -> *(.a,*GeneralSt)))) !*GeneralSt -> *GeneralSt
start ini_step step ps
	#! (intr_info,ps) 	= getInterrupt ps
	= StartIntr intr_info ini_step step ps

cont :: !*(.a,!*GeneralSt) -> *(.a,!*GeneralSt);
cont (ls,ps)
	# (intr_info,ps) 	= getInterrupt ps
	# ps				= ContIntr intr_info ps
	= (ls,ps)

stop :: !*(.a,!*GeneralSt) -> *(.a,!*GeneralSt);
stop (ls,ps)
	# (intr_info,ps) 	= getInterrupt ps
	# ps				= StopIntr intr_info ps
	= (ls,ps)
