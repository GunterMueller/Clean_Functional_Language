implementation module Random


import	StdInt, StdClass
import	StdTime
import htmlHandler, GenPrint, GenParse

derive bimap (,), Maybe

::	RandomSeed	= RS !Int
derive gForm RandomSeed; derive gUpd RandomSeed; derive gParse RandomSeed; derive gPrint RandomSeed

nullRandomSeed :: RandomSeed
nullRandomSeed
	=	RS 0

getNewRandomSeed :: !*env -> (!RandomSeed, !*env) | TimeEnv env
getNewRandomSeed env
	#	({hours,minutes,seconds}, env)	= getCurrentTime env
	=	(RS (1+(hours+minutes+seconds) bitand 65535), env)

random :: !RandomSeed -> (!Int,!RandomSeed)
random (RS seed)
	=	(newSeed,RS newSeed)
where
	newSeed		= if (nextSeed>=0) nextSeed (nextSeed+65537)
	nextSeed	= (seed75 bitand 65535)-(seed75>>16)
	seed75		= seed*75
