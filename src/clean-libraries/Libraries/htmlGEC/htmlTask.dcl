definition module htmlTask

// library for controlling interactive Tasks (iTask) based on iData
// (c) 2006,2007 MJP

import htmlSettings, htmlButtons

:: *TSt										// task state
:: Task a		:== St *TSt a				// an interactive task
:: Void 		= Void						// for tasks returning non interesting results, won't show up in editors either

defaultUser		:== 0						// default id of user

derive gForm 	Void						
derive gUpd 	Void, TClosure
derive gPrint 	Void, TClosure
derive gParse 	Void
derive gerda 	Void

/* Initiating the iTask library:
startTask		:: start iTasks beginning with user with given id, True if trace allowed
				 	id < 0	: for login purposes.						
startNewTask	:: same, lifted to iTask domain, use it after a login ritual						
singleUserTask 	:: start wrapper function for single user 
multiUserTask 	:: start wrapper function for user with indicated id with option to switch between [0..users - 1]  
multiUserTask2 	:: same, but forces an automatic update request every (n minutes, m seconds)  
*/

startTask 		:: !Int !Bool !(Task a) 	!*HSt -> (a,[BodyTag],!*HSt) 	| iCreate a
startNewTask 	:: !Int !Bool !(Task a) 		  -> Task a 				| iCreateAndPrint a 

singleUserTask 	:: !Int	!Bool !(Task a) 	!*HSt -> (Html,*HSt) 			| iCreate a
multiUserTask 	:: !Int !Bool !(Task a)  	!*HSt -> (Html,*HSt) 			| iCreate a
multiUserTask2 :: !(!Int,!Int) !Int !Bool !(Task a) !*HSt -> (Html,*HSt) 	| iCreate a 


/* promote iData editor
editTask		:: create an editor with button to finish task
(<<@)			:: set iData attribute globally for indicated (composition of) iTask(s) 
*/
editTask 		:: String a 	-> Task a							| iData a 
(<<@) infix  3 	:: (Task a) b  	-> Task a 							| setTaskAttr b

class 	 setTaskAttr a :: !a *TSt -> *TSt
instance setTaskAttr Lifespan, StorageFormat, Mode

/* monadic operators on iTasks
(=>>)			:: bind
(#>>)			:: bind, no argument passed
return_V		:: return the value
*/

(=>>) infix  1 	:: (Task a) (a -> Task b) 	-> Task b
(#>>) infixl 1 	:: (Task a) (Task b) 		-> Task b
return_V 		:: a 						-> Task a 				| iCreateAndPrint a

/* prompting variants
(?>>)			:: prompt as long as task is active but not finished
(!>>)			:: prompt when task is activated
(<|)			:: repeat task (from scratch) as long as predicate does not hold, and give error message otherwise
return_VF		:: return the value and show the Html code specified
return_D		:: return the value and show it in iData display format
*/

(?>>) infix  5 	:: [BodyTag] (Task a) 		-> Task a			| iCreate a
(!>>) infix  5 	:: [BodyTag] (Task a) 		-> Task a			| iCreate a
(<|)  infix  6 	:: (Task a) (a -> .Bool, a -> [BodyTag]) 
											-> Task a | iCreate a
return_VF 		:: a [BodyTag] 		  		-> Task a			| iCreateAndPrint a
return_D		:: a 						-> Task a			| gForm {|*|}, iCreateAndPrint a

/* Assign tasks to user with indicated id
(@:)			:: will prompt who is waiting for task with give name
(@::)			:: same, default task name given
*/
(@:)  infix 3 	:: !(!String,!Int) (Task a)	-> (Task a)			| iCreate a
(@::) infix 3 	:: !Int (Task a)		    -> (Task a)			| iCreate a

/* Promote any TSt state transition function to an iTask:
newTask			:: to promote a user defined function to as task which is (possibly recursively) called when activated
newTask_GC		:: same, and garbage collect *all* (persistent) subtasks
newTask_Std		:: same, non optimized version will increase stack
*/
newTask 		:: !String (Task a) 		-> (Task a) 		| iData a 
newTask_GC 		:: !String (Task a) 		-> (Task a) 		| iData a 
newTask_Std 	:: !String (Task a) 		-> (Task a) 		| iCreateAndPrint a

/* Infinite iteration of an iTask:
foreverTask		:: infinitely repeating Task
foreverTask_GC	:: same, and garbage collect *all* (persistent) subtasks
foreverTask_Std	:: same, non optimized version will increase stack
*/
foreverTask		:: (Task a) 				-> Task a 			| iData a
foreverTask_GC	:: (Task a) 				-> Task a 			| iCreateAndPrint a
foreverTask_Std	:: (Task a) 				-> Task a 			| iCreateAndPrint a

/* Conditional iteration of an iTask:
repeatTask		:: repeat Task until predict is valid
repeatTask_GC	:: same, and garbage collect *all* (persistent) subtasks
repeatTask_Std	:: same, non optimized version will increase stack
*/
//repeatTask		:: (Task a) 				-> Task a 			| iData a
//repeatTask_GC	:: (Task a) 				-> Task a 			| iCreateAndPrint a
repeatTask_Std	:: (a -> Task a) (a -> Bool) -> a -> Task a		| iCreateAndPrint a

/*	Sequencing Tasks:
seqTasks		:: do all iTasks one after another, task completed when all done
*/
seqTasks		:: [(String,Task a)] 	-> (Task [a])			| iCreateAndPrint a

/* Choose Tasks
buttonTask		:: Choose the iTask when button pressed
chooseTask		:: Choose one iTask from list, depending on button pressed
chooseTask_pdm	:: Choose one iTask from list, depending on pulldownmenu item selected
mchoiceTask		:: Multiple Choice of iTasks, depending on marked checkboxes
*/
buttonTask		:: String (Task a)		-> (Task a) 			| iCreateAndPrint a
chooseTask		:: [(String,Task a)] 	-> (Task a) 			| iCreateAndPrint a
chooseTask_pdm 	:: [(String,Task a)] 	-> (Task a)	 			| iCreateAndPrint a
mchoiceTasks 	:: [(String,Task a)] 	-> (Task [a]) 			| iCreateAndPrint a

/* Do m Tasks parallel / interleaved and FINISH as soon as SOME Task completes:
orTask			:: do both iTasks in any order, task completed and ends as soon as first one done
(-||-)			:: same, now as infix combinator
orTask2			:: do both iTasks in any order, task completed and ends as soon as first one done
orTasks			:: do all  iTasks in any order, task completed and ends as soon as first one done
*/
orTask 			:: (Task a,Task a) 		-> (Task a) 			| iCreateAndPrint a
(-||-) infixr 3 :: (Task a) (Task a) 	-> (Task a) 			| iCreateAndPrint a
orTask2			:: (Task a,Task b) 		-> (Task (EITHER a b)) 	| iCreateAndPrint a & iCreateAndPrint b
orTasks			:: [(String,Task a)] 	-> (Task a)				| iCreateAndPrint a 

/* Do Tasks parallel / interleaved and FINISH when ALL Tasks done:
andTask			:: do both iTasks in any order (interleaved), task completed when both done
(-&&-)			:: same, now as infix combinator
andTasks		:: do all  iTasks in any order (interleaved), task completed when all  done
andTasks_mu		:: assign task to indicated users, task completed when all done
*/
andTask			:: (Task a,Task b) 		-> (Task (a,b)) 		| iCreateAndPrint a & iCreateAndPrint b
(-&&-) infixr 4 :: (Task a) (Task b) 	-> (Task (a,b)) 		| iCreateAndPrint a & iCreateAndPrint b
andTasks		:: [(String,Task a)]	-> (Task [a])			| iCreateAndPrint a
andTasks_mu 	:: String [(Int,Task a)]-> (Task [a]) 			| iData a

/* Do not yet use when you garbage collect tasks !!
andTasks_mstone :: do all iTasks in any order (interleaved), task completed when all done
					but continue with next task as soon as one of the tasks is completed
					string indicates which task delivered what
*/
andTasks_mstone :: [(String,Task a)] 	-> (Task [(String,a)]) 		| iCreateAndPrint a

/* Time and Date management:
waitForTimeTask	:: Task is done when time has come
waitForTimerTask:: Task is done when specified amount of time has passed 
waitForDateTask	:: Task is done when date has come
*/
waitForTimeTask	:: HtmlTime				-> (Task HtmlTime)
waitForTimerTask:: HtmlTime				-> (Task HtmlTime)
waitForDateTask	:: HtmlDate				-> (Task HtmlDate)

/* Do not yet use when you garbage collect tasks !!
-!>				:: a task, either finished or interrupted (by completion of the first task) is returned in the closure
				   if interrupted, the work done so far is returned and can be can be continued somewhere else
channel			:: splits a task in respectively a sender task and receiver task; the sender can be edited as usual. 
				   When the sender task is finshed the receiver task gets its result and is finished as well.
*/
:: TClosure a 	= TClosure (Task a)			

(-!>) infix 4 	:: (Task stop) (Task a) -> (Task (Maybe stop,TClosure a)) | iCreateAndPrint stop & iCreateAndPrint a
channel  		:: String (Task a) 		-> (Task (TClosure a,TClosure a)) | iCreateAndPrint a

/* Operations on Task state
taskId			:: id assigned to task
userId			:: id of application user
addHtml			:: add html code
*/

taskId			:: TSt -> (Int,TSt)
userId 			:: TSt -> (Int,TSt)
addHtml 		:: [BodyTag] TSt -> TSt

/* Lifting to iTask domain
(*>>)			:: lift functions of type (TSt -> (a,TSt)) to iTask domain 
(@>>)			:: lift functions of (TSt -> TSt) to iTask domain 
appIData		:: lift iData editors to iTask domain
appHSt			:: lift HSt domain to TSt domain, will be executed only once
appHSt2			:: lift HSt domain to TSt domain, will be executed on each invocation
*/
(*>>) infix 4 	:: (TSt -> (a,TSt)) (a -> Task b) 	-> Task b
(@>>) infix 4 	:: (TSt -> TSt) (Task a) 			-> Task a
appIData 		:: (IDataFun a) 					-> Task a 			| iData a
appHSt 			:: (HSt -> (a,HSt)) 				-> Task a			| iData a
appHSt2			:: (HSt -> (a,HSt)) 				-> Task a			| iData a

/* Controlling side effects
Once			:; 	task will be done only once, the value of the task will be remembered
*/

Once 			:: (Task a) 						-> (Task a) 		| iData a


