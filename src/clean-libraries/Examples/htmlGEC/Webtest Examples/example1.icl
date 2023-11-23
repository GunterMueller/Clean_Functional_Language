module example1

import StdEnv, webServerTest

// --------- The Specification --------- //

:: State = InitState | State Int
:: In = UpButton | IntTextBox Int

spec :: State In -> [Trans Html State]
spec InitState	input			= [ FTrans (\_ = [State 0]) ]
spec (State n)	UpButton		= [ FTrans increment ]
								where
									increment [html]
										| htmlPageTitle html == [userPageTitle] && htmlEditBoxValues html displayName == [n+1]
										= [State (n+1)]
									increment _ = []
spec (State n)	(IntTextBox m)	= [ FTrans setToVal ]
								where
									setToVal [html]
										| htmlPageTitle html == [userPageTitle] && htmlEditBoxValues html displayName == [m]
											= [State m]
									setToVal _ = []

derive ggen		In, State
derive gEq		State
derive genShow	In, State

transInput UpButton = HtmlButton "+I"
transInput (IntTextBox n) = HtmlIntTextBox displayName n
trasnInput _ = abort "Undefined input in trasnInput"

// --------- The Implementation --------- //

userpage :: *HSt -> (Html,*HSt)
userpage hst
# (butfun,hst) 	= TableFuncBut (nFormId "calcbut") incbut hst			// shows buttons
# (display,hst)	= mkStoreForm (nFormId displayName) 0 butfun.value hst	// calculates new values	
= mkHtml userPageTitle
	[ H1 [] "Calculator Example: "
	, toBody display 
	, toBody butfun 
	] hst
where
	incbut = [[(LButton (defpixel / 3) "+1",f)]]
	f n
		| n rem 10 == 5
			= n+2		// the inserted error
			= n+1


// --------- Common Definitions --------- //

userPageTitle = "Calculator"
displayName = "display"

// --------- Testing --------- //

Start :: *World -> *World
Start world
	= testHtml [Nsequences 10, Ntests 100] spec InitState transInput userpage world