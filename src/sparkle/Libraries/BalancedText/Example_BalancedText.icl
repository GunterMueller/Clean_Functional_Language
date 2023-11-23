module
	Example

import
	StdEnv,
	StdIO,
	BalancedText

ExampleDialog
	= Dialog "Example dialog - close to exit example program"
		(    BalancedTextControl "The dialog will be of the same width as this text. (which is approx. 350)" 350
				[] 
				[]
		 :+: BalancedTextControl "And this longer text will be adjusted as much as possible to fit this width. This includes spanning multiple lines. " 350
		 		[ BalancedTextColour			Red
		 		, BalancedTextBackgroundColour	Black
		 		, BalancedTextFontSize			12
		 		, BalancedTextFontFace			"Comic Sans MS"
		 		, BalancedTextFontStyle			["bold"]
		 		]
		 		[ ControlPos					(Left, zero)
		 		]
		) [WindowClose (noLS closeProcess)]

LargeDialog
	= Window "Large window - test update speed"
		(    BalancedTextControl (foldr (+++) "" (repeatn 500 "Hallo ")) 650 [] [] 
		)
		[]
            
Start :: *World -> *World
Start world
	= startIO MDI 0 initialize [ProcessClose closeProcess] world   
	where
		initialize :: (*PSt .ps) -> *PSt .ps
		initialize state
			# (_, state)		= openDialog 0 ExampleDialog state
			# (_, state)		= openDialog 0 ExampleDialog state
			# many_hallos		= foldr (+++) "" (repeatn 500 "Hallo ")
			# state				= BalancedTextWindow "TEST window" many_hallos 500 {w=300,h=100} [] [] state
			= state
