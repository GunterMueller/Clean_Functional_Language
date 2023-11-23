module combinatorTest

import StdEnv, htmlTask, htmlTrivial

// (c) MJP 2007

// Just a scratch file to test the different combinators

// Known bugs 
// -> an andTask should skip to add html code of the task being selected by the user

derive gUpd []
derive gForm []

Start world = doHtmlServer (multiUserTask 9 True (foreverTask_Std simpleMile)) world






// the following obscure tasks have been tested succesfully

// test repeat
testRepeat = simpleAnd <| (\n -> sum n > 100,\n -> [Txt "sum should be larger then 100",Br, toHtml n, Br])



// closure task test


// mile stone task
simpleMile = show( andTasks_mstone [("task " <+++ i,simple) \\ i <- [0..2]])

// andTask tests
simpleAnd3 	= andTasks [("task " <+++ i,simple_mu i 0 (simple2 i)) \\ i <- [0..1]]
simpleAnd2 	= andTasks [("task " <+++ i,simple) \\ i <- [0..3]]
simpleAnd 	= show( andTasks [("task " <+++ i,simple) \\ i <- [0..2]])
myAndTasks2 = andTasks [("MyTask " <+++ i,
						("W" <+++ i,i) @: (editTask ("OK " <+++ i) i =>> \v -> 
						("B1",0) @: editTask ("OK " <+++ v) v))
						\\ i <- [0..3]]
			=>> \val -> return_D val
myAndTasks = andTasks ([("MyTask " <+++ i,editTask ("OK " <+++ i) i) \\ i <- [0..3]] ++ 
					 [("Special",1 @:: orTasks [("Temp",editTask "SpecOK" 4),("Temp2",2 @:: editTask "SpecOK" 4)])])
			=>> \val -> return_D val

// orTasks tests
simpleOr 	= show( orTasks [("task " <+++ i,simple) \\ i <- [0..3]])
myOrTasks = orTasks ([("MyTask " <+++ i,editTask ("OK " <+++ i) i) \\ i <- [0..3]] ++ 
					 [("Special",1 @:: orTasks [("Temp",editTask "SpecOK" 4),("Temp2",2 @:: editTask "SpecOK" 4)])])
			=>> \val -> return_D val
myOrTasks2 = orTasks [("MyTask " <+++ i,
						("W" <+++ i,i) @: (editTask ("OK " <+++ i) i =>> \v -> 
						("B1",0) @: editTask ("OK " <+++ v) v))
						\\ i <- [0..3]]
			=>> \val -> return_D val

// multi user tests
mysingletest 		= simple_mu 0 1 (simple_mu 1 0 simple)
myduotest 			= duo 0 (duo 1 simple)
duo i task 			= show (simple_mu 0 i task) #>> show (simple_mu 1 i task)
simple_mu n i task 	= ("MyTask " <+++ n, i) @: task

// super simple editors
show task			= task =>> \v -> return_D v
simple  			= editTask "OK" 0
simple2 n 			= [Txt "Fill in integer value:"] ?>> editTask "OK" n

