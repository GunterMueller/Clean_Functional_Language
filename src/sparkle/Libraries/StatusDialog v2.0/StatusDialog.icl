implementation module
	StatusDialog

import
	StdEnv,
	StdIO,
	BalancedText,
	MarkUpText
from StdFunc import seq

// ---------------------------------------------------------------------------------------------------------------------------
:: StatusDialogEvent = 
// ---------------------------------------------------------------------------------------------------------------------------
	  NewMessage			!String
	| Finished
	| CloseStatusDialog

// ---------------------------------------------------------------------------------------------------------------------------
:: StatusDialogFunction ps	:== (StatusDialogEvent -> ps -> ps) -> ps -> ps
// ---------------------------------------------------------------------------------------------------------------------------

// ---------------------------------------------------------------------------------------------------------------------------
:: StatusDialogState ps =
// ---------------------------------------------------------------------------------------------------------------------------
	{ sdsPreviousMessages		:: ![String]
	, sdsCurrentBitmap			:: !Int
	, sdsHistoryId				:: !Id
	, sdsHistoryShown			:: !Bool
	}

// ---------------------------------------------------------------------------------------------------------------------------
openStatusDialog :: !String !(StatusDialogFunction (*PSt .ps)) !(*PSt .ps) -> *PSt .ps
// ---------------------------------------------------------------------------------------------------------------------------
openStatusDialog overview_message userfunction state
	# ([dialog_id, whole_id, head_id, message_id, previousmessage_id, bitmap_id, ok_id, history_id, dummy_id: _], state)
									= accPIO (openIds 9) state
	# (rid1, state)					= accPIO openRId state
	# (rid2, state)					= accPIO openRId state
	# (rid3, state)					= accPIO openRId state
	# (rid4, state)					= accPIO openRId state
	# (maybe_bitmap1, state)		= openBitmap (applicationpath "Images/StatusDialog_Busy1.bmp") state
	# maybe_bitmap1					= case maybe_bitmap1 of
										Just bitmap		-> Just (resizeBitmap {w=50,h=50} bitmap)
										Nothing			-> Nothing
	# (maybe_bitmap2, state)		= openBitmap (applicationpath "Images/StatusDialog_Busy2.bmp") state
	# maybe_bitmap2					= case maybe_bitmap2 of
										Just bitmap		-> Just (resizeBitmap {w=50,h=50} bitmap)
										Nothing			-> Nothing
	# (maybe_bitmap3, state)		= openBitmap (applicationpath "Images/StatusDialog_Finished.bmp") state
	# maybe_bitmap3					= case maybe_bitmap3 of
										Just bitmap		-> Just (resizeBitmap {w=50,h=50} bitmap)
										Nothing			-> Nothing
	# localstate					= {sdsPreviousMessages = [], sdsCurrentBitmap = 1, sdsHistoryId = whole_id, sdsHistoryShown = False}
	# statusdialog					= StatusDialog dialog_id whole_id rid1 rid2 rid3 rid4 head_id message_id previousmessage_id bitmap_id ok_id history_id dummy_id overview_message maybe_bitmap1 maybe_bitmap2 maybe_bitmap3 userfunction
	= snd (openModalDialog localstate statusdialog state)

// ===========================================================================================================================
// The argument bitmaps must be of size 50x50. (must be resized by calling functions)
// ---------------------------------------------------------------------------------------------------------------------------
// StatusDialog :: !RId !Id !Id !Id !Id !Id !String (Maybe !Bitmap) (Maybe !Bitmap) (Maybe !Bitmap) (*PSt -> *PSt) -> Dialog 
// ---------------------------------------------------------------------------------------------------------------------------
StatusDialog dialog_id whole_id rid1 rid2 rid3 rid4 head_id message_id previousmessage_id bitmap_id ok_id history_id dummy_id overview_message maybe_bitmap1 maybe_bitmap2 maybe_bitmap3 userfunction
	# bg_colour								= RGB {r=10, g=150, b=200}
	# border_colour							= RGB {r=10, g=50, b=100}
	= Dialog "Status Dialog" 
		(CompoundControl
			(    Receiver					rid1 receiver []
			 :+: MarkUpControl				[CmCenter, CmBText overview_message]
												[ MarkUpWidth				550
												, MarkUpBackgroundColour	bg_colour
												, MarkUpTextColour			Green
												, MarkUpTextSize			12
												]
												[ ControlId					head_id
												]
			 :+: CustomControl				{w=50,h=50} (if (isJust maybe_bitmap1) (\_ _ -> draw (fromJust maybe_bitmap1)) (\_ _ -> id))
			 									[ ControlPos				(Below head_id, OffsetVector {vx=0, vy=25})
			 									, ControlId					bitmap_id
			 									]
			 :+: MarkUpControl				[CmBText "Previous: "] 
			 									[ MarkUpBackgroundColour	bg_colour
			 									]
			 									[ ControlPos				(RightTo bitmap_id, zero)
			 									, ControlId					dummy_id
			 									]
			 :+: MarkUpControl				[CmText "."]
			 									[ MarkUpBackgroundColour	bg_colour
			 									, MarkUpReceiver			rid2
			 									, MarkUpWidth				400
			 									]
			 									[ ControlId					previousmessage_id
			 									]
			 :+: MarkUpControl				[CmBText "Current: "] 
			 									[ MarkUpBackgroundColour	bg_colour
			 									]
			 									[ ControlPos				(Below dummy_id, zero)
			 									]
			 :+: MarkUpControl				[CmText "."]
			 									[ MarkUpBackgroundColour	bg_colour
			 									, MarkUpReceiver			rid3
			 									, MarkUpWidth				400
			 									]
			 									[ ControlId					message_id
			 									, ControlPos				(Below previousmessage_id, zero)
			 									]
			 :+: ButtonControl				"History On "
			 									[ ControlId					history_id
			 									, ControlSelectState		Unable
			 									, ControlPos				(Right, OffsetVector {vx=0, vy=25})
			 									, ControlFunction			history_fun
			 									]
			 :+: ButtonControl				"Ok"
			 									[ ControlFunction			(noLS (closeWindow dialog_id))
			 									, ControlSelectState		Unable
			 									, ControlId					ok_id
			 									, ControlPos				(LeftOf history_id, zero)
			 									]
			 :+: MarkUpControl				[CmText "no history yet"]
			 									[ MarkUpBackgroundColour	border_colour
			 									, MarkUpTextColour			White
			 									, MarkUpNrLines				6
			 									, MarkUpWidth				550
			 									, MarkUpReceiver			rid4
			 									]
			 									[ ControlId					whole_id
			 									, ControlPos				(Below head_id, OffsetVector {vx=0,vy=20})
			 									, ControlHide
			 									]
			)
			[ ControlLook					True (\_ upd -> seq [setPenColour bg_colour, fill upd.newFrame,
															     setPenColour border_colour, draw upd.newFrame])
			])
		[ WindowInit					(noLS (userfunction set_message))
		, WindowId						dialog_id
		]
	where
		receiver (NewMessage newmsg) (dialogstate, state)
			# oldmsg					= if (isEmpty dialogstate.sdsPreviousMessages) "" (hd dialogstate.sdsPreviousMessages)
			# dialogstate				= {dialogstate & sdsPreviousMessages = [newmsg: dialogstate.sdsPreviousMessages]}
			# oldnum					= dialogstate.sdsCurrentBitmap
			# newnum					= 3 - oldnum
			# dialogstate				= {dialogstate & sdsCurrentBitmap = newnum}
			# newbitmap					= if (newnum == 1) maybe_bitmap1 maybe_bitmap2
			# newlook					= if (isNothing newbitmap) (\_ _ -> id) (\_ _ -> draw (fromJust newbitmap))
			# state						= changeMarkUpText rid3 [CmText newmsg] state
			# state						= changeMarkUpText rid2 [CmText oldmsg] state
			# state						= appPIO (setControlLook bitmap_id True (True, newlook)) state
			= (dialogstate, state)
		receiver Finished (dialogstate, state)
			# newlook					= if (isNothing maybe_bitmap3) (\_ _ -> id) (\_ _ -> draw (fromJust maybe_bitmap3))
			# state						= appPIO (setControlLook bitmap_id True (True, newlook)) state
			# state						= appPIO (hideControl whole_id) state
			# state						= changeMarkUpText rid4 (history_text 0 dialogstate.sdsPreviousMessages) state
			# state						= appPIO (hideControl whole_id) state
			= (dialogstate, appPIO (enableControls [ok_id, history_id]) state)
			where
				history_text num [text: texts]
					# this_text			= [CmCenter, CmBText ("[last-" +++ toString num +++ "]"), CmAlign "1", CmTabSpace, CmText text]
					# other_texts		= history_text (num+1) texts
					| isEmpty texts		= this_text
					= this_text ++ [CmNewline: other_texts]
				history_text num []
					= []
		receiver CloseStatusDialog (dialogstate, state)
			= (dialogstate, closeWindow dialog_id state)
		
		set_message msg state
			= snd (syncSend rid1 msg state)
		
		history_fun (dialogstate, state)
			= case dialogstate.sdsHistoryShown of
				True		-> hide_history dialogstate.sdsHistoryId (dialogstate, state)
				False		-> show_history dialogstate.sdsHistoryId (dialogstate, state)
		
		hide_history id (dialogstate, state)
			# state						= appPIO (setControlText history_id "History On") state
			# state						= appPIO (hideControl id) state
			# dialogstate				= {dialogstate & sdsHistoryShown = False}
			= (dialogstate, state)
		
		show_history id (dialogstate, state)
			# state						= appPIO (setControlText history_id "History Off") state
			# state						= appPIO (showControl id) state
			# dialogstate				= {dialogstate & sdsHistoryShown = True}
			= (dialogstate, state)
