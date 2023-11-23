definition module Random

//	**************************************************************************************************
//
//	General utility for random number generation.
//
//	This module has been moved to htmlGEC because it needs to export derived generic instances
//	for the abstract type RandomSeed of gForm, gUpd, gParse, and gPrint.
//	
//	**************************************************************************************************

import htmlHandler, GenPrint, GenParse
from StdTime import class TimeEnv, instance TimeEnv World

::	RandomSeed
derive gForm RandomSeed; derive gUpd RandomSeed; derive gParse RandomSeed; derive gPrint RandomSeed

nullRandomSeed	:: RandomSeed
//	nullRandomSeed generates a useless RandomSeed (random nullRandomSeed = (0,nullRandomSeed)).

getNewRandomSeed:: !*env	-> (!RandomSeed, !*env)	| TimeEnv env
//	GetNewRandomSeed generates a useful RandomSeed, using the current time.

random			:: !RandomSeed		-> (!Int, !RandomSeed)
//	Given a RandomSeed, Random generates a random number and a new RandomSeed.
