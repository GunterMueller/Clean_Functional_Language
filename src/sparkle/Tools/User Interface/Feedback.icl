/*
** Program: Clean Prover System
** Module:  Feedback (.icl)
** 
** Author:  Maarten de Mol
** Created: 6 December 2000
*/

implementation module 
	Feedback

import 
	StdEnv,
	StdIO,
	States,
	ControlMaybe,
	MarkUpText,
	Tactics,
	RWSDebug
 
// -------------------------------------------------------------------------------------------------------------------------------------------------
:: Feedback =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ fbId					:: !Id
	, fbRId					:: !RId (MarkUpMessage ProofCommand)
	, fbInfo				:: !FeedbackInfo
	, fbKind				:: !FeedbackKind
	}
inControl feedback :== feedback.fbKind == ControlFeedback
inWindow feedback  :== feedback.fbKind == (WindowFeedback zero zero)

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: FeedbackInfo =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ fiNum					:: !Int
	, fiName				:: !String
	, fiTitle				:: !String
	, fiBackground			:: !Colour
	, fiNrLines				:: !Int
	, fiItalic				:: !Bool
	, fiShow				:: !ShowFeedback
	}
instance < FeedbackInfo
	where (<) info1 info2 = info1.fiNum < info2.fiNum

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: FeedbackKind =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  ControlFeedback
	| WindowFeedback		!Vector2 !Size
instance == FeedbackKind
	where (==) ControlFeedback			ControlFeedback			= True
		  (==) (WindowFeedback _ _)		(WindowFeedback _ _)	= True
		  (==) _						_						= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: FeedbackContents			:== MarkUpText ProofCommand
:: ShowFeedback				:== Theorem *PState -> (Error, FeedbackContents, *PState)

GrayBlue					:== RGB {r=175, g=175, b=185}
// -------------------------------------------------------------------------------------------------------------------------------------------------


















// ------------------------------------------------------------------------------------------------------------------------
// boxedControl :: MarkUpText MarkUpAttributes ControlAttributes -> Control
// ------------------------------------------------------------------------------------------------------------------------
boxedControl ftext mattrs attrs
	# margin_attrs						= [ControlVMargin 1 1, ControlHMargin 1 1]
	# look_attrs						= [ControlLook True (\_ {newFrame} -> seq [setPenColour Blue, draw newFrame])]
	= CompoundControl
		( MarkUpControl ftext mattrs [] )
		( attrs ++ margin_attrs ++ look_attrs )

// ------------------------------------------------------------------------------------------------------------------------
eventHandler :: !(MarkUpEvent ProofCommand) !*PState -> !*PState
// ------------------------------------------------------------------------------------------------------------------------
eventHandler event pstate
	| event.meSelectEvent				= pstate
	# (mb_ids, pstate)					= pstate!ls.stWindows.winProof
	| isNothing mb_ids					= pstate
	# (theorem, id, rid)				= fromJust mb_ids
	= snd (syncSend rid event.meLink pstate)






























// ------------------------------------------------------------------------------------------------------------------------
darken :: !Colour -> !Colour
// ------------------------------------------------------------------------------------------------------------------------
darken (RGB rgb=:{r,g,b})
	= RGB {r=r-40, g=g-40, b=b-40}
darken other
	= other

// ------------------------------------------------------------------------------------------------------------------------
createFeedbackControl :: !Feedback !(Maybe Id) !*PState -> (_, !Maybe Id, !*PState)
// ------------------------------------------------------------------------------------------------------------------------
createFeedbackControl feedback previous_id pstate
	| inWindow feedback					= (ControlNothing, previous_id, pstate)
	# (text_id, pstate)					= accPIO openId pstate
	# pos								= case previous_id of
											(Just prev_id)			-> (Below prev_id, zero)
											Nothing					-> (Left, zero)
	# text_control						= MarkUpControl [/*CmUnderline, CmBText feedback.fbInfo.fiTitle, CmEndUnderline*/]
											[ MarkUpBackgroundColour	GrayBlue
											, MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											]
											[ ControlPos				pos
											, ControlId					text_id
											]
	# start_text						= case feedback.fbInfo.fiItalic of
											True	-> [CmIText "creating"]
											False	-> [CmText "creating"]
	# contents_control					= boxedControl start_text
											[ MarkUpBackgroundColour	feedback.fbInfo.fiBackground
											, MarkUpFontFace			"Courier New"
											, MarkUpTextSize			10
											, MarkUpLinkStyle			False Black feedback.fbInfo.fiBackground False Black (darken feedback.fbInfo.fiBackground)
											, MarkUpWidth				725
											, MarkUpNrLines				feedback.fbInfo.fiNrLines
											, MarkUpHScroll
											, MarkUpVScroll
											, MarkUpReceiver			feedback.fbRId
											, MarkUpEventHandler		eventHandler
											, MarkUpIgnoreFontSize		["Symbol", "VDM and Z 1.0"]
											]
											[ ControlId					feedback.fbId
											, ControlPos				(Below text_id, zero)
											]
	= (ControlJust (text_control :+: contents_control), Just feedback.fbId, pstate)

// ------------------------------------------------------------------------------------------------------------------------
createFeedbackControls :: [!Feedback] !*PState -> (ListLS (ControlMaybe (:+: (MarkUpState a) (CompoundControl (MarkUpState ProofCommand)))) ls !*PState,!*PState)
// ------------------------------------------------------------------------------------------------------------------------
createFeedbackControls feedbacks pstate
	# (feedbacks, pstate)				= create feedbacks Nothing pstate
	= (ListLS feedbacks, pstate)
	where
		create :: ![Feedback] !(Maybe Id) !*PState -> (_, !*PState)
		create [] _ pstate
			= ([], pstate)
		create [feedback:feedbacks] previous_id pstate
			# (feedback, previous_id, pstate)	= createFeedbackControl feedback previous_id pstate
			# (feedbacks, pstate)				= create feedbacks previous_id pstate
			= ([feedback:feedbacks], pstate)

// ------------------------------------------------------------------------------------------------------------------------
closeFeedbackWindows :: [!Feedback] !*PState -> ([!Feedback], !*PState)
// ------------------------------------------------------------------------------------------------------------------------
closeFeedbackWindows [feedback:feedbacks] pstate
	| inWindow feedback
		# pstate						= closeWindow feedback.fbId pstate
		= closeFeedbackWindows feedbacks pstate
	| inControl feedback
		# (feedbacks, pstate)			= closeFeedbackWindows feedbacks pstate
		= ([feedback:feedbacks], pstate)
closeFeedbackWindows [] pstate
	= ([], pstate)

// ------------------------------------------------------------------------------------------------------------------------
openFeedbackWindow :: !Feedback !*PState -> !*PState
// ------------------------------------------------------------------------------------------------------------------------
openFeedbackWindow feedback pstate
	# (vector, width, height)			= examine feedback.fbKind
	= MarkUpWindow feedback.fbInfo.fiTitle [CmText "creating"]
			[ MarkUpBackgroundColour	feedback.fbInfo.fiBackground
			, MarkUpFontFace			"Courier New"
			, MarkUpTextSize			10
			, MarkUpLinkStyle			False Black feedback.fbInfo.fiBackground True Black feedback.fbInfo.fiBackground
			, MarkUpReceiver			feedback.fbRId
			, MarkUpEventHandler		eventHandler
			, MarkUpWidth				width
			, MarkUpHeight				height
			, MarkUpIgnoreFontSize		["Symbol", "VDM and Z 1.0"]
			]
			[ WindowId					feedback.fbId
			, WindowClose				(noLS close_window)
			, WindowPos					(Fix, OffsetVector vector)
			]
			pstate
	where
		close_window pstate
			# (mb_ids, pstate)			= pstate!ls.stWindows.winProof
			| isNothing mb_ids			= pstate
			# (theorem_ptr, id, rid)	= fromJust mb_ids
			= snd (syncSend rid (PCmdLayout RemoveWindow feedback.fbInfo.fiName) pstate)
		
		examine :: !FeedbackKind -> (!Vector2, !Int, !Int)
		examine (WindowFeedback vector size)
			# width						= if (size.w == 0) 300 size.w
			# height					= if (size.h == 0) 200 size.h
			= (vector, width, height)






















// ------------------------------------------------------------------------------------------------------------------------
refreshFeedbacks :: !Theorem ![Feedback] !*PState -> !*PState
// ------------------------------------------------------------------------------------------------------------------------
refreshFeedbacks theorem [feedback: feedbacks] pstate
	# (error, contents, pstate)			= feedback.fbInfo.fiShow theorem pstate
	| isError error
		# pstate						= ShowError error id pstate
		= refreshFeedbacks theorem feedbacks pstate
	# pstate							= changeMarkUpText feedback.fbRId contents pstate
	# pstate							= jumpToMarkUpLabel feedback.fbRId "@LastScreen" pstate
	= refreshFeedbacks theorem feedbacks pstate
refreshFeedbacks theorem [] pstate
	= pstate

// ------------------------------------------------------------------------------------------------------------------------
updateFeedbacks :: !ChangeLayout !FeedbackInfo ![Feedback] !*PState -> (!Bool, !Bool, ![Feedback], !*PState)
// ------------------------------------------------------------------------------------------------------------------------
updateFeedbacks AddControl info feedbacks pstate
	= addControl info feedbacks pstate
updateFeedbacks AddWindow info feedbacks pstate
	= addWindow info feedbacks pstate
updateFeedbacks RemoveControl info feedbacks pstate
	# (changed, feedbacks)				=  removeControl info feedbacks
	= (changed, True, feedbacks, pstate)
updateFeedbacks RemoveWindow info feedbacks pstate
	= removeWindow info feedbacks pstate















// ------------------------------------------------------------------------------------------------------------------------
addWindow :: !FeedbackInfo ![Feedback] !*PState -> (!Bool, !Bool, ![Feedback], !*PState)
// ------------------------------------------------------------------------------------------------------------------------
addWindow info [feedback: feedbacks] pstate
	| inControl feedback
		# (redraw, refresh, feedbacks, pstate)		= addWindow info feedbacks pstate
		= (redraw, refresh, [feedback: feedbacks], pstate)
	| inWindow feedback
		| feedback.fbInfo.fiName <> info.fiName
			# (redraw, refresh, feedbacks, pstate)	= addWindow info feedbacks pstate
			= (redraw, refresh, [feedback: feedbacks], pstate)
		= (False, True, [feedback: feedbacks], pstate)
addWindow info [] pstate
	# (id, pstate)									= accPIO openId pstate
	# (rid, pstate)									= accPIO openRId pstate
	# feedback										=	{ fbId			= id
														, fbRId			= rid
														, fbInfo		= info
														, fbKind		= WindowFeedback zero zero
														}
	# pstate										= openFeedbackWindow feedback pstate
	= (False, True, [feedback], pstate)

// ------------------------------------------------------------------------------------------------------------------------
removeWindow :: !FeedbackInfo ![Feedback] !*PState -> (!Bool, !Bool, ![Feedback], !*PState)
// ------------------------------------------------------------------------------------------------------------------------
removeWindow info [feedback:feedbacks] pstate
	| inControl feedback
		# (redraw, refresh, feedbacks, pstate)		= removeWindow info feedbacks pstate
		= (redraw, refresh, [feedback:feedbacks], pstate)
	| inWindow feedback
		| feedback.fbInfo.fiName <> info.fiName
			# (redraw, refresh, feedbacks, pstate)	= removeWindow info feedbacks pstate
			= (redraw, refresh, [feedback:feedbacks], pstate)
		# pstate									= closeWindow feedback.fbId pstate
		= (False, True, feedbacks, pstate)
removeWindow info [] pstate
	= (False, False, [], pstate)

// ------------------------------------------------------------------------------------------------------------------------
addControl :: !FeedbackInfo ![Feedback] !*PState -> (!Bool, !Bool, ![Feedback], !*PState)
// ------------------------------------------------------------------------------------------------------------------------
addControl info [feedback: feedbacks] pstate
	| inWindow feedback
		# (redraw, refresh, feedbacks, pstate)		= addControl info feedbacks pstate
		= (redraw, refresh, [feedback: feedbacks], pstate)
	| inControl feedback
		| feedback.fbInfo.fiName <> info.fiName
			# (redraw, refresh, feedbacks, pstate)	= addControl info feedbacks pstate
			= (redraw, refresh, [feedback: feedbacks], pstate)
		= (False, False, [feedback: feedbacks], pstate)
addControl info [] pstate
	# (id, pstate)									= accPIO openId pstate
	# (rid, pstate)									= accPIO openRId pstate
	# feedback										=	{ fbId			= id
														, fbRId			= rid
														, fbInfo		= info
														, fbKind		= ControlFeedback
														}
	= (True, True, [feedback], pstate)

// ------------------------------------------------------------------------------------------------------------------------
removeControl :: !FeedbackInfo ![Feedback] -> (!Bool, ![Feedback])
// ------------------------------------------------------------------------------------------------------------------------
removeControl info [feedback:feedbacks]
	| inWindow feedback
		# (changed, feedbacks)						= removeControl info feedbacks
		= (changed, [feedback: feedbacks])
	| inControl feedback
		| feedback.fbInfo.fiName <> info.fiName
			# (changed, feedbacks)					= removeControl info feedbacks
			= (changed, [feedback: feedbacks])
		= (True, feedbacks)
removeControl info []
	= (False, [])