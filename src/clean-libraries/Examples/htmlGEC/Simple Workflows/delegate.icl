module delegate

import StdEnv, htmlTask, htmlTrivial


// (c) 2007 MJP

// Quite a difficult workflow exercise given to me by Erik Zuurbier.
// First a set of person id's is made to which a task can be delegated
// The task is actually shipped to the first person who accepts the task
// That person can stop the task whenever he wants
// Now again everybody in the set is asked again to accept the task
// The one who accepts can *continue* the work already done so far
// This process can be repeated as many times one likes until finally the task is finished


derive gForm [], Maybe
derive gUpd [], Maybe
derive gPrint Maybe

npersons = 5

//Start world = doHtmlServer (multiUserTask npersons True (delegate mytask2 (Time 0 3 0) <<@ TxtFile)) world
Start world = doHtmlServer (multiUserTask npersons True (delegate mytask2 (Time 0 3 0) )) world


mytask = editTask "Done" 0
mytask2 =	editTask "Done1" 0 =>> \v1 ->	
			editTask "Done2" 0 =>> \v2 ->	
			editTask "Done3" 0 =>> \v3 -> 
			return_D (v1 + v2 + v3)

delegate :: (Task a) HtmlTime -> (Task a) | iData a
delegate task time 
=	[Txt "Choose persons you want to delegate work to:",Br,Br] 
	?>>	determineSet [] =>> \set -> 
	delegateToSomeone task set =>> \result -> 
	return_D result
where
	delegateToSomeone :: (Task a) [Int] -> (Task a) | iData a
	delegateToSomeone task set = newTask "delegateToSet" doDelegate
	where 
		doDelegate						
		 =	orTasks [("Waiting for " <+++ who, who @:: buttonTask "I Will Do It" (return_V who)) \\ who <- set]	=>> \who ->	
			who @:: stopTask2 -!> task =>> \(stopped,TClosure task) -> 
		 	if (isJust stopped) (delegateToSomeone task set) task   
	
		stopTask 		= buttonTask "Stop" (return_V True)					  			

		stopTask2		= stopTask -||- (0 @:: stopTask)	
//		stopTask2		= stopTask -||- timerStop time -||- (0 @:: stopTask)	

		timerStop time	= waitForTimerTask time #>> return_V True
	
						  			

determineSet set = newTask "determineSet" determineSet`
where
	determineSet`	
	=	[Txt ("Current set:" +++ print set)] 
		?>> chooseTask	[("Add Person", cancelTask choosePerson =>> \nr  -> return_V nr)
						,("Finished",	return_V Nothing)
						] =>> \result -> 
		case result of
			(Just new)  -> determineSet (sort (removeDup [new:set])) 
			Nothing		-> return_V set

	choosePerson =	editTask "Set" (PullDown (1,100) (0,[toString i \\ i <- [1..npersons]])) =>> \whomPD -> 
					return_V (Just (toInt(toString whomPD)))

	cancelTask task = task -||- buttonTask "Cancel" (return_V createDefault)
	
	print [] = ""
	print [x:xs] = toString x +++ " " +++ print xs
						  			
