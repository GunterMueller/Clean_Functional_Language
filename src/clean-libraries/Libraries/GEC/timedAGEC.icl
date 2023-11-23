implementation module timedAGEC

import genericgecs, guigecs, infragecs
import StdPSt, StdTimer
import modeAGEC

// Timer driven GEC

:: Timed = Timed (Int ->Int) Int						

//	{location,makeUpValue,outputOnly,gec_value,update}

gGEC{|Timed|} args=:{gec_value=Just (Timed updfun i),update=tiupdate} pSt
# (tid,pSt) 		= openId pSt
# (ahandle,pSt)		= gGEC {|*|} {args & gec_value=Just (Hide i),update=aupdate} pSt
# pSt				= snd (openTimer Void (timer tid ahandle) pSt)
= convert tid (ahandle,pSt)
where
	convert tid (ahandle,pSt) = ({ahandle & gecSetValue = set tid ahandle
	                               		  , gecGetValue = get tid ahandle
	                          	 },pSt)

	set tid ahandle upd (Timed updfun ni) pSt
	# pSt = appPIO (setTimerInterval tid ni) pSt
	= ahandle.gecSetValue upd (Hide ni) pSt

	get tid ahandle pSt
	# (Hide ni,pSt) = ahandle.gecGetValue pSt
	= (Timed updfun ni,pSt)

	aupdate reason (Hide ni) pSt = tiupdate reason (Timed updfun ni) pSt
		
	timer tid ahandle = (Timer i NilLS [TimerId tid, TimerFunction (timeout tid ahandle)])
	where
		timeout tid ahandle _ (lSt,pSt)
		# (Hide i,pSt) = ahandle.gecGetValue pSt
		# ni = updfun i
		# pSt = appPIO (setTimerInterval tid ni) pSt
		= (lSt,ahandle.gecSetValue YesUpdate (Hide ni) pSt)
