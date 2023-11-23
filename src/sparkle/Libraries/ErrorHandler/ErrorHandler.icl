implementation module 
   ErrorHandler

import 
   StdEnv,
   StdIO,
   MarkUpText,
   BalancedText,
   ControlMaybe

from StdFunc import seq
   
// ---------------------------------------------------------------------------------------------------------
:: HandlerError a       :== [a]
:: ErrorShortMessage a  :== a -> String
:: ErrorLongMessage  a  :== a -> String
// ---------------------------------------------------------------------------------------------------------


// ---------------------------------------------------------------------------------------------------------
OK :== []
// ---------------------------------------------------------------------------------------------------------

// ---------------------------------------------------------------------------------------------------------
isOK :: !(HandlerError a) -> Bool
// ---------------------------------------------------------------------------------------------------------
isOK [error:errors]
	= False
isOK []
	= True
   
// ---------------------------------------------------------------------------------------------------------
isError :: !(HandlerError a) -> Bool
// ---------------------------------------------------------------------------------------------------------
isError [error:errors]
	= True
isError []
	= False

// ---------------------------------------------------------------------------------------------------------
pushError :: !a !(HandlerError a) -> HandlerError a
// ---------------------------------------------------------------------------------------------------------
pushError error errors
   = [error: errors]














// ---------------------------------------------------------------------------------------------------------
ErrorHandler :: !(ErrorShortMessage a) !(ErrorLongMessage a) !Bool !(HandlerError a) ![String] !*(PSt .ps)
			 -> (!String, !*PSt .ps)
// ---------------------------------------------------------------------------------------------------------
ErrorHandler _ _ _ [] _ pstate
	= ("", pstate)
ErrorHandler make_short_msg make_long_msg fatal [error:errors] buttons pstate
	# title									= make_short_msg error
	# explanation							= make_long_msg error
	# details								= map make_short_msg errors
	# (mb_bitmap, pstate)					= accFiles (openBitmap (applicationpath "Images/ErrorImage.bmp")) pstate
	# (dialog_id, pstate)					= accPIO openId pstate
	# (button_ids, pstate)					= accPIO (openIds (length buttons)) pstate
	# (dialog, pstate)						= ErrorDialog fatal title explanation details mb_bitmap buttons dialog_id button_ids pstate
	# ((_, mb_button), pstate)				= openModalDialog (hd buttons) dialog pstate
	= case mb_button of
		Nothing		-> ("", pstate)
		(Just msg)	-> (msg, pstate)

// ---------------------------------------------------------------------------------------------------------
AlmostBG		:== RGB {r=230, g=170, b=170}
BG				:== RGB {r=210, g=140, b=140}
TitleFG			:== RGB {r=150, g=  0, b=  0}

GreenBG			:== RGB {r=140, g=210, b=140}
// ---------------------------------------------------------------------------------------------------------

// ---------------------------------------------------------------------------------------------------------
// ErrorDialog
// ---------------------------------------------------------------------------------------------------------
ErrorDialog fatal title explanation details mb_bitmap buttons dialog_id button_ids pstate
	# bg									= if fatal BG GreenBG
	# start_control							= bitmap_control :+: title_control bg :+: bitmap_control
	# (real_size, pstate)					= controlSize start_control False (Just (5,5)) (Just (5,5)) (Just (15,15)) pstate
	= (
		Dialog "Error!"
			(CompoundControl (start_control :+: explanation_control (real_size.w) bg :+: (details_control details real_size.w bg) :+: (ListLS (button_controls buttons button_ids)))
				[ ControlItemSpace		15 15
				, ControlHMargin		5 5
				, ControlVMargin		5 5
				, ControlLook			False (\_ {newFrame} -> seq [setPenColour bg, fill newFrame])
				])
			[ WindowId					dialog_id
			, WindowHMargin				0 0
			, WindowVMargin				0 0
			, WindowClose				(noLS (closeWindow dialog_id))
			, WindowOk					(hd button_ids)
			, WindowCancel				(hd button_ids)
			, WindowInitActive			(hd button_ids)
			]
	  , pstate)
	where
		bitmap_control
			= CustomControl			bitmap_size (\_ _ -> bitmap_draw)
										[]
			where
				bitmap_size			= if (isNothing mb_bitmap) {w=0,h=0} (getBitmapSize (fromJust mb_bitmap))
				bitmap_draw			= if (isNothing mb_bitmap) (\pict->pict) (seq [setPenColour BG, setPenBack BG, draw (fromJust mb_bitmap)])
		
		title_control bg
			= BalancedTextControl	title 500
										[ BalancedTextFontSize					11
										, BalancedTextColour					TitleFG
										, BalancedTextBackgroundColour			bg
										, BalancedTextFontStyle					["Bold"]
										, BalancedTextFontFace					"Comic Sans MS"
										]
										[]
		
		explanation_control w bg
			= BalancedTextControl	explanation w
										[ BalancedTextColour					Blue
										, BalancedTextFontSize					10
										, BalancedTextBackgroundColour			bg
										, BalancedTextFontStyle					["Bold"]
										, BalancedTextFontFace					"Times New Roman"
										]
										[ ControlPos							(Center, zero)
										]
		
		details_control [] w bg
			= ControlNothing
		details_control errors w bg
			= ControlJust
			( boxedMarkUp			Black DoNotResize [CmBText "Underlying errors:", CmNewline: ferrors]
										[ MarkUpWidth							w
										, MarkUpNrLines							(min 11 (length details+1))
										, MarkUpFontFace						"Times New Roman"
										, MarkUpTextSize						8
										, MarkUpTextColour						Grey
										, MarkUpBackgroundColour				AlmostBG
										, MarkUpVScroll
										, MarkUpHScroll
										]
										[ ControlPos							(Center, zero)
										]
			)
			where
				ferrors
					= flatten (map (\text -> [CmIText text, CmNewline]) errors)
		
		button_controls [] []
			= []
		button_controls [name:names] [id:ids]
			# pos					= if (isEmpty ids) (Right, OffsetVector {vx=0,vy=5}) (LeftOf (hd ids), OffsetVector {vx=10,vy=0})
			# control				= ButtonControl name
										[ ControlPos							pos
										, ControlId								id
										, ControlFunction						(close name)
										]
			= [control: button_controls names ids]
		
		close :: !String !(!String, !*PSt .ls) -> (!String, !*PSt .ls)
		close button (_, pstate)
			= (button, closeWindow dialog_id pstate)
              
















// -----------------------------------------------------------------------------------------
umap :: !(.a -> (.s -> (.c, .s))) !.[.a] !.s -> (!.[.c], !.s)        
// -----------------------------------------------------------------------------------------
umap f [] state
	= ([], state)
umap f [x:xs] state
	#! (fx, state)	= f x state
	#! (fxs, state)	= umap f xs state
	= ([fx:fxs], state)     

// ---------------------------------------------------------------------------------------------------------
uumap :: !(.a -> .(.s1 -> .(.s2 -> (.c, .s1, .s2)))) !.[.a] !.s1 !.s2 -> (!.[.c], !.s1, !.s2)
// ---------------------------------------------------------------------------------------------------------
uumap f [] state1 state2
	= ([], state1, state2)
uumap f [x:xs] state1 state2
	#! (fx, state1, state2)			= f x state1 state2
	#! (fxs, state1, state2)		= uumap f xs state1 state2
	= ([fx:fxs], state1, state2)

// ---------------------------------------------------------------------------------------------------------
uwalk :: !(.a -> (.s -> .s)) !.[.a] !.s -> .s
// ---------------------------------------------------------------------------------------------------------
uwalk f [] state
	= state
uwalk f [x:xs] state
	#! state				= f x state
	= uwalk f xs state

// ---------------------------------------------------------------------------------------------------------
uuwalk :: !(.a -> .(.s1 -> .(.s2 -> (.s1, .s2)))) ![.a] !.s1 !.s2 -> (!.s1, !.s2)
// ---------------------------------------------------------------------------------------------------------
uuwalk f [] state1 state2
	= (state1, state2)
uuwalk f [x:xs] state1 state2
	#! (state1, state2)		= f x state1 state2
	= uuwalk f xs state1 state2

// ---------------------------------------------------------------------------------------------------------
TruncPath :: !String -> String
// ---------------------------------------------------------------------------------------------------------
TruncPath text
	# list					= [c \\ c <-: text]
	# reverse_list			= reverse list
	# reverse_filename		= takeWhile (\c -> c <> '\\' && c <> '/') reverse_list
	= toString (reverse reverse_filename)

// ---------------------------------------------------------------------------------------------------------
TruncExtension :: !String -> String
// ---------------------------------------------------------------------------------------------------------
TruncExtension text
	# list					= [c \\ c <-: text]
	# filename				= takeWhile (\c -> c <> '.') list
	= toString filename

// ---------------------------------------------------------------------------------------------------------
smap :: !(.a -> .b) !.[.a] -> .[.b]
// ---------------------------------------------------------------------------------------------------------
smap f []
	= []
smap f [x:xs]
	#! fx					= f x
	#! fxs					= smap f xs
	= [fx:fxs]
        
// ---------------------------------------------------------------------------------------------------------
mapError :: !(.a -> (HandlerError b, .c)) !.[.a] -> (!HandlerError b, !.[.c])
// ---------------------------------------------------------------------------------------------------------
mapError f []
   = (OK, [])
mapError f [x:xs]
   #! (error, fx)       = f x
   | isError error      = (error, [])
   #! (error, fxs)      = mapError f xs
   | isError error      = (error, [])
   = (OK, [fx:fxs])   
   
// ---------------------------------------------------------------------------------------------------------
umapError :: !(.a -> (.s -> (HandlerError b, .c, .s))) !.[.a] !.s -> (!HandlerError b, !.[.c], !.s)
// ---------------------------------------------------------------------------------------------------------
umapError f [] state
	= (OK, [], state)
umapError f [x:xs] state
	#! (error, fx, state)	= f x state
	| isError error			= (error, [], state)
	#! (error, fxs, state)	= umapError f xs state
	| isError error			= (error, [], state)
	= (OK, [fx:fxs], state)

// ---------------------------------------------------------------------------------------------------------
uumapError :: !(.a -> .(.s1 -> .(.s2 -> (HandlerError b, .c, .s1, .s2)))) !.[.a] !.s1 !.s2 -> (!HandlerError b, !.[.c], !.s1, !.s2)
// ---------------------------------------------------------------------------------------------------------
uumapError f [] state1 state2
	= (OK, [], state1, state2)
uumapError f [x:xs] state1 state2
	#! (error, fx, state1, state2)	= f x state1 state2
	| isError error					= (error, [], state1, state2)
	#! (error, fxs, state1, state2)	= uumapError f xs state1 state2
	| isError error					= (error, [], state1, state2)
	= (OK, [fx:fxs], state1, state2)

// ---------------------------------------------------------------------------------------------------------
uwalkError :: !(.a -> (.s -> (HandlerError b, .s))) !.[.a] !.s -> (!HandlerError b, !.s)
// ---------------------------------------------------------------------------------------------------------
uwalkError f [] state
	= (OK, state)
uwalkError f [x:xs] state
	#! (error, state)		= f x state
	| isError error			= (error, state)
	#! (error, state)		= uwalkError f xs state
	| isError error			= (error, state)
	= (OK, state)

// ---------------------------------------------------------------------------------------------------------
uuwalkError :: !(.a -> .(.s1 -> .(.s2 -> (HandlerError b, .s1, .s2)))) !.[.a] !.s1 !.s2 -> (!HandlerError b, !.s1, !.s2)
// ---------------------------------------------------------------------------------------------------------
uuwalkError f [] state1 state2
	= (OK, state1, state2)
uuwalkError f [x:xs] state1 state2
	#! (error, state1, state2)		= f x state1 state2
	| isError error					= (error, state1, state2)
	#! (error, state1, state2)		= uuwalkError f xs state1 state2
	| isError error					= (error, state1, state2)
	= (OK, state1, state2)

// ---------------------------------------------------------------------------------------------------------
useqError :: ![.a -> (HandlerError b, .a)] !.a -> (!HandlerError b, !.a)
// ---------------------------------------------------------------------------------------------------------
useqError [f:fs] state
	#! (error, state)			= f state
	| isError error				= (error, state)
	#! (error, state)			= useqError fs state
	| isError error				= (error, state)
	= (OK, state)
useqError [] state
	= (OK, state)

// ---------------------------------------------------------------------------------------------------------
ufilter :: !(a .s -> (!Bool, .s)) ![a] !.s -> (![a], !.s)
// ---------------------------------------------------------------------------------------------------------
ufilter pred [x:xs] state
	# (ok, state)				= pred x state
	# (xs, state)				= ufilter pred xs state
	= case ok of
		True	->	([x:xs], state)
		False	->	(xs, state)
ufilter pred [] state
	= ([], state)