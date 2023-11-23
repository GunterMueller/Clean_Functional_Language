module deadline

import StdEnv, htmlTask, htmlTrivial

derive gForm []
derive gUpd  []

// (c) MJP 2007

// One can select a user to whom a task is delegated
// This user will get a certain amount of time to finish the task
// If the task is not finished on time, the task will be shipped back to the original user who has to do it instead
// It is also possible that the user becomes impatient and he can cancel the delegated task even though the deadline is not reached


npersons = 5

Start world = doHtmlServer (multiUserTask npersons True (foreverTask (deadline mytask))) world

mytask = editTask "OK" 0 <| ((<) 23,\n -> [Txt ("Error " <+++ n <+++ " should be larger than 23")])

deadline :: (Task a) -> (Task a) | iData a
deadline task
=	[Txt "Choose person you want to delegate work to:",Br,Br] 
	?>>	editTask "Set" (PullDown (1,100) (0,map toString [1..npersons])) =>> \whomPD ->	
	[Txt "How long do you want to wait?",Br,Br] 
	?>>	editTask "SetTime" (Time 0 0 0) =>> \time ->
	[Txt "Cancel delegated work if you are getting impatient:",Br,Br] 
	?>> delegateTask (toInt(toString whomPD)) time task
		-||-
		buttonTask "Cancel" (return_V (False,createDefault))=>> CheckDone
where
	CheckDone (ok,value)
	| ok =	[Txt ("Result of task: " +++ printToString value),Br,Br] 
			?>>	buttonTask "OK" (return_V value)
	=		[Txt "Task expired or canceled, you have to do it yourself!",Br,Br] 
			?>>	buttonTask "OK" task

	delegateTask who time task
	= ("Timed Task",who) 	
	  @: 	(( waitForTimeTask time #>> 							// wait for deadline
			  return_V (False,createDefault) )						// return default value
			-||-
			([Txt ("Please finish task before " <+++ time),Br,Br] 	// tell deadline
			?>> task =>> \v -> return_V (True,v)))					// do task and return its result


