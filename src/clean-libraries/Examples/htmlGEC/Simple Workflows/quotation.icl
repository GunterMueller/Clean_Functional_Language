module quotation

import StdEnv, StdHtml, GenEq

// (c) 2007 MJP

// A task is given to user 0
// When finished the result of the task is reviewed by user 1
// He can comment on the task, or approve or cancel it
// When the result needs more work, the whole process is repeated
// Otherwise the task is completed
// The task itself in the example is a quotation form that needs to be filled in

derive gForm 	QForm, Review, Person, Gender
derive gUpd 	QForm, Review, Person, Gender
derive gParse 	QForm, Review, Person, Gender
derive gPrint 	QForm, Review, Person, Gender
derive gerda 	QForm, Review, Person, Gender


:: Persoonsgegevens
				=	{ naam :: String
					, e_mail :: String
					}
:: Verzendgegevens
				=	{ adres 	:: String
					, postcode 	:: String
					, plaats 	:: String
					}

//Start world = doHtmlServer (multiUserTask 2 (reviewtask <<@ Persistent)) world
Start world = doHtmlServer (multiUserTask 2 True reviewtask) world

:: QForm = 	{ toComp 			:: String
			, startDate 		:: HtmlDate
			, endDate 			:: HtmlDate
			, estimatedHours 	:: Int
			, description		:: TextArea
			, price				:: Real 	
			}
::	Person = { firstName		:: String
			 , surname			:: String
			 , dateOfBirth		:: HtmlDate
			 , gender			:: Gender
			 }
::	Gender = Male | Female
:: Review = Approved | Rejected | NeedsRework TextArea

reviewtask :: Task (QForm,Review)
reviewtask = taskToReview 1 (createDefault, mytask)

mytask :: a -> (Task a) | iData a
mytask v = [Txt "Fill in Form:",Br,Br] ?>> editTask "TaskDone" v <<@ Submit

taskToReview :: Int (a,a -> Task a) -> Task (a,Review) | iData a
taskToReview reviewer (v`,task) 
= newTask "taskToReview" taskToReview`
where
	taskToReview`
	=	task v`               =>> \v ->
		reviewer @:: review v =>> \r ->
		[Txt ("Reviewer " <+++ reviewer <+++ " says "),toHtml r,Br] ?>> 
		editTask "OK" Void #>>
		case r of
			(NeedsRework _) -> taskToReview reviewer (v,task) 	
			else            -> return_V (v,r)

review :: a -> Task Review | iData a
review v
=	[toHtml v,Br,Br] ?>>
	chooseTask
		[ ("Rework",  editTask "Done" (NeedsRework createDefault) <<@ Submit)
		, ("Approved",return_V Approved)
		, ("Reject",  return_V Rejected)
		]
