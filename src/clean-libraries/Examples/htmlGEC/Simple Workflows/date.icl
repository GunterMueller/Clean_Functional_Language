module date

import StdEnv, StdHtml

// (c) MJP 2007

// findDate will settle a date and time between two persons that want to meet
// first a person is chosen by the person taken the initiative, person 0
// then a date is settled by the two persons by repeatedly asking each other for a convenient date
// if such a date is found both have to confirm the date and the task is finished

npersons = 5

Start world = doHtmlServer (multiUserTask npersons True findDate) world

findDate :: Task (HtmlDate,HtmlTime)
findDate
=	[Txt "Choose person you want to date:",Br] 
	?>>	editTask "Set" (PullDown (1,100) (0,[toString i \\ i <- [1..npersons]])) =>> \whomPD ->
	let whom = toInt(toString whomPD)
	in
	[Txt "Determining date:",Br,Br] 
	?>>	findDate` whom (Date 1 1 2007,Time 9 0 0) =>> \datetime	->
	[] ?>> confirm 0 whom datetime -&&- confirm whom 0 datetime #>>
	return_V datetime
where
	findDate` :: Int (HtmlDate,HtmlTime) -> Task (HtmlDate,HtmlTime)
	findDate` whom daytime
	=	proposeDateTime daytime =>> \daytime ->
		("Meeting Request",whom) @: determineDateTime daytime =>> \(ok,daytime) ->
		if ok (return_V daytime)
		(	isOkDateTime daytime =>> \ok ->
			if ok (return_V daytime)
			      (newTask "findDate`" (findDate` whom daytime))
		)
	where
		proposeDateTime :: (HtmlDate,HtmlTime) -> Task (HtmlDate,HtmlTime)
		proposeDateTime (date,time)
		=	[Txt "Propose a new date and time for meeting",Br,Br] 
			?>>	editTask "Set" input =>> \(_,date,_,time) -> 
			return_V (date,time)
		where
			input = (showHtml [Txt "date: "], date, showHtml [Txt "time: "], time)

		determineDateTime :: (HtmlDate,HtmlTime) -> Task (Bool,(HtmlDate,HtmlTime))
		determineDateTime daytime
		=	isOkDateTime daytime =>> \ok ->
			if ok (return_V (ok,daytime))
			(	proposeDateTime daytime =>> \daytime ->
				return_V (ok,daytime)
			)

		isOkDateTime :: (HtmlDate,HtmlTime) -> Task Bool
		isOkDateTime (date,time)
		=	[Txt ("Can we meet on the " <+++ date <+++ " at " <+++ time <+++ "?"),Br] 
			?>>	chooseTask	[ ("Accept",return_V True)
						 	, ("Sorry", return_V False)
						 	]

	confirm  :: Int Int (HtmlDate,HtmlTime) -> Task Void 
	confirm me you (date,time)
	= 	me @::	[Txt ("User " <+++ me <+++ " and " <+++ you <+++ " have a meeting on " <+++ date <+++ " at " <+++ time),Br,Br] 
				?>>	editTask "OK" Void
				
