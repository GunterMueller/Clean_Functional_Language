module 
	Example

import
	StdEnv,
	StdIO,
	MarkUpText

FunctionExample1 	=	[ CmBackgroundColour Green, CmBText "map :: (a -> b) [a] -> [b]", CmFillLine, CmEndBackgroundColour, CmNewline
						, CmText "map f [] ",     CmAlign "1", CmText "= []", CmNewline
						, CmText "map f [x:xs] ", CmAlign "1", CmText "= [f x: map f xs]"
						]
FunctionExample2 	=	[ CmBackgroundColour Green, CmBText "map :: (a -> b) [a] -> [b]", CmFillLine, CmEndBackgroundColour, CmNewline
						, CmText "map f _x", CmNewline
						, CmTabSpace, CmText "= "
						] ++ Case1
					where
						Case1 =	[ CmScope 
								, CmBText "case ", CmText "_x ", CmBText "of", CmNewline, CmTabSpace
								, CmAlign "c_pat", CmText "[] ",     CmAlign "c_end_pat", CmText "-> []", CmNewline
								, CmAlign "c_pat", CmText "[x:xs] ", CmAlign "c_end_pat", CmText "-> [f x: map f xs]"
								, CmEndScope
								]
FunctionExample3	=	[ CmLink "scroll down to [end]" "end", CmNewline
						, CmText "eqList :: [a] [a] -> Bool | == a", CmNewline
						, CmText "eqList _x _y", CmNewline
						, CmTabSpace, CmText "= "
						] ++ Case1 ++ [CmLabel "end" True]
					where
						Case1 =	[ CmScope
								, CmBText "case ", CmText "_x ", CmBText "of", CmNewline, CmTabSpace
								, CmAlign "c_pat", CmText "[] ",     CmAlign "c_end_pat", CmText "-> "] ++ Case2 ++ [CmNewline
								, CmAlign "c_pat", CmText "[x:xs] ", CmAlign "c_end_pat", CmText "-> "] ++ Case3
						Case2 = [ CmScope
								, CmBText "case ", CmText "_y ", CmBText "of", CmNewline, CmTabSpace
								, CmAlign "c_pat", CmText "[] ",       CmAlign "c_end_pat", CmText "-> True", CmNewline
								, CmAlign "c_pat", CmBText "default ", CmAlign "c_end_pat", CmText "-> False"
								, CmEndScope
								]
						Case3 = [ CmScope
								, CmBText "case ", CmText "_y ", CmBText "of", CmNewline, CmTabSpace
								, CmAlign "c_pat", CmText "[] ",     CmAlign "c_end_pat", CmText "-> False", CmNewline
								, CmAlign "c_pat", CmText "[y:ys] ", CmAlign "c_end_pat", CmText "-> x == y && eqList xs ys"
								, CmEndScope
								]
RatingExample1 		= 	[ CmBold, CmUText "Indeling ronde 1:", CmEndBold, CmNewline
						, CmLink "Maarten de Mol" "Maarten de Mol", CmChangeSize (-4), CmColour Red, CmText "[1909]", CmEndColour, CmEndSize
						, CmAlign "1", CmText " - ", CmAlign "2"
						, CmText "M. Beekhuis", CmChangeSize (-4), CmColour Red, CmText "[2011]", CmEndColour, CmEndSize
						, CmAlign "3", CmText " 0 - 1", CmNewline
						, CmText "C. van Dijk", CmChangeSize (-4), CmColour Red, CmText "[1692]", CmEndColour, CmEndSize
						, CmAlign "1", CmText " - ", CmAlign "2" 
						, CmLink "Jan-Willem Hoentjen" "Jan-Willem Hoentjen", CmChangeSize (-4), CmColour Red, CmText "[1848]", CmEndColour, CmEndSize
						, CmAlign "3", CmText " 0 - 1"
						]
ListExample1		=	[ CmRight,  CmIText  "1. ", CmAlign "voor", CmCenter, CmLink "Assembly (Intel)"       0,  CmAlign "na", CmNewline
						, CmRight,  CmIText  "2. ", CmAlign "voor", CmCenter, CmLink "Assembly (Mac)"         0,  CmAlign "na", CmNewline
						, CmRight,  CmIText  "3. ", CmAlign "voor", CmCenter, CmLink "Assembly (Sparc)"       0,  CmAlign "na", CmNewline
						, CmRight,  CmIText  "4. ", CmAlign "voor", CmCenter, CmLink "C"                      0,  CmAlign "na", CmNewline
						, CmRight,  CmIText  "5. ", CmAlign "voor", CmCenter, CmLink "C++"                    0,  CmAlign "na", CmNewline
						, CmRight,  CmIText  "6. ", CmAlign "voor", CmCenter, CmLink "Clean"                  1,  CmAlign "na", CmNewline
						, CmRight,  CmIText  "7. ", CmAlign "voor", CmCenter, CmLink "Java"                   0,  CmAlign "na", CmNewline
						, CmRight,  CmIText  "8. ", CmAlign "voor", CmCenter, CmLink "Haskell"                0,  CmAlign "na", CmNewline
						, CmRight,  CmIText  "9. ", CmAlign "voor", CmCenter, CmLink "ML"                     0,  CmAlign "na", CmNewline
						, CmRight,  CmIText "10. ", CmAlign "voor", CmCenter, CmLink "Pascal"                 0,  CmAlign "na", CmNewline
						, CmRight,  CmIText "11. ", CmAlign "voor", CmCenter, CmLink "Scheme"                 0,  CmAlign "na"
						]

      
ExampleDialog status_id rid
	= Dialog "Example dialog" 
		(     MarkUpControl		FunctionExample1 [] []
		  :+: MarkUpControl		FunctionExample2 
		  							[ MarkUpFontFace			"Comic Sans MS"
		  							, MarkUpTextSize			10
		  							, MarkUpBackgroundColour	Blue
		  							, MarkUpTextColour			White
		  							] 
		  							[ ControlPos				(Left, zero)
		  							]
		  :+: MarkUpControl		FunctionExample3 
		  							[ MarkUpFontFace			"MS Serif"
		  							, MarkUpTextSize			10
		  							, MarkUpBackgroundColour	Black
		  							, MarkUpTextColour			Red
		  							, MarkUpNrLines				3
		  							, MarkUpHScroll
		  							, MarkUpVScroll
		  							, MarkUpEventHandler		event_handler1
		  							, MarkUpLinkStyle			False White Black True White Black
		  							] 
		  							[ ControlPos				(Left, zero)
		  							]
		  :+: MarkUpControl		RatingExample1   
		  							[ MarkUpTextSize			12
		  							, MarkUpBackgroundColour	LightGrey
		  							, MarkUpEventHandler		event_handler2
		  							] 
		  							[ ControlPos (Left, zero)
		  							]
		  :+: TextControl		"" [ControlPos (Left, zero)]
		  :+: TextControl       "----------------------------------------------------------"
		  							[ ControlId					status_id
		  							, ControlPos				(Center, zero)
		  							]
		  :+: MarkUpControl		[CmBText "Time elapsed: ", CmText "0 clock ticks", CmTabSpace, CmTabSpace]
		  							[ MarkUpReceiver			rid
		  							]
		  							[ ControlPos				(Left, zero)
		  							]
		)
		[ WindowClose (noLS closeProcess)
		]
	where
		event_handler1 :: (!MarkUpEvent !String) (*PSt .ps) -> (*PSt .ps)
		event_handler1 event state
			| not event.meClickEvent			= state
			= jumpToMarkUpLabel event.meOwnRId event.meLink state
		event_handler1 other state
			= state
		
		event_handler2 :: (!MarkUpEvent !String) (*PSt .ps) -> (*PSt .ps)
		event_handler2 event state
			# text								= if event.meSelectEvent "selected " ""
			# text								= if event.meClickEvent ("clicked[" +++ toString event.meNrClicks +++ "] ") text
			= appPIO (setControlText status_id (text +++ event.meLink)) state
		event_handler2 other state
			= state
            
Start :: *World -> *World
Start world
	= startIO MDI 0 initialize [ProcessClose closeProcess] world   
	where
		initialize :: (*PSt .ps) -> *PSt .ps
		initialize state
			# (status_id, state)		= accPIO openId state
			# (rid, state)				= accPIO openRId state
			# (timerid, state)			= accPIO openId state
			# (_, state)				= openTimer 0 (Timer 1 NilLS [TimerFunction (timer rid)]) state
			# (_, state)				= openDialog 0 (ExampleDialog status_id rid) state
			# state						= MarkUpWindow "MarkUpWindow" ListExample1
											[ MarkUpBackgroundColour		Blue
											, MarkUpTextColour				White
											, MarkUpTextSize				14
											, MarkUpLinkStyle				False Yellow Blue False White Black
											] [WindowClose (noLS closeProcess), WindowPos (Fix, OffsetVector {vx=500,vy=100})] state
			= state
			where
				timer :: (!RId (!MarkUpMessage a)) !Int (!Int, *PSt .ps) -> (!Int, *PSt .ps)
				timer rid new_ticks (ticks, state)
					# ticks				= ticks + new_ticks
					# state				= changeMarkUpText rid [CmBText "Time elapsed: ", CmText (toString ticks +++ " clock ticks")] state
					= (ticks, state)
