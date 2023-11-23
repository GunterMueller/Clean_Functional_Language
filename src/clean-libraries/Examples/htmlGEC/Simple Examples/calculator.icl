module calculator

// simple spreadsheet example
// (c) MJP 2005

import StdEnv
import StdHtml

//Start world  = doHtmlServer arrowcalculator world
Start world  = doHtmlServer calculator world

calculator hst
# (calcfun,hst) 	= TableFuncBut (initID myCalculator) hst			// shows buttons
# (display,hst) 	= mkStoreForm  (initID myDisplay) calcfun.value hst	// calculates new values	
= mkHtml "Calculator"
	[ H1 [] "Calculator Example: "
	, toBody display 
	, toBody calcfun
	] hst

	
myDisplay		= nFormId "display" (0 <|> 0)

myCalculator	= nFormId "calcbut" calcbuttons
where
	calcbuttons = 	[	[(but "7",set 7),	(but "8",set 8),	(but "9",set 9)	]
					,	[(but "4",set 4),	(but "5",set 5),	(but "6",set 6)	]
					,	[(but "1",set 1),	(but "2",set 2),	(but "3",set 3)	]
					,	[(but "0",set 0),	(but "C",clear),    (but "CA",cla) ]	
					,	[(but "+",app (+)),	(but "-",app (-)),	(but "*",app (*))]
					,   [(but "^2",app2 (*))]
					]
	where
		set 	i 	(t <|> b) = (t 		 <|> b*10 + i)
		clear 		(t <|> b) = (t 		 <|> 0)
		cla 		(t <|> b) = (0 		 <|> 0)
		app		fun (t <|> b) = (fun t b <|> 0)
		app2    fun (t <|> b) = (fun t t <|> 0)
		
but i = LButton (defpixel / 3) i

/*
arrowcalculator hst
# (calcfun,hst) 	= TableFuncBut (initID myCalculator) hst		// shows buttons
# (display,hst) 	= startCircuit circuit calcfun.value hst	// calculates new values	
= mkHtml "Calculator" 
	[ H1 [] "Calculator Example: "
	, toBody display
	, toBody calcfun
	] hst
where
	circuit  =  store myDisplay
*/